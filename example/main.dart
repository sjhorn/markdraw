/// Example app using the MarkdrawEditor widget.
///
/// File I/O is handled by [MarkdrawFileHandler], which ships with the
/// package and wires file_picker + platform I/O to the controller.
///
/// Usage:
///   cd example && flutter run
library;

import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:url_launcher/url_launcher.dart';

import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  runApp(MarkdrawApp(
    home: (context, themeMode, onThemeModeChanged) => _CanvasPage(
      themeMode: themeMode,
      onThemeModeChanged: onThemeModeChanged,
    ),
  ));
}

class _CanvasPage extends StatefulWidget {
  const _CanvasPage({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeModeChanged;

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<_CanvasPage> {
  final _controller = MarkdrawController(
    config: MarkdrawEditorConfig(
      onLinkOpen: (url) => launchUrl(Uri.parse(url)),
    ),
  );
  late final _files = MarkdrawFileHandler(controller: _controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdrawEditor(
      controller: _controller,
      onSave: _files.save,
      onSaveAs: _files.saveAs,
      onOpen: _files.open,
      onExportPng: _files.exportPng,
      onExportSvg: _files.exportSvg,
      onImportImage: () => _files.importImage(context),
      onImportLibrary: _files.importLibrary,
      onExportLibrary: _files.exportLibrary,
      onThemeModeChanged: widget.onThemeModeChanged,
      currentThemeMode: widget.themeMode,
    );
  }
}
