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
      title: 'Multi-Topic Text Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TextEditorScreen(),
    );
  }
}

class Topic {
  String title;
  Map<String, String> versions;
  String currentContent;

  Topic({
    required this.title,
    Map<String, String>? versions,
    this.currentContent = '',
  }) : versions = versions ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'versions': versions,
    'currentContent': currentContent,
  };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    title: json['title'],
    versions: Map<String, String>.from(json['versions']),
    currentContent: json['currentContent'],
  );
}

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _newTopicController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Topic> _topics = [];
  Topic? _selectedTopic;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _setupKeyboardListeners();
  }

  void _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadTopics();
  }

  void _loadTopics() {
    final topicsJson = _prefs?.getString('topics');
    if (topicsJson != null) {
      final List<dynamic> decoded = json.decode(topicsJson);
      setState(() {
        _topics = decoded.map((t) => Topic.fromJson(t)).toList();
      });
    }
  }

  void _saveTopics() {
    final topicsJson = json.encode(_topics.map((t) => t.toJson()).toList());
    _prefs?.setString('topics', topicsJson);
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
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a topic first')),
      );
      return;
    }

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    setState(() {
      _selectedTopic!.versions[timestamp] = _controller.text;
      _selectedTopic!.currentContent = _controller.text;
      _saveTopics();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved version at $timestamp')),
    );
  }

  void _showLoadDialog() {
    if (_selectedTopic == null || _selectedTopic!.versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No versions available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Load Version - ${_selectedTopic!.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _selectedTopic!.versions.length,
            itemBuilder: (context, index) {
              final timestamp = _selectedTopic!.versions.keys.toList().reversed.toList()[index];
              return ListTile(
                title: Text(timestamp),
                subtitle: Text(
                  _selectedTopic!.versions[timestamp]!.length > 50
                      ? '${_selectedTopic!.versions[timestamp]!.substring(0, 50)}...'
                      : _selectedTopic!.versions[timestamp]!,
                ),
                onTap: () {
                  _controller.text = _selectedTopic!.versions[timestamp]!;
                  _selectedTopic!.currentContent = _controller.text;
                  _saveTopics();
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

  void _showAddTopicDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Topic'),
        content: TextField(
          controller: _newTopicController,
          decoration: const InputDecoration(
            hintText: 'Enter topic name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_newTopicController.text.isNotEmpty) {
                setState(() {
                  _topics.add(Topic(title: _newTopicController.text));
                  _saveTopics();
                });
                _newTopicController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteTopic(Topic topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Topic'),
        content: Text('Are you sure you want to delete "${topic.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _topics.remove(topic);
                if (_selectedTopic == topic) {
                  _selectedTopic = null;
                  _controller.clear();
                }
                _saveTopics();
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Topic Text Editor'),
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
      body: Row(
        children: [
          // Topics sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add New Topic'),
                  onTap: _showAddTopicDialog,
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      return ListTile(
                        title: Text(topic.title),
                        selected: _selectedTopic == topic,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTopic(topic),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedTopic = topic;
                            _controller.text = topic.currentContent;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Text editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _selectedTopic == null
                      ? 'Select a topic to start editing...'
                      : 'Start typing...',
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (value) {
                  if (_selectedTopic != null) {
                    _selectedTopic!.currentContent = value;
                    _saveTopics();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _newTopicController.dispose();
    super.dispose();
  }
}