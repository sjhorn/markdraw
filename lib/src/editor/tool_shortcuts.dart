import 'tool_type.dart';

/// Returns the [ToolType] mapped to the given single-character [key],
/// or `null` if the key is not a tool shortcut.
///
/// Number keys 1–8 map to tools in toolbar order (matching Excalidraw).
/// Letter keys F and H map to frame and hand tools (matching Excalidraw).
/// Keys 9 and 0 are reserved for image and eraser (not yet implemented).
/// Only fires when no modifier keys (Ctrl/Shift) are held.
ToolType? toolTypeForKey(String key) {
  return switch (key) {
    '1' => ToolType.select,
    '2' => ToolType.rectangle,
    '3' => ToolType.diamond,
    '4' => ToolType.ellipse,
    '5' => ToolType.arrow,
    '6' => ToolType.line,
    '7' => ToolType.freedraw,
    '8' => ToolType.text,
    'f' => ToolType.frame,
    'h' => ToolType.hand,
    _ => null,
  };
}

/// Returns the keyboard shortcut label for the given [ToolType],
/// or `null` if no shortcut is assigned.
String? shortcutForToolType(ToolType type) {
  return switch (type) {
    ToolType.select => '1',
    ToolType.rectangle => '2',
    ToolType.diamond => '3',
    ToolType.ellipse => '4',
    ToolType.arrow => '5',
    ToolType.line => '6',
    ToolType.freedraw => '7',
    ToolType.text => '8',
    ToolType.frame => 'F',
    ToolType.hand => 'H',
  };
}
