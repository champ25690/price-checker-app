import 'package:flutter/foundation.dart';

String? getDirectImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  
  String directUrl = url;

  // Handle /file/d/ID format
  if (url.contains('drive.google.com/file/d/')) {
    final regex = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      directUrl = 'https://lh3.googleusercontent.com/d/$id=w1000';
    }
  }
  
  // Handle ?id=ID format (open or uc)
  else if (url.contains('drive.google.com/open') || url.contains('drive.google.com/uc')) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('id')) {
      final id = uri.queryParameters['id'];
      directUrl = 'https://lh3.googleusercontent.com/d/$id=w1000';
    }
  }

  // On Web, CanvasKit requires proper CORS headers which Google Drive may not provide.
  // We use a local CORS proxy running on port 8081.
  if (kIsWeb) {
    try {
      final host = Uri.base.host;
      final proxyHost = host.isEmpty ? 'localhost' : host;
      return 'http://$proxyHost:8081/?url=${Uri.encodeComponent(directUrl)}';
    } catch (e) {
      return 'http://localhost:8081/?url=${Uri.encodeComponent(directUrl)}';
    }
  }

  return directUrl;
}
