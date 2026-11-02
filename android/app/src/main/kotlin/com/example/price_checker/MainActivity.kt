package com.example.price_checker

import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "price_checker_scanner"
    private val authChannelName = "device_auth_channel"
    private var methodChannel: MethodChannel? = null
    private var authChannel: MethodChannel? = null
    private var clipboardManager: ClipboardManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isActivityVisible = false
    private var isScannerEnabled = true
    private var isClearingClipboard = false
    private var isReceiverRegistered = false

    private var lastEmittedCode = ""
    private var lastEmittedTime = 0L

    private val keyBuffer = StringBuilder()
    private var lastKeyTime = 0L

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        if (!isActivityVisible || !isScannerEnabled || isClearingClipboard) return@OnPrimaryClipChangedListener
        readClipboardAndEmit()
    }

    private val scanBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isActivityVisible || !isScannerEnabled || intent == null) return
            val possibleKeys = listOf(
                "barcode_string",
                "barcode",
                "data",
                "value",
                "SCAN_BARCODE1",
                "scannerdata",
                "scan_result",
                "decode_data",
                "com.symbol.datawedge.data_string",
                "android.intent.extra.SCAN_BROADCAST_DATA"
            )
            for (key in possibleKeys) {
                val str = intent.getStringExtra(key)?.trim()
                if (!str.isNullOrEmpty()) {
                    emitScannedCode(str)
                    return
                }
            }
            val bytes = intent.getByteArrayExtra("barocode") ?: intent.getByteArrayExtra("barcode")
            if (bytes != null && bytes.isNotEmpty()) {
                val str = String(bytes).trim()
                if (str.isNotEmpty()) {
                    emitScannedCode(str)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        authChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, authChannelName)
        authChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    val androidId = try {
                        android.provider.Settings.Secure.getString(
                            contentResolver,
                            android.provider.Settings.Secure.ANDROID_ID
                        ) ?: ""
                    } catch (_: Exception) {
                        ""
                    }
                    val manufacturer = (Build.MANUFACTURER ?: "").trim()
                    val model = (Build.MODEL ?: "").trim()
                    val rawModel = if (model.startsWith(manufacturer, ignoreCase = true)) {
                        model
                    } else {
                        "$manufacturer $model".trim()
                    }
                    val fullModel = rawModel.replaceFirstChar {
                        if (it.isLowerCase()) it.titlecase() else it.toString()
                    }
                    val osVersion = "Android ${Build.VERSION.RELEASE ?: ""} (SDK ${Build.VERSION.SDK_INT})"
                    result.success(
                        mapOf(
                            "androidId" to androidId,
                            "deviceModel" to fullModel,
                            "osVersion" to osVersion
                        )
                    )
                }
                "setScannerEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: true
                    isScannerEnabled = enabled
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        clipboardManager?.addPrimaryClipChangedListener(clipListener)
        registerScannerReceiver()
    }

    override fun onStart() {
        super.onStart()
        isActivityVisible = true
    }

    override fun onResume() {
        super.onResume()
        isActivityVisible = true
    }

    override fun onStop() {
        isActivityVisible = false
        super.onStop()
    }

    override fun onDestroy() {
        try {
            clipboardManager?.removePrimaryClipChangedListener(clipListener)
        } catch (_: Exception) {}
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(scanBroadcastReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerScannerReceiver() {
        if (isReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction("android.intent.ACTION_DECODE_DATA")
            addAction("android.intent.action.SCANRESULT")
            addAction("com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED")
            addAction("com.rscja.scanner.action.scannerdata")
            addAction("nlscan.action.SCANNER_RESULT")
            addAction("com.honeywell.decode.intent.action.EDIT_DATA")
            addAction("com.symbol.datawedge.api.RESULT_ACTION")
            addAction("com.android.server.scannerservice.broadcast")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(scanBroadcastReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(scanBroadcastReceiver, filter)
            }
            isReceiverRegistered = true
        } catch (_: Exception) {}
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (!isScannerEnabled) {
            return super.dispatchKeyEvent(event)
        }
        if (event.action == KeyEvent.ACTION_DOWN) {
            if (event.keyCode == KeyEvent.KEYCODE_PASTE ||
                (event.keyCode == KeyEvent.KEYCODE_V && event.isCtrlPressed)
            ) {
                readClipboardAndEmit()
                return true
            }

            val now = System.currentTimeMillis()
            if (event.keyCode == KeyEvent.KEYCODE_ENTER ||
                event.keyCode == KeyEvent.KEYCODE_NUMPAD_ENTER
            ) {
                if (keyBuffer.length >= 3 && (now - lastKeyTime) < 150) {
                    val scanned = keyBuffer.toString()
                    keyBuffer.clear()
                    emitScannedCode(scanned)
                } else {
                    keyBuffer.clear()
                }
            } else {
                val unicode = event.unicodeChar
                if (unicode > 0 && !event.isCtrlPressed && !event.isAltPressed) {
                    if (now - lastKeyTime > 150) {
                        keyBuffer.clear()
                    }
                    keyBuffer.append(unicode.toChar())
                    lastKeyTime = now
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun extractClipText(): String {
        return try {
            val clip = clipboardManager?.primaryClip
            if (clip != null && clip.itemCount > 0) {
                clip.getItemAt(0)?.coerceToText(this)?.toString()?.trim() ?: ""
            } else {
                ""
            }
        } catch (_: Exception) {
            ""
        }
    }

    private fun readClipboardAndEmit() {
        val text = extractClipText()
        if (text.isNotEmpty()) {
            emitScannedCode(text)
        } else {
            mainHandler.postDelayed({
                if (!isActivityVisible || isClearingClipboard) return@postDelayed
                val retryText = extractClipText()
                if (retryText.isNotEmpty()) {
                    emitScannedCode(retryText)
                }
            }, 60)
        }
    }

    private fun emitScannedCode(rawCode: String) {
        val code = rawCode.replace("\r", "").replace("\n", "").trim()
        if (code.isEmpty()) return

        val now = System.currentTimeMillis()
        if (code == lastEmittedCode && (now - lastEmittedTime) < 350) {
            return
        }
        lastEmittedCode = code
        lastEmittedTime = now

        mainHandler.post {
            methodChannel?.invokeMethod(
                "onBarcodeScanned",
                code,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result == true) {
                            mainHandler.postDelayed({
                                clearClipboardSafely()
                            }, 200)
                        }
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?
                    ) {}

                    override fun notImplemented() {}
                }
            )
        }
    }

    private fun clearClipboardSafely() {
        try {
            isClearingClipboard = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                clipboardManager?.clearPrimaryClip()
            } else {
                clipboardManager?.setPrimaryClip(ClipData.newPlainText("", ""))
            }
        } catch (_: Exception) {
        } finally {
            mainHandler.postDelayed({
                isClearingClipboard = false
            }, 100)
        }
    }
}
