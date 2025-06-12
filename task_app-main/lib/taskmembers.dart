// taskmembers.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class TaskMembersPage extends StatefulWidget {
  final String projectId;
  final String currentUserEmail;

  const TaskMembersPage({
    required this.projectId,
    required this.currentUserEmail,
  });

  @override
  _TaskMembersPageState createState() => _TaskMembersPageState();
}

class _TaskMembersPageState extends State<TaskMembersPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<String> _projectMembers = [];
  List<String> _selectedMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjectMembers();
  }

  Future<void> _loadProjectMembers() async {
    final sanitizedEmail = widget.currentUserEmail.replaceAll('.', ',');
    final snapshot = await _db
        .child('members/$sanitizedEmail/projects/${widget.projectId}/assign_to')
        .get();

    if (snapshot.exists) {
      setState(() {
        _projectMembers = List<String>.from(snapshot.value as List<dynamic>);
        _isLoading = false;
      });
    }
  }

  void _toggleMemberSelection(String member) {
    setState(() {
      if (_selectedMembers.contains(member)) {
        _selectedMembers.remove(member);
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  void _confirmSelection() => Navigator.pop(context, _selectedMembers);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Select Members", style: TextStyle(color: Colors.black)),
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
              itemCount: _projectMembers.length,
              itemBuilder: (context, index) {
                final member = _projectMembers[index];
                final isSelected = _selectedMembers.contains(member);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.white,
                  child: ListTile(
                    title: Text(member),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.deepPurple)
                        : null,
                    onTap: () => _toggleMemberSelection(member),
                  ),
                );
              },
            ),
    );
  }
}