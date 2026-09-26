// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

bool get isPWAInstalled {
  try {
    return js.context.callMethod('isAppInstalled') == true;
  } catch (e) {
    return false;
  }
}

void setupPWAInstall(Function onAvailable) {
  try {
    js.context['onInstallPromptAvailable'] = onAvailable;
    if (js.context.callMethod('isInstallPromptReady') == true) {
      onAvailable();
    }
  } catch (e) {}
}

void installPWA() {
  try {
    js.context.callMethod('installPWA');
  } catch (e) {}
}

void updateThemeColor(String hexColor) {
  try {
    final document = js.context['document'];
    if (document != null) {
      final meta = document.callMethod('getElementById', ['theme_color_meta']);
      if (meta != null) {
        meta['content'] = hexColor;
      }
    }
  } catch (e) {}
}
