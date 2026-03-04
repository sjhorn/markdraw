library;

import 'package:flutter/material.dart';

import 'color_utils.dart';
import 'style_icon_painters.dart';

/// A small square color swatch.
class ColorSwatch extends StatelessWidget {
  final String color;
  final bool isSelected;
  final VoidCallback onTap;

  const ColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parsed = parseColor(color);
    final isTransparent = color == 'transparent';
    final isLight = !isTransparent && (parsed.r + parsed.g + parsed.b) > 1.8;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isTransparent ? cs.surface : parsed,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : (isLight || isTransparent)
                    ? cs.outlineVariant
                    : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: isTransparent
            ? CustomPaint(painter: DiagonalLinePainter())
            : null,
      ),
    );
  }
}

/// The 6th swatch that shows the active color and opens a full palette popup.
class ColorPickerButton extends StatelessWidget {
  final String color;
  final bool isActive;
  final ValueChanged<String> onColorSelected;

  const ColorPickerButton({
    super.key,
    required this.color,
    required this.isActive,
    required this.onColorSelected,
  });

  static const paletteColors = [
    ['#f8f9fa', '#e9ecef', '#ced4da', '#868e96', '#343a40'],
    ['#fff5f5', '#ffc9c9', '#ff8787', '#fa5252', '#e03131'],
    ['#fff0f6', '#fcc2d7', '#f783ac', '#e64980', '#c2255c'],
    ['#f8f0fc', '#eebefa', '#da77f2', '#be4bdb', '#9c36b5'],
    ['#f3f0ff', '#d0bfff', '#9775fa', '#7950f2', '#6741d9'],
    ['#e7f5ff', '#a5d8ff', '#4dabf7', '#228be6', '#1971c2'],
    ['#e3fafc', '#99e9f2', '#3bc9db', '#15aabf', '#0c8599'],
    ['#e6fcf5', '#96f2d7', '#38d9a9', '#12b886', '#099268'],
    ['#ebfbee', '#b2f2bb', '#69db7c', '#40c057', '#2f9e44'],
    ['#fff9db', '#ffec99', '#ffd43b', '#fab005', '#f08c00'],
    ['#fff4e6', '#ffd8a8', '#ffa94d', '#fd7e14', '#e8590c'],
    ['#f8f1ee', '#eaddd7', '#d2bab0', '#a18072', '#846358'],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parsed = parseColor(color);
    final isTransparent = color == 'transparent';
    final isLight = !isTransparent && (parsed.r + parsed.g + parsed.b) > 1.8;
    return GestureDetector(
      onTap: () => _showPalettePopup(context),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isTransparent ? cs.surface : parsed,
          border: Border.all(
            color: isActive
                ? cs.primary
                : (isLight || isTransparent)
                    ? cs.outlineVariant
                    : cs.outlineVariant,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: isTransparent
            ? CustomPaint(painter: DiagonalLinePainter())
            : null,
      ),
    );
  }

  void _showPalettePopup(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => ColorPaletteOverlay(
        anchor: offset,
        currentColor: color,
        onSelect: (c) {
          entry.remove();
          onColorSelected(c);
        },
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

/// Full-palette popup overlay with grid + transparent + hex input.
class ColorPaletteOverlay extends StatefulWidget {
  final Offset anchor;
  final String currentColor;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const ColorPaletteOverlay({
    super.key,
    required this.anchor,
    required this.currentColor,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<ColorPaletteOverlay> createState() => _ColorPaletteOverlayState();
}

class _ColorPaletteOverlayState extends State<ColorPaletteOverlay> {
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: widget.currentColor == 'transparent' ? '' : widget.currentColor,
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const swatchSize = 24.0;
    const spacing = 3.0;
    const cols = 5;
    const rows = 12;
    const popupWidth = cols * (swatchSize + spacing) + spacing + 24;
    const popupHeight = (rows + 1) * (swatchSize + spacing) + spacing + 60;

    final screen = MediaQuery.of(context).size;
    var left = widget.anchor.dx - popupWidth / 2 + 14;
    var top = widget.anchor.dy + 34;
    if (left + popupWidth > screen.width - 8) {
      left = screen.width - popupWidth - 8;
    }
    if (left < 8) left = 8;
    if (top + popupHeight > screen.height - 8) {
      top = widget.anchor.dy - popupHeight - 4;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => widget.onSelect('transparent'),
                    child: Container(
                      width: swatchSize,
                      height: swatchSize,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: widget.currentColor == 'transparent'
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width:
                              widget.currentColor == 'transparent' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: CustomPaint(painter: DiagonalLinePainter()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final row in ColorPickerButton.paletteColors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spacing),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final hex in row)
                            Padding(
                              padding: const EdgeInsets.only(right: spacing),
                              child: _buildGridSwatch(hex, swatchSize),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        hintText: '#rrggbb',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (value) {
                        final hex = value.trim();
                        if (_isValidHex(hex)) {
                          widget.onSelect(hex);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridSwatch(String hex, double size) {
    final cs = Theme.of(context).colorScheme;
    final parsed = parseColor(hex);
    final isLight = (parsed.r + parsed.g + parsed.b) > 1.8;
    final isSelected =
        widget.currentColor.toLowerCase() == hex.toLowerCase();
    return GestureDetector(
      onTap: () => widget.onSelect(hex),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: parsed,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : isLight
                    ? cs.outlineVariant
                    : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  bool _isValidHex(String value) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6) return false;
    return int.tryParse(hex, radix: 16) != null;
  }
}
