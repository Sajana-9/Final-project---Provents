import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'taskmembers.dart';
import 'taskselection.dart';

class TaskDetailPage extends StatefulWidget {
  final String projectId;
  final String? taskId;
  const TaskDetailPage({required this.projectId, this.taskId});

  @override
  _TaskDetailPageState createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  String _currentUserEmail = '';
  int _complexity = 1;
  int _priority = 1;
  List<String> _dependencies = [];
  List<String> _assignedMembers = [];
  DateTime? _dueDate;
  bool _isNewTask = true;
  bool _isLoading = true;

  final Map<int, String> priorityLabels = {
    1: "Low",
    2: "Medium",
    3: "High",
    4: "Very High",
  };

  final Map<int, Color> priorityColors = {
    1: Colors.green,
    2: Colors.blue,
    3: Colors.orange,
    4: Colors.red,
  };

@override
void initState() {
  super.initState();
  
  _isNewTask = widget.taskId == null;
  
  // Load user first, then conditionally load task data
  _loadCurrentUser().then((_) {
    if (!_isNewTask) {
      _loadTaskData();
    } else {
      setState(() => _isLoading = false);
    }
  });
}

Future<void> _deleteProject() async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete Project'),
      content: Text('Are you sure you want to delete this project and all its tasks?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (shouldDelete != true) return;

  final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
  await _db.child('members/$sanitizedEmail/projects/${widget.projectId}/tasks/${widget.taskId}').remove();
  
  Navigator.pop(context); // Go back to previous screen
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Task deleted')),
  );
}

Future<void> _loadCurrentUser() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    
    if (email.isEmpty) {
      print("No email found in SharedPreferences");
      return;
    }
    
    setState(() {
      _currentUserEmail = email;
      print("Current user email set to: $_currentUserEmail");
    });
  } catch (e) {
    print("Error loading current user: $e");
  }
}

  Future<void> _loadTaskData() async {
  bool _hasError = false; // Starts as false
  try {
    // Fix email format - replace . with , to match your DB structure
    final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
    print(_currentUserEmail);
    
    // Correct path to tasks - they're under projects/{projectId}/tasks
    final taskSnapshot = await _db.child(
      'members/$sanitizedEmail/projects/${widget.projectId}/tasks/${widget.taskId}'
    ).get();

    print("Trying to load from path: members/$sanitizedEmail/projects/${widget.projectId}/tasks/${widget.taskId}");
    
    if (taskSnapshot.exists) {
      final taskData = taskSnapshot.value as Map<dynamic, dynamic>;
      
      setState(() {
        _nameController.text = taskData['name'] ?? '';
        _descController.text = taskData['description'] ?? '';
        _complexity = taskData['complextivity'] ?? 1;
        _priority = taskData['priority'] ?? 1;
        _assignedMembers = List<String>.from(taskData['assign_to'] ?? []);
        _dependencies = List<String>.from(taskData['dependencies'] ?? []);
        
        if (taskData['due_date'] != null) {
          try {
            _dueDate = DateTime.parse(taskData['due_date']);
            _dueDateController.text = _formatDate(_dueDate!);
          } catch (e) {
            print("Error parsing date: ${taskData['due_date']}");
          }
        }
        
        _isLoading = false;
      });
    } else {
      print("Snapshot doesn't exist at the specified path");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  } catch (e) {
    print("Error loading task data: $e");
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }
}

  Future<void> _saveTask() async {
    final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
    final taskData = {
      'name': _nameController.text,
      'description': _descController.text,
      'complextivity': _complexity,
      'priority': _priority,
      'assign_to': _assignedMembers,
      'dependencies': _dependencies,
      'status': false,
      'due_date': _dueDate?.toIso8601String().split('T').first,
    };

    if (_isNewTask) {
      final newTaskRef = _db.child(
          'members/$sanitizedEmail/projects/${widget.projectId}/tasks').push();
      await newTaskRef.set(taskData);
    } else {
      await _db.child(
          'members/$sanitizedEmail/projects/${widget.projectId}/tasks/${widget.taskId}')
          .update(taskData);
    }
    
    Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateController.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _selectMembers() async {
    final selectedMembers = await Navigator.push(
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

  Future<void> _selectDependencies() async {
    final selectedTasks = await Navigator.push(
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isNewTask) {
      return Scaffold(
        backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isNewTask ? "New Task" : "Task Details",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
            IconButton(
      icon: Icon(Icons.delete, color: Colors.red[300]),
      onPressed: _deleteProject,
    ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 24),
            _buildDetailsCard(),
            const SizedBox(height: 24),
            _buildTeamSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    cursorColor: Colors.deepPurple,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Task name",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.deepPurple),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColors[_complexity],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${priorityLabels[_complexity]}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              cursorColor: Colors.black,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Task description",
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.calendar_today,
                  "Deadline",
                  _dueDate != null ? _formatDate(_dueDate!) : "Select date",
                  onTap: _selectDate,
                ),
                _buildPrioritySelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      children: [
        const Icon(Icons.flag, size: 20, color: Colors.deepPurple),
        const SizedBox(height: 6),
        const Text(
          "Priority",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _showPriorityOptions,
          child: Text(
            priorityLabels[_complexity]!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showPriorityOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Priority",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...priorityLabels.entries.map((entry) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: priorityColors[entry.key],
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text("${entry.key} - ${entry.value}"),
                onTap: () {
                  setState(() => _complexity = entry.key);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsCard() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Task Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selectDependencies,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.link, size: 20, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      "Dependencies",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dependencies
                      .map((task) => Chip(
                            label: Text(task),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _dependencies.remove(task);
                              });
                            },
                            backgroundColor: Colors.grey[200],
                            labelStyle: const TextStyle(color: Colors.black87),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTeamSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          "Team Members",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _assignedMembers.length + 1,
          itemBuilder: (context, index) {
            if (index == _assignedMembers.length) {
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey[200],
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    onPressed: _selectMembers,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Stack(
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: _getMemberColor(index),
                        child: Text(
                          _getInitials(_assignedMembers[index]),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _assignedMembers[index].split('@').first,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _assignedMembers.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildInfoItem(IconData icon, String title, String value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemberColor(int index) {
    final colors = [
      Colors.deepPurple,
      Colors.blueAccent,
      Colors.teal,
      Colors.orange,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  String _getInitials(String email) {
    final parts = email.split('@').first.split('.');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return email.substring(0, 2).toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }
}