// taskselection.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class TaskSelectionPage extends StatefulWidget {
  final String projectId;
  final String currentUserEmail;

  const TaskSelectionPage({
    required this.projectId,
    required this.currentUserEmail,
  });

  @override
  _TaskSelectionPageState createState() => _TaskSelectionPageState();
}

class _TaskSelectionPageState extends State<TaskSelectionPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<String> _allTasks = [];
  List<String> _selectedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjectTasks();
  }

  Future<void> _loadProjectTasks() async {
    final sanitizedEmail = widget.currentUserEmail.replaceAll('.', ',');
    final snapshot = await _db
        .child('members/$sanitizedEmail/projects/${widget.projectId}/tasks')
        .get();

    if (snapshot.exists) {
      final tasksMap = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _allTasks = tasksMap.values
            .map<String>((task) => task['name']?.toString() ?? 'Unnamed Task')
            .toList();
        _isLoading = false;
      });
    }
  }

  void _toggleTaskSelection(String task) {
    setState(() {
      if (_selectedTasks.contains(task)) {
        _selectedTasks.remove(task);
      } else {
        _selectedTasks.add(task);
      }
    });
  }

  void _confirmSelection() => Navigator.pop(context, _selectedTasks);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Select Tasks", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmSelection,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allTasks.length,
              itemBuilder: (context, index) {
                final task = _allTasks[index];
                final isSelected = _selectedTasks.contains(task);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.white,
                  child: ListTile(
                    title: Text(task),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.deepPurple)
                        : null,
                    onTap: () => _toggleTaskSelection(task),
                  ),
                );
              },
            ),
    );
  }
}