// createtask.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'taskselection.dart';
import 'taskmembers.dart';

class Createtaskpage extends StatefulWidget {
  final String projectId;
  
  const Createtaskpage({required this.projectId});

  @override
  TaskdetailState createState() => TaskdetailState();
}

class TaskdetailState extends State<Createtaskpage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  TextEditingController _taskNameController = TextEditingController();
  TextEditingController _taskDescController = TextEditingController();
  DateTime? _selectedDeadline;
  int? _selectedComplexity;
  List<String> _dependencies = [];
  List<String> _assignedMembers = [];
  String _currentUserEmail = '';

  final List<int> complexityLevels = [1, 2, 3, 4];
  final Map<int, String> complexityLabels = {
    1: "Low",
    2: "Medium",
    3: "High",
    4: "Very High",
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email') ?? '';
    });
  }

  void _pickDeadline() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() => _selectedDeadline = pickedDate);
    }
  }

  void _addDependency() async {
    final selectedTasks = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskSelectionPage(
          projectId: widget.projectId,
          currentUserEmail: _currentUserEmail,
        ),
      ),
    );

    if (selectedTasks != null) {
      setState(() => _dependencies = selectedTasks);
    }
  }

  void _addMembers() async {
    final selectedMembers = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskMembersPage(
          projectId: widget.projectId,
          currentUserEmail: _currentUserEmail,
        ),
      ),
    );

    if (selectedMembers != null) {
      setState(() => _assignedMembers = selectedMembers);
    }
  }

  Future<void> _saveTask() async {
    if (_taskNameController.text.isEmpty ||
        _selectedDeadline == null ||
        _selectedComplexity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    try {
      final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
      final taskRef = _db
          .child('members/$sanitizedEmail/projects/${widget.projectId}/tasks')
          .push();

      await taskRef.set({
        'name': _taskNameController.text,
        'description': _taskDescController.text,
        'due_date': DateFormat('yyyy-MM-dd').format(_selectedDeadline!),
        'complextivity': _selectedComplexity,
        'dependency': _dependencies,
        'assign_to': _assignedMembers,
        'status': false
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving task: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Create Task", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _taskNameController,
                decoration: const InputDecoration(
                  labelText: "Task Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _taskDescController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Task Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  _selectedDeadline == null
                      ? "Select Deadline"
                      : "Deadline: ${DateFormat('yyyy-MM-dd').format(_selectedDeadline!)}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDeadline,
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedComplexity,
                items: complexityLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text("$level - ${complexityLabels[level]}"),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedComplexity = value),
                decoration: const InputDecoration(
                  labelText: "Task Complexity",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Dependencies", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _dependencies.isEmpty
                  ? const Text("No dependencies added",
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dependencies
                          .map((dep) => Chip(
                                label: Text(dep),
                                deleteIcon: const Icon(Icons.close),
                                onDeleted: () => setState(() => _dependencies.remove(dep)),
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Dependency", style: TextStyle(color: Colors.white)),
                onPressed: _addDependency,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Assigned Members",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _assignedMembers.isEmpty
                  ? const Text("No members assigned",
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _assignedMembers
                          .map((member) => Chip(
                                label: Text(member),
                                deleteIcon: const Icon(Icons.close),
                                onDeleted: () => setState(() => _assignedMembers.remove(member)),
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text("Add Member", style: TextStyle(color: Colors.white)),
                onPressed: _addMembers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}