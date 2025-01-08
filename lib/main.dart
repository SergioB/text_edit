import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
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

class FileData {
  final String content;
  final DateTime timestamp;

  FileData(this.content, this.timestamp);

  Map<String, dynamic> toJson() => {
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FileData.fromJson(Map<String, dynamic> json) => FileData(
    json['content'] as String,
    DateTime.parse(json['timestamp'] as String),
  );
}

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<FileData> _versions = [];
  String? _currentFilePath;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _setupKeyboardListeners();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final lastFilePath = _prefs?.getString('lastFilePath');
    final lastTimestamp = _prefs?.getString('lastTimestamp');

    if (lastFilePath != null) {
      final file = File(lastFilePath);
      if (await file.exists()) {
        try {
          await _loadFile(file);
          // Only try to load specific version if we have versions loaded
          if (lastTimestamp != null && _versions.isNotEmpty) {
            final targetTimestamp = DateTime.parse(lastTimestamp);
            _loadSpecificVersion(targetTimestamp);
          }
        } catch (e) {
          debugPrint('Error loading last file: $e');
          // Clear invalid preferences
          await _prefs?.remove('lastFilePath');
          await _prefs?.remove('lastTimestamp');
        }
      } else {
        // Clear preferences if file doesn't exist
        await _prefs?.remove('lastFilePath');
        await _prefs?.remove('lastTimestamp');
      }
    }
  }

  void _loadSpecificVersion(DateTime targetTimestamp) {
    if (_versions.isEmpty) {
      return; // Don't do anything if there are no versions
    }

    final targetVersion = _versions.lastWhere(
          (version) => version.timestamp.isBefore(targetTimestamp) ||
          version.timestamp.isAtSameMomentAs(targetTimestamp),
      orElse: () => _versions.last,
    );
    _controller.text = targetVersion.content;
  }


  void _setupKeyboardListeners() {
    _focusNode.onKeyEvent = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.keyS &&
          HardwareKeyboard.instance.isControlPressed &&
          event is KeyDownEvent) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _saveAs();
        } else {
          _saveCurrentVersion();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyO &&
          HardwareKeyboard.instance.isControlPressed &&
          event is KeyDownEvent) {
        _openFile();
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

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = File(result.files.single.path!);
      await _loadFile(file);
    }
  }

  Future<void> _loadFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content);

      final newVersions = (data as List)
          .map((v) => FileData.fromJson(v as Map<String, dynamic>))
          .toList();

      setState(() {
        _currentFilePath = file.path;
        _versions = newVersions;
        if (_versions.isNotEmpty) {
          _controller.text = _versions.last.content;
        }
      });

      // Save the current file path to preferences
      await _prefs?.setString('lastFilePath', file.path);
      if (_versions.isNotEmpty) {
        await _prefs?.setString('lastTimestamp', _versions.last.timestamp.toIso8601String());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File loaded successfully')),
      );
    } catch (e) {
      debugPrint('Error loading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading file: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveAs() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save As',
      fileName: 'document.json',
    );
    if (result != null) {
      setState(() => _currentFilePath = result);
      await _saveCurrentVersion();
    }
  }

  Future<void> _saveCurrentVersion() async {
    if (_currentFilePath == null) {
      await _saveAs();
      return;
    }

    final timestamp = DateTime.now();
    final newVersion = FileData(_controller.text, timestamp);

    setState(() {
      _versions.add(newVersion);
    });

    try {
      final file = File(_currentFilePath!);
      await file.writeAsString(json.encode(
        _versions.map((v) => v.toJson()).toList(),
      ));

      // Save the current timestamp to preferences
      await _prefs?.setString('lastTimestamp', timestamp.toIso8601String());
      await _prefs?.setString('lastFilePath', _currentFilePath!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Saved version at ${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}'
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving file')),
      );
    }
  }

  void _showLoadDialog() {
    if (_versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No versions available')),
      );
      return;
    }

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
              final version = _versions.reversed.toList()[index];
              final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss')
                  .format(version.timestamp);
              return ListTile(
                title: Text(timestamp),
                subtitle: Text(
                  version.content.length > 50
                      ? '${version.content.substring(0, 50)}...'
                      : version.content,
                ),
                onTap: () async {
                  _controller.text = version.content;
                  // Save the selected version timestamp
                  await _prefs?.setString('lastTimestamp', version.timestamp.toIso8601String());
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
        title: Text(_currentFilePath != null
            ? 'Editing: ${_currentFilePath!.split(Platform.pathSeparator).last}'
            : 'Text Editor with History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openFile,
            tooltip: 'Open File (Ctrl+O)',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCurrentVersion,
            tooltip: 'Save (Ctrl+S)',
          ),
          IconButton(
            icon: const Icon(Icons.save_as),
            onPressed: _saveAs,
            tooltip: 'Save As (Ctrl+Shift+S)',
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
