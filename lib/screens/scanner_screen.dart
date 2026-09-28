import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _torchOn = false;
  bool _detected = false;

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue ?? capture.barcodes.firstOrNull?.displayValue;
    if (barcode == null) return;
    _detected = true;
    HapticFeedback.vibrate();
    _controller.stop();
    // ส่งค่าบาร์โค้ดกลับไปหน้า search
    context.pop(barcode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // กล้อง full screen
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay มืดรอบๆ viewfinder
          _ScannerOverlay(),

          // Status bar area
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.arrow_back,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'สแกนบาร์โค้ด',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // hint text
                const Text(
                  'วางบาร์โค้ดไว้ในกรอบ\nระบบจะค้นหาอัตโนมัติ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                ),

                const SizedBox(height: 28),

                // ปุ่มไฟฉาย + แกลเลอรี
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!kIsWeb) ...[
                      _RoundBtn(
                        icon: _torchOn ? Icons.flash_off : Icons.flash_on,
                        label: _torchOn ? 'ปิดไฟ' : 'ไฟฉาย',
                        onTap: () {
                          _controller.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                      ),
                      const SizedBox(width: 32),
                    ],
                    _RoundBtn(
                      icon: Icons.photo_library_outlined,
                      label: 'แกลเลอรี',
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final capture = await _controller.analyzeImage(image.path);
                          if (capture != null && capture.barcodes.isNotEmpty) {
                            _onDetect(capture);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ไม่พบบาร์โค้ดในรูปภาพนี้')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay มืดรอบ viewfinder + กรอบมุม
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const boxW = 240.0;
    const boxH = 180.0;
    final left = (size.width - boxW) / 2;
    final top = size.height * 0.32;

    return Stack(
      children: [
        // overlay มืด 4 ชิ้น
        Positioned(top: 0, left: 0, right: 0, height: top,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(top: top, left: 0, width: left, height: boxH,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(top: top, right: 0, width: left, height: boxH,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(top: top + boxH, left: 0, right: 0, bottom: 0,
            child: const ColoredBox(color: Color(0x99000000))),

        // เส้นสแกน
        Positioned(
          left: left + 8,
          top: top + boxH / 2,
          width: boxW - 16,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.transparent, kPrimary, Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),

        // กรอบมุม 4 มุม
        ..._corners(left, top, boxW, boxH),
      ],
    );
  }

  List<Widget> _corners(double l, double t, double w, double h) {
    const s = 22.0;
    const th = 3.0;
    const r = 6.0;
    final color = kPrimary;

    return [
      _corner(l, t, s, th, r, color, true, true),
      _corner(l + w - s, t, s, th, r, color, false, true),
      _corner(l, t + h - s, s, th, r, color, true, false),
      _corner(l + w - s, t + h - s, s, th, r, color, false, false),
    ];
  }

  Widget _corner(double l, double t, double s, double th, double r, Color c,
      bool leftSide, bool topSide) {
    return Positioned(
      left: l,
      top: t,
      child: SizedBox(
        width: s,
        height: s,
        child: CustomPaint(painter: _CornerPainter(c, th, r, leftSide, topSide)),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness, radius;
  final bool leftSide, topSide;

  _CornerPainter(this.color, this.thickness, this.radius, this.leftSide, this.topSide);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (leftSide && topSide) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
      path.lineTo(size.width, 0);
    } else if (!leftSide && topSide) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      path.lineTo(size.width, size.height);
    } else if (leftSide && !topSide) {
      path.moveTo(size.width, size.height);
      path.lineTo(radius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - radius);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width - radius, size.height);
      path.quadraticBezierTo(size.width, size.height, size.width, size.height - radius);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
