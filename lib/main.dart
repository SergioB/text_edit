import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Editor with History',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TextEditorScreen(),
    );
  }
}

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Map<String, String> _versions = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _setupKeyboardListeners();
  }

  void _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadVersions();
  }

  void _loadVersions() {
    final versions = _prefs?.getString('versions');
    if (versions != null) {
      setState(() {
        _versions = Map<String, String>.from(json.decode(versions));
      });
    }
  }

  void _saveVersions() {
    _prefs?.setString('versions', json.encode(_versions));
  }

  void _setupKeyboardListeners() {
    _focusNode.onKeyEvent = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.keyS &&
          HardwareKeyboard.instance.isControlPressed &&
          event is KeyDownEvent) {
        _saveCurrentVersion();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyL &&
          HardwareKeyboard.instance.isControlPressed &&
          event is KeyDownEvent) {
        _showLoadDialog();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _saveCurrentVersion() {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    setState(() {
      _versions[timestamp] = _controller.text;
      _saveVersions();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved version at $timestamp')),
    );
  }

  void _showLoadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Version'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _versions.length,
            itemBuilder: (context, index) {
              final timestamp = _versions.keys.toList().reversed.toList()[index];
              return ListTile(
                title: Text(timestamp),
                subtitle: Text(
                  _versions[timestamp]!.length > 50
                      ? '${_versions[timestamp]!.substring(0, 50)}...'
                      : _versions[timestamp]!,
                ),
                onTap: () {
                  _controller.text = _versions[timestamp]!;
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Editor with History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCurrentVersion,
            tooltip: 'Save (Ctrl+S)',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showLoadDialog,
            tooltip: 'Load Version (Ctrl+L)',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Start typing...',
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
