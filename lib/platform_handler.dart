// platform_handler.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializePlatform() async {
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(800, 600));

    final prefs = await SharedPreferences.getInstance();
    final savedBounds = prefs.getString('window_bounds');
    if (savedBounds != null) {
      final bounds = json.decode(savedBounds);
      await windowManager.setBounds(Rect.fromLTWH(
        bounds['x'] ?? 0.0,
        bounds['y'] ?? 0.0,
        bounds['width'] ?? 800.0,
        bounds['height'] ?? 600.0,
      ));
    } else {
      await windowManager.setSize(const Size(1024, 768));
      await windowManager.center();
    }
  }
}

class PlatformWrapper extends StatefulWidget {
  final Widget child;

  const PlatformWrapper({super.key, required this.child});

  @override
  State<PlatformWrapper> createState() => _PlatformWrapperState();
}

class _PlatformWrapperState extends State<PlatformWrapper> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await _saveWindowBounds();
    await windowManager.destroy();
  }

  @override
  void onWindowResized() async {
    await _saveWindowBounds();
  }

  @override
  void onWindowMoved() async {
    await _saveWindowBounds();
  }

  Future<void> _saveWindowBounds() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('window_bounds', json.encode({
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      }));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool get isDesktop {
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}