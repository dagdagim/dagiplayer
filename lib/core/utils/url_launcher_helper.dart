import 'package:flutter/services.dart';

class UrlLauncherHelper {
  static const _channel = MethodChannel('com.dagi.dagiplayer/launcher');

  /// Opens the given [url] in the default system browser.
  static Future<bool> openUrl(String url) async {
    try {
      final success = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Copies [text] to the system clipboard.
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
