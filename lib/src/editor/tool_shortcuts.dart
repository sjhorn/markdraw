import 'tool_type.dart';

/// Returns the [ToolType] mapped to the given single-character [key],
/// or `null` if the key is not a tool shortcut.
///
/// Only lowercase keys are recognized. These shortcuts should only be
/// checked when no modifier keys (Ctrl/Shift) are held.
ToolType? toolTypeForKey(String key) {
  return switch (key) {
    'v' => ToolType.select,
    'r' => ToolType.rectangle,
    'e' => ToolType.ellipse,
    'd' => ToolType.diamond,
    'l' => ToolType.line,
    'a' => ToolType.arrow,
    'p' => ToolType.freedraw,
    't' => ToolType.text,
    'h' => ToolType.hand,
    _ => null,
  };
}
