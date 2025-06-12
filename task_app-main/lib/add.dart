import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'addmembers.dart';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController = TextEditingController();
  DateTime? _dueDate;
  List<String> _selectedMembers = [];
  String _currentUserEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email') ?? '';
      if (_currentUserEmail.isNotEmpty && !_selectedMembers.contains(_currentUserEmail)) {
        _selectedMembers.add(_currentUserEmail);
      }
    });
  }

  Future<void> _createProject() async {
    if (_projectNameController.text.isEmpty) {
      _showError('Project name is required');
      return;
    }

    try {
      final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
      final projectRef = _db.child('members/$sanitizedEmail/projects').push();

      final projectData = {
        'name': _projectNameController.text,
        'description': _projectDescriptionController.text,
        'due_date': _dueDate != null
            ? DateFormat('yyyy-MM-dd').format(_dueDate!)
            : '',
        'assign_to': _selectedMembers.map((email) => email.replaceAll('.', ',')).toList(),
        'tasks': {}
      };

      await projectRef.set(projectData);
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Error creating project: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Add New",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF5F33E1),
        child: Icon(Icons.save, color: Colors.white),
        onPressed: _createProject,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectInfoSection(),
            SizedBox(height: 20),
            _buildWhiteCard(_buildTeamMembersSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteCard(Widget child) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildProjectInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF7700FF).withOpacity(0.21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _projectNameController,
            decoration: InputDecoration(
              hintText: "Name",
              border: InputBorder.none,
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _projectDescriptionController,
            decoration: InputDecoration(
              hintText: "Description",
              border: InputBorder.none,
            ),
            style: TextStyle(color: Colors.black),
            maxLines: 3,
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dueDate == null
                    ? "Due Date: Add Due Date"
                    : "Due Date: ${_dueDate!.toLocal().toString().split(' ')[0]}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today, color: Colors.deepPurple),
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dueDate = pickedDate;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Assigned to",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () async {
                final selected = await Navigator.push<List<String>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MembersPage(
                      currentUserEmail: _currentUserEmail,
                    ),
                  ),
                );
                if (selected != null) {
                  setState(() {
                    _selectedMembers = {..._selectedMembers, ...selected}.toList();
                  });
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.deepPurple,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _selectedMembers.isEmpty
            ? Text("No members assigned yet.", style: TextStyle(color: Colors.grey))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedMembers.map((email) => Chip(
                  label: Text(email),
                  deleteIcon: Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _selectedMembers.remove(email)),
                )).toList(),
              ),
      ],
    );
  }
}
