import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'supabase_config.dart';

// ============================================================================
// 1. DATA MODEL: โครงสร้างข้อมูลเครื่องจากตาราง 'devices' บน Supabase
// ============================================================================
class ClientDeviceModel {
  final String deviceId;
  final String userName;
  final String deviceModel;
  final String osVersion;
  final String activationCode;
  final bool isActivated;
  final String status; // 'pending', 'active', 'banned'
  final DateTime? registeredAt;
  final DateTime? activatedAt;

  const ClientDeviceModel({
    required this.deviceId,
    required this.userName,
    required this.deviceModel,
    required this.osVersion,
    required this.activationCode,
    required this.isActivated,
    required this.status,
    this.registeredAt,
    this.activatedAt,
  });

  factory ClientDeviceModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return ClientDeviceModel(
      deviceId: (map['device_id'] ?? map['deviceId'] ?? '').toString(),
      userName:
          (map['user_name'] ?? map['userName'] ?? 'ไม่ระบุชื่อผู้ใช้').toString(),
      deviceModel:
          (map['device_model'] ?? map['deviceModel'] ?? 'ไม่ระบุรุ่นอุปกรณ์')
              .toString(),
      osVersion:
          (map['os_version'] ?? map['osVersion'] ?? 'ไม่ระบุ OS').toString(),
      activationCode:
          (map['activation_code'] ?? map['activationCode'] ?? '').toString(),
      isActivated:
          (map['is_activated'] ?? map['isActivated'] ?? false) == true,
      status: (map['status'] ?? 'pending').toString(),
      registeredAt: parseDate(map['registered_at'] ?? map['registeredAt']),
      activatedAt: parseDate(map['activated_at'] ?? map['activatedAt']),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'device_id': deviceId,
      'user_name': userName,
      'device_model': deviceModel,
      'os_version': osVersion,
      'activation_code': activationCode,
      'is_activated': isActivated,
      'status': status,
      'registered_at':
          (registeredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'activated_at': activatedAt?.toUtc().toIso8601String(),
    };
  }

  ClientDeviceModel copyWith({
    String? userName,
    String? deviceModel,
    String? osVersion,
    String? activationCode,
    bool? isActivated,
    String? status,
    DateTime? registeredAt,
    DateTime? activatedAt,
  }) {
    return ClientDeviceModel(
      deviceId: deviceId,
      userName: userName ?? this.userName,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      activationCode: activationCode ?? this.activationCode,
      isActivated: isActivated ?? this.isActivated,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }

  bool isSameAuthState(ClientDeviceModel? other) {
    if (other == null) return false;
    return deviceId == other.deviceId &&
        userName == other.userName &&
        activationCode == other.activationCode &&
        isActivated == other.isActivated &&
        status.toLowerCase() == other.status.toLowerCase();
  }
}

// ============================================================================
// 2. DEVICE AUTH GUARD:
//    - เปิดแอปทันทีแบบ 0ms (ไม่หมุนรอโหลดตอนเข้าแอป ไม่ว่าจะมีเน็ตหรือไม่มีเน็ต)
//    - ตรวจสอบสิทธิ์กับ Supabase อยู่เบื้องหลัง (Background Check)
//    - ล็อกหน้าจออัตโนมัติทันทีเมื่อตรวจพบสถานะถูกแบนหรือถูกลบสิทธิ์
// ============================================================================
class DeviceAuthGuard extends StatefulWidget {
  final String appName;
  final String appShortBadge;
  final String appPrefix;
  final Widget? child;
  final WidgetBuilder? authenticatedBuilder;
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;

  /// โหลดข้อมูลแคชของเครื่องล่วงหน้าก่อน runApp เพื่อให้เปิดเข้าแอปได้ทันทีในเฟรมแรก (0ms)
  static SharedPreferences? _preloadedPrefs;
  static Map<String, dynamic>? _preloadedHwInfo;

  static Future<void> ensurePreloaded() async {
    try {
      _preloadedPrefs ??= await SharedPreferences.getInstance();
    } catch (_) {}
    if (!kIsWeb && _preloadedHwInfo == null) {
      try {
        const channel = MethodChannel('device_auth_channel');
        _preloadedHwInfo = await channel
            .invokeMapMethod<String, dynamic>('getDeviceInfo')
            .timeout(const Duration(milliseconds: 150));
      } catch (_) {}
    }
  }

