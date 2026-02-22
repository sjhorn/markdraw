import 'package:flutter/services.dart';

/// Abstraction for system clipboard access.
///
/// Allows mocking in tests and provides a single point of control
/// for clipboard I/O across platforms.
abstract class ClipboardService {
  /// Copies [text] to the system clipboard.
  Future<void> copyText(String text);

  /// Reads text from the system clipboard, or null if unavailable.
  Future<String?> readText();
}

/// Default implementation using Flutter's [Clipboard] API.
class FlutterClipboardService implements ClipboardService {
  const FlutterClipboardService();

  @override
  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<String?> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
