import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/pwa_manager.dart' as pwa;

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (!pwa.isPWAInstalled) {
        pwa.setupPWAInstall(() {
          if (mounted) {
            setState(() {
              _showBanner = true;
            });
          }
        });
      }
    }
  }

  void _install() {
    pwa.installPWA();
    setState(() {
      _showBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) return const SizedBox.shrink();

    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.download_for_offline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ติดตั้งแอปลงในเครื่องเพื่อใช้งานได้สะดวกยิ่งขึ้น',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _install,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ติดตั้ง'),
          ),
        ],
      ),
    );
  }
}