  const DeviceAuthGuard({
    super.key,
    required this.appName,
    required this.appShortBadge,
    required this.appPrefix,
    this.child,
    this.authenticatedBuilder,
    this.lightTheme,
    this.darkTheme,
    this.themeMode = ThemeMode.light,
  });

  @override
  State<DeviceAuthGuard> createState() => _DeviceAuthGuardState();
}

class _DeviceAuthGuardState extends State<DeviceAuthGuard>
    with WidgetsBindingObserver {
  static const MethodChannel _authChannel =
      MethodChannel('device_auth_channel');

  bool _isBusy = false;

  // ข้อมูลประจำเครื่อง
  String _deviceId = '';
  String _rawModelName = 'Android Device';
  String _deviceModel = '';
  String _osVersion = 'Android';

  // การเชื่อมต่อ Supabase เบื้องหลัง
  SupabaseClient? _supabaseClient;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;
  Timer? _pollingTimer;

  // ข้อมูลสถานะของเครื่องปัจจุบัน
  ClientDeviceModel? _deviceRecord;
  String? _statusMessage;
  bool _isStatusError = false;

  // Controllers
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool get _isAccessGranted =>
      _deviceRecord != null &&
      _deviceRecord!.isActivated &&
      _deviceRecord!.status.toLowerCase() == 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // โหลดข้อมูลแคชในเครื่องแบบซิงโครนัสทันที (ไม่รอเครือข่าย)
    _initLocalStateSync();
    // เริ่มตรวจสอบสิทธิ์เบื้องหลังโดยไม่บล็อกการเปิดแอป
    unawaited(_startBackgroundVerification());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _pollingTimer?.cancel();
    _userNameController.dispose();
    _pinController.dispose();
    try {
      _supabaseClient?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_fetchLatestDeviceRecordInBackground());
    }
  }

  Future<void> _syncNativeScannerState() async {
    if (kIsWeb) return;
    try {
      await _authChannel.invokeMethod('setScannerEnabled', _isAccessGranted);
    } catch (_) {}
  }

  /// โหลดสถานะจากแคชในเครื่องทันทีตั้งแต่เฟรมแรก เพื่อไม่ให้มีหน้าหมุนโหลดกวนใจเวลาเปิดแอป
  void _initLocalStateSync() {
    final prefs = DeviceAuthGuard._preloadedPrefs;
    final hwInfo = DeviceAuthGuard._preloadedHwInfo;

    String rawHwId = '';
    if (hwInfo != null) {
      rawHwId = (hwInfo['androidId'] ?? '').toString().trim();
      final m = (hwInfo['deviceModel'] ?? '').toString().trim();
      final o = (hwInfo['osVersion'] ?? '').toString().trim();
      if (m.isNotEmpty) _rawModelName = m;
      if (o.isNotEmpty) _osVersion = o;
    } else if (kIsWeb) {
      _rawModelName = 'Web Browser';
      _osVersion = 'Web';
    }

    if (rawHwId.isEmpty && prefs != null) {
      rawHwId = prefs.getString('saved_hw_device_id') ?? '';
      if (rawHwId.isEmpty) {
        final rnd = Random.secure();
        rawHwId = List.generate(
          8,
          (_) => rnd.nextInt(16).toRadixString(16),
        ).join().toUpperCase();
        prefs.setString('saved_hw_device_id', rawHwId);
      }
    }

    if (rawHwId.isNotEmpty) {
      final cleanId =
          rawHwId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      _deviceId = '${widget.appPrefix}-$cleanId';
    } else {
      _deviceId = '${widget.appPrefix}-DEVICE';
    }

    _deviceModel = '$_rawModelName (${widget.appShortBadge})';

    if (prefs != null) {
      final savedUser = prefs.getString('device_auth_user_name') ?? '';
      if (savedUser.isNotEmpty) {
        _userNameController.text = savedUser;
      }

      final cachedMapStr = prefs.getString('cached_device_status_$_deviceId');
      if (cachedMapStr != null && cachedMapStr.isNotEmpty) {
        final parts = cachedMapStr.split('|');
        if (parts.length >= 4) {
          _deviceRecord = ClientDeviceModel(
            deviceId: _deviceId,
            userName: parts[0],
            deviceModel: _deviceModel,
            osVersion: _osVersion,
            activationCode: parts[1],
            isActivated: parts[2] == 'true',
            status: parts[3],
          );
        }
      }
    }

    _syncNativeScannerState();
  }

  /// ทำงานอยู่เบื้องหลังทั้งหมด: เตรียมข้อมูลเครื่อง + เชื่อมต่อ Supabase Realtime + เช็คสถานะซ้ำ
  Future<void> _startBackgroundVerification() async {
    try {
      final prefs =
          DeviceAuthGuard._preloadedPrefs ?? await SharedPreferences.getInstance();
      DeviceAuthGuard._preloadedPrefs = prefs;

      if (!kIsWeb && DeviceAuthGuard._preloadedHwInfo == null) {
        try {
          final info = await _authChannel
              .invokeMapMethod<String, dynamic>('getDeviceInfo');
          if (info != null) {
            DeviceAuthGuard._preloadedHwInfo = info;
          }
        } catch (_) {}
      }

      // อัปเดตข้อมูลเครื่องหากตอนเริ่มต้นยังโหลดไม่ครบ
      final hwInfo = DeviceAuthGuard._preloadedHwInfo;
      String rawHwId = '';
      if (hwInfo != null) {
        rawHwId = (hwInfo['androidId'] ?? '').toString().trim();
        final m = (hwInfo['deviceModel'] ?? '').toString().trim();
        final o = (hwInfo['osVersion'] ?? '').toString().trim();
        if (m.isNotEmpty) _rawModelName = m;
        if (o.isNotEmpty) _osVersion = o;
      }

      if (rawHwId.isEmpty) {
        rawHwId = prefs.getString('saved_hw_device_id') ?? '';
        if (rawHwId.isEmpty) {
          final rnd = Random.secure();
          rawHwId = List.generate(
            8,
            (_) => rnd.nextInt(16).toRadixString(16),
          ).join().toUpperCase();
          await prefs.setString('saved_hw_device_id', rawHwId);
        }
      }

      final cleanId =
          rawHwId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final resolvedDeviceId = '${widget.appPrefix}-$cleanId';
      _deviceModel = '$_rawModelName (${widget.appShortBadge})';

      if (_deviceId != resolvedDeviceId) {
        _deviceId = resolvedDeviceId;
        final cachedMapStr = prefs.getString('cached_device_status_$_deviceId');
        if (cachedMapStr != null && cachedMapStr.isNotEmpty) {
          final parts = cachedMapStr.split('|');
          if (parts.length >= 4 && mounted) {
            setState(() {
              _deviceRecord = ClientDeviceModel(
                deviceId: _deviceId,
                userName: parts[0],
                deviceModel: _deviceModel,
                osVersion: _osVersion,
                activationCode: parts[1],
                isActivated: parts[2] == 'true',
                status: parts[3],
              );
            });
          }
        } else if (mounted && !_isAccessGranted) {
          setState(() {});
        }
      }

      _supabaseClient = SupabaseClient(
        SupabaseConfig.defaultSupabaseUrl.trim(),
        SupabaseConfig.defaultSupabaseAnonKey.trim(),
      );

      // เช็คข้อมูลครั้งแรกเบื้องหลังโดยไม่บล็อก UI
      unawaited(_fetchLatestDeviceRecordInBackground());

      // เปิด Realtime Stream เบื้องหลัง
      _realtimeSubscription?.cancel();
      _realtimeSubscription = _supabaseClient!
          .from(SupabaseConfig.devicesTable)
          .stream(primaryKey: ['device_id'])
          .eq('device_id', _deviceId)
          .listen(
            (rows) {
              if (!mounted) return;
              if (rows.isEmpty) {
                _applyBackgroundRecordUpdate(null);
              } else {
                _applyBackgroundRecordUpdate(
                  ClientDeviceModel.fromMap(rows.first),
                );
              }
            },
            onError: (_) {},
          );

      // เช็คสถานะซ้ำเบื้องหลังทุก 5 วินาที (ไม่รีเฟรชหน้าจอหากสถานะสิทธิ์เหมือนเดิม)
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _supabaseClient != null) {
          unawaited(_fetchLatestDeviceRecordInBackground());
        }
      });
    } catch (_) {}
  }

  /// อัปเดตสถานะจากเบื้องหลังเฉพาะเมื่อมีการเปลี่ยนแปลงจริงเท่านั้น (ป้องกันหน้าจอกระพริบหรือโหลดใหม่)
  void _applyBackgroundRecordUpdate(ClientDeviceModel? newRecord) {
    if (!mounted) return;
    final bool wasGranted = _isAccessGranted;
    final bool isSame = (_deviceRecord == null && newRecord == null) ||
        (_deviceRecord != null && _deviceRecord!.isSameAuthState(newRecord));

    _saveCachedDeviceRecord(newRecord);

    if (isSame) {
      // สถานะเหมือนเดิมทุกประการ -> ไม่ต้อง setState ให้แอปหลักรีโหลด
      return;
    }

    _deviceRecord = newRecord;
    final bool nowGranted = _isAccessGranted;

    // หากกำลังใช้งานแอปอยู่และสิทธิ์ยังเป็น active เหมือนเดิม ไม่ต้องสั่ง rebuild
    if (wasGranted && nowGranted) {
      return;
    }

    setState(() {});
    _syncNativeScannerState();
  }

  Future<void> _saveCachedDeviceRecord(ClientDeviceModel? record) async {
    try {
      final prefs =
          DeviceAuthGuard._preloadedPrefs ?? await SharedPreferences.getInstance();
      final key = 'cached_device_status_$_deviceId';
      if (record == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(
          key,
          '${record.userName}|${record.activationCode}|${record.isActivated}|${record.status}',
        );
      }
    } catch (_) {}
  }

  /// ดึงข้อมูลเครื่องล่าสุดจาก Supabase เบื้องหลัง (Timeout สั้น ไม่ค้างเมื่อเน็ตช้า/ไม่มีเน็ต)
  Future<void> _fetchLatestDeviceRecordInBackground() async {
    if (_supabaseClient == null) return;

    try {
      final response = await _supabaseClient!
          .from(SupabaseConfig.devicesTable)
          .select()
          .eq('device_id', _deviceId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;
      if (response == null) {
        _applyBackgroundRecordUpdate(null);
      } else {
        _applyBackgroundRecordUpdate(ClientDeviceModel.fromMap(response));
      }
    } catch (_) {
      // เมื่อไม่มีอินเทอร์เน็ตหรือสัญญาณอ่อน จะคงสถานะแคชล่าสุดไว้ ไม่รบกวนการใช้งาน
    }
  }

  /// 1. ฟังก์ชันส่งคำขอลงทะเบียนเครื่องใหม่
  Future<void> _registerDevice() async {
    final userName = _userNameController.text.trim();
    if (userName.isEmpty) {
      setState(() {
        _statusMessage = 'กรุณากรอกชื่อผู้ใช้งาน หรือรหัสพนักงาน';
        _isStatusError = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    try {
      final prefs =
          DeviceAuthGuard._preloadedPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString('device_auth_user_name', userName);

      final newDevice = ClientDeviceModel(
        deviceId: _deviceId,
        userName: userName,
        deviceModel: _deviceModel,
        osVersion: _osVersion,
        activationCode: '',
        isActivated: false,
        status: 'pending',
        registeredAt: DateTime.now().toUtc(),
        activatedAt: null,
      );

      _supabaseClient ??= SupabaseClient(
        SupabaseConfig.defaultSupabaseUrl.trim(),
        SupabaseConfig.defaultSupabaseAnonKey.trim(),
      );

      await _supabaseClient!
          .from(SupabaseConfig.devicesTable)
          .upsert(newDevice.toSupabaseMap())
          .timeout(const Duration(seconds: 6));

      await _saveCachedDeviceRecord(newDevice);
      if (!mounted) return;
      setState(() {
        _deviceRecord = newDevice;
        _statusMessage = null;
      });
      _syncNativeScannerState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
        _isStatusError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// 2. ฟังก์ชันตรวจสอบรหัส 6 หลักและเปิดใช้งานเครื่อง (Activate)
  Future<void> _verifyActivationCode() async {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.length != 6) {
      setState(() {
        _statusMessage = 'กรุณากรอกรหัสยืนยันให้ครบ 6 หลัก';
        _isStatusError = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    try {
      _supabaseClient ??= SupabaseClient(
        SupabaseConfig.defaultSupabaseUrl.trim(),
        SupabaseConfig.defaultSupabaseAnonKey.trim(),
      );

      final latestMap = await _supabaseClient!
          .from(SupabaseConfig.devicesTable)
          .select()
          .eq('device_id', _deviceId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (latestMap == null) {
        await _saveCachedDeviceRecord(null);
        setState(() {
          _deviceRecord = null;
          _statusMessage = 'ไม่พบข้อมูลการลงทะเบียน กรุณาลงทะเบียนใหม่อีกครั้ง';
          _isStatusError = true;
        });
        return;
      }

      final latestDevice = ClientDeviceModel.fromMap(latestMap);
      _deviceRecord = latestDevice;

      if (latestDevice.status.toLowerCase() == 'banned') {
        await _saveCachedDeviceRecord(latestDevice);
        setState(() {
          _statusMessage = null;
        });
        _syncNativeScannerState();
        return;
      }

      if (latestDevice.activationCode.trim().isEmpty) {
        setState(() {
          _statusMessage = 'ผู้ดูแลระบบยังไม่ได้อนุมัติรหัส 6 หลักให้เครื่องนี้';
          _isStatusError = true;
        });
        return;
      }

      if (latestDevice.activationCode.trim() != enteredPin) {
        setState(() {
          _statusMessage = 'รหัสยืนยัน 6 หลักไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
          _isStatusError = true;
        });
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      await _supabaseClient!
          .from(SupabaseConfig.devicesTable)
          .update({
            'is_activated': true,
            'status': 'active',
            'activated_at': nowUtc.toIso8601String(),
          })
          .eq('device_id', _deviceId)
          .timeout(const Duration(seconds: 6));

      final updated = latestDevice.copyWith(
        isActivated: true,
        status: 'active',
        activatedAt: nowUtc,
      );
      await _saveCachedDeviceRecord(updated);
      if (!mounted) return;
      setState(() {
        _deviceRecord = updated;
        _pinController.clear();
        _statusMessage = null;
      });
      _syncNativeScannerState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'ตรวจสอบรหัสไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ต';
        _isStatusError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: _deviceId));
    if (!mounted) return;
    setState(() {
      _statusMessage = 'คัดลอกรหัสเครื่อง $_deviceId แล้ว';
      _isStatusError = false;
    });
  }

  Widget _wrapWithAppShellIfNeeded(Widget guardScreen) {
    if (widget.authenticatedBuilder != null) {
      return MaterialApp(
        title: widget.appName,
        debugShowCheckedModeBanner: false,
        theme: widget.lightTheme ??
            ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                brightness: Brightness.light,
              ),
            ),
        darkTheme: widget.darkTheme,
        themeMode: widget.themeMode,
        home: guardScreen,
      );
    }
    return guardScreen;
  }

  @override
  Widget build(BuildContext context) {
    // หากได้รับสิทธิ์อยู่แล้ว -> เปิดเข้าหน้าแอปหลักทันทีในเฟรมแรก (0ms) โดยตรวจสอบสิทธิ์ซ้ำอยู่เบื้องหลัง
    if (_isAccessGranted) {
      return widget.authenticatedBuilder != null
          ? widget.authenticatedBuilder!(context)
          : (widget.child ?? const SizedBox.shrink());
    }

    // หน้าจอลงทะเบียน / กรอกรหัส 6 หลัก / ล็อกหน้าจอเมื่อถูกแบน (เพียวๆ สมมาตรกึ่งกลาง)
    return _wrapWithAppShellIfNeeded(
      PopScope(
        canPop: false,
        child: _buildPureSymmetricalGuardScreen(context),
      ),
    );
  }

  Widget _buildPureSymmetricalGuardScreen(BuildContext context) {
    final bool isBanned =
        _deviceRecord != null && _deviceRecord!.status.toLowerCase() == 'banned';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor:
            isBanned ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isBanned
                  ? const [Color(0xFFFEE2E2), Color(0xFFFEF2F2)]
                  : const [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 34,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isBanned
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isBanned)
                          _buildBannedContent()
                        else if (_deviceRecord == null)
                          _buildRegistrationContent()
                        else
                          _buildActivationPinContent(),

                        if (_statusMessage != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: _isStatusError
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isStatusError
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              _statusMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isStatusError
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        const SizedBox(height: 18),

                        _buildSymmetricalDeviceFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. เนื้อหาหน้าลงทะเบียนเครื่อง (สมมาตรกึ่งกลางทั้งหมด)
  Widget _buildRegistrationContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFCCFBF1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF99F6E4), width: 4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.verified_user_outlined,
            size: 34,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ลงทะเบียนเครื่องเข้าใช้งาน',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'กรุณาระบุชื่อผู้ใช้งานหรือสาขา\nเพื่อส่งคำขออนุมัติสิทธิ์ไปยังผู้ดูแลระบบ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 26),
        TextField(
          controller: _userNameController,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _registerDevice(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'ชื่อ-นามสกุล / รหัสพนักงาน / สาขา',
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF0F766E), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isBusy ? null : _registerDevice,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'ส่งคำขอลงทะเบียน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// 2. เนื้อหาหน้ากรอกรหัสยืนยัน 6 หลัก (สมมาตรกึ่งกลางทั้งหมด)
  Widget _buildActivationPinContent() {
    final record = _deviceRecord!;
    final bool hasCodeGenerated = record.activationCode.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: hasCodeGenerated
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasCodeGenerated
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFFDE68A),
              width: 4,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            hasCodeGenerated
                ? Icons.vpn_key_rounded
                : Icons.hourglass_top_rounded,
            size: 32,
            color: hasCodeGenerated
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ยืนยันรหัส 6 หลัก',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.userName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 12),

        // ป้ายสถานะสมมาตรกึ่งกลาง
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: hasCodeGenerated
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: hasCodeGenerated
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: Text(
            hasCodeGenerated
                ? '● อนุมัติแล้ว กรุณากรอกรหัส 6 หลัก'
                : '● รอผู้ดูแลระบบสุ่มรหัส 6 หลัก',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hasCodeGenerated
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ช่องกรอกรหัส 6 หลักแบบสมมาตร 100%
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (value.length == 6 && !_isBusy) {
              _verifyActivationCode();
            }
          },
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '• • • • • •',
            hintStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: Color(0xFFCBD5E1),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF0F766E), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ปุ่มยืนยันหลัก
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isBusy ? null : _verifyActivationCode,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'ยืนยันเข้าใช้งาน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // ปุ่มเสริมคู่สมมาตรซ้าย-ขวา (วางรหัส / เปลี่ยนชื่อผู้ใช้)
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isBusy
                    ? null
                    : () async {
                        final data = await Clipboard.getData('text/plain');
                        final raw = data?.text
                                ?.replaceAll(RegExp(r'[^0-9]'), '')
                                .trim() ??
                            '';
                        if (raw.isNotEmpty) {
                          final pin =
                              raw.length > 6 ? raw.substring(0, 6) : raw;
                          _pinController.text = pin;
                          if (pin.length == 6) {
                            _verifyActivationCode();
                          }
                        }
                      },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'วางรหัสที่คัดลอก',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 16,
              color: const Color(0xFFE2E8F0),
            ),
            Expanded(
              child: TextButton(
                onPressed: _isBusy
                    ? null
                    : () {
                        setState(() {
                          _userNameController.text = record.userName;
                          _deviceRecord = null;
                          _statusMessage = null;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'เปลี่ยนชื่อผู้ใช้',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. เนื้อหาหน้าล็อกอัตโนมัติเมื่อถูกแบน (สมมาตรกึ่งกลางทั้งหมด)
  Widget _buildBannedContent() {
    final record = _deviceRecord!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFECACA), width: 4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.lock_person_rounded,
            size: 36,
            color: Color(0xFFDC2626),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ระงับสิทธิ์การใช้งาน',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF991B1B),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.userName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7F1D1D),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Text(
            'เครื่องนี้ถูกระงับสิทธิ์โดยผู้ดูแลระบบ\nหน้าจอจะปลดล็อกอัตโนมัติเมื่อได้รับการปลดบล็อก',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF991B1B),
            ),
          ),
        ),
      ],
    );
  }

  /// ส่วนท้ายการ์ดแสดงรหัสประจำเครื่อง รุ่นมือถือ และช่องทางติดต่อแอดมิน/นักพัฒนาแบบสมมาตร 100%
  Widget _buildSymmetricalDeviceFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: _copyDeviceId,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _deviceId,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: Color(0xFF334155),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_rawModelName • $_osVersion',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'พัฒนาโดย champ สาขา 9544',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: 'champ25690'),
                  );
                  if (!mounted) return;
                  setState(() {
                    _statusMessage = 'คัดลอก Line ID : champ25690 แล้ว';
                    _isStatusError = false;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: const Text(
                    'ติดต่อแอดมิน Line ID : champ25690',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
