import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'addmembers.dart';
import 'chat.dart';
import 'createtask.dart';
import 'taskdetail.dart';
import 'update_project_member.dart';
import 'package:intl/intl.dart';
import 'feedback.dart';
import 'database.dart';

class DetailPage extends StatefulWidget {
  final String projectId;
  const DetailPage({required this.projectId});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isEditing = false;
  String _currentUserEmail = '';
  List<String> _assignedMembers = [];
  Map<String, dynamic> _tasks = {};
  String? _dueDate;
  String? _category;
  bool _isLoadingTasks = false;
  String _flaskServerUrl = 'http://127.0.0.1:5000';
  bool _sortByPriority = true;
  

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadCurrentUser();
  }



  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email') ?? '';
    });
    _loadProjectData();
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
  await _db.child('members/$sanitizedEmail/projects/${widget.projectId}').remove();
  
  Navigator.pop(context); // Go back to previous screen
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Project deleted')),
  );
}

  Future<void> _loadProjectData() async {
    final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
    
    _db.child('members/$sanitizedEmail/projects/${widget.projectId}').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _titleController.text = data['name'] ?? 'Project Title';
          _descriptionController.text = data['description'] ?? 'Project Description';
          _assignedMembers = List<String>.from(data['assign_to'] ?? []);
          _dueDate = data['due_date'];
          _category = data['catogory'];
          _tasks = data['tasks'] != null ? Map<String, dynamic>.from(data['tasks']) : {};
        });
        
        if (_sortByPriority) {
          await _sortTasksByPriority();
        }
      }
    });
  }

  Future<void> _sortTasksByPriority() async {


      // Get IP from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final String? serverIp = prefs.getString('ip');
  print('Server IP: $serverIp');
  
  if (serverIp == null) {
    throw Exception('No server IP found in SharedPreferences');
  }


    if (_tasks.isEmpty) return;
    
    setState(() => _isLoadingTasks = true);
    
    try {
      List<Map<String, dynamic>> tasksForApi = _tasks.entries.map((entry) {
        return {
          'task_id': entry.key,
          'completed': entry.value['status'] ?? false,
          'complexity': entry.value['complextivity'] ?? 1,
          'deadline': entry.value['due_date'] ?? '',
          'dependencies': entry.value['dependencies']?.join(',') ?? '',
        };
      }).toList();

      final response = await http.post(
        Uri.parse('http://$serverIp:5000/prioritize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tasks': tasksForApi}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prioritizedTasks = jsonDecode(response.body)['prioritized_tasks'];
        Map<String, dynamic> sortedTasks = {};
        for (var task in prioritizedTasks) {
          if (_tasks.containsKey(task['task_id'])) {
            sortedTasks[task['task_id']] = _tasks[task['task_id']];
          }
        }
        _tasks.forEach((taskId, taskData) {
          if (!sortedTasks.containsKey(taskId)) {
            sortedTasks[taskId] = taskData;
          }
        });

        setState(() => _tasks = sortedTasks);
      } else {
        _sortTasksLocally();
      }
    } catch (e) {
      _sortTasksLocally();
    } finally {
      setState(() => _isLoadingTasks = false);
    }
  }

  void _sortTasksLocally() {
    final entries = _tasks.entries.toList();
    entries.sort((a, b) {
      if (a.value['status'] != b.value['status']) {
        return a.value['status'] ? 1 : -1;
      }
      final dateA = DateTime.tryParse(a.value['due_date'] ?? '') ?? DateTime(2100);
      final dateB = DateTime.tryParse(b.value['due_date'] ?? '') ?? DateTime(2100);
      final dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;
      return (b.value['complextivity'] ?? 1).compareTo(a.value['complextivity'] ?? 1);
    });
    setState(() => _tasks = Map.fromEntries(entries));
  }







Future<void> _updateDueDate() async {
  final now = DateTime.now();
  final initialDate = _dueDate != null 
      ? DateTime.parse(_dueDate!) 
      : now.add(const Duration(days: 1)); // Default to tomorrow if no date set

  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: now,
    lastDate: DateTime(now.year + 5), // 5 years in future
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.deepPurple, // Header background color
            onPrimary: Colors.white, // Header text color
            onSurface: Colors.black, // Body text color
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple, // Button text color
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (pickedDate != null) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
    
    try {
      await _db.child('members/$sanitizedEmail/projects/${widget.projectId}').update({
        'due_date': formattedDate
      });
      
      setState(() {
        _dueDate = formattedDate;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dueDate == null 
              ? 'Due date set to ${_formatDate(formattedDate)}' 
              : 'Due date updated to ${_formatDate(formattedDate)}'),
          duration: const Duration(seconds: 2),
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update date: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }
}

Future<void> _toggleTaskStatus(String taskId, bool newStatus) async {
  // Local state update
  setState(() {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId]['status'] = newStatus;
    }
  });

  // Database reference setup
  final sanitizedCurrentEmail = _currentUserEmail.replaceAll('.', ',');
  final taskRef = _db.child(
    'members/$sanitizedCurrentEmail/projects/${widget.projectId}/tasks/$taskId'
  );

  final projectRef = _db.child(
    'members/$sanitizedCurrentEmail/projects/${widget.projectId}'
  );


  // Update task status
  await taskRef.update({'status': newStatus});

  // Handle completion logic
  if (newStatus) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    await taskRef.update({'completed_date': formattedDate});

    final projectSnapshot = await projectRef.get();
    if (projectSnapshot.exists) {
      final projectData = Map<dynamic, dynamic>.from(projectSnapshot.value as Map);
      
    }

    final taskSnapshot = await taskRef.get();
    if (taskSnapshot.exists) {
      final taskData = Map<dynamic, dynamic>.from(taskSnapshot.value as Map);
      final projectData = Map<dynamic, dynamic>.from(projectSnapshot.value as Map);
      final complextivity = taskData['complextivity'] as int? ?? 1;
      final points = complextivity * 5;
      final assignTo = List<String>.from(projectData['assign_to'] ?? []);
      final taskName = taskData['name']?.toString() ?? 'Unnamed Task';

      // Notification payload
      final notification = {
        'type': 'task_completed',
        'taskId': taskId,
        'taskName': taskName,
        'projectId': widget.projectId,
        'projectName': widget.projectId, // Replace with actual project name if available
        'completedBy': _currentUserEmail,
        'completedDate': formattedDate,
        'pointsEarned': points,
        'timestamp': ServerValue.timestamp,
        'read': false,
      };

      // Update all assigned members
      for (final rawEmail in assignTo) {
        final sanitizedEmail = rawEmail.replaceAll('.', ',');
        final memberRef = _db.child('members/$sanitizedEmail');
        
        // Update points
        final memberSnapshot = await memberRef.get();
        if (memberSnapshot.exists) {
          final currentPoints = memberSnapshot.child('points').value as int? ?? 0;
          await memberRef.update({'points': currentPoints + points});
          
          // Add notification
          await memberRef.child('notifications').push().set(notification);
        }
      }
    }
  } else {
    // Handle task un-completion
    await taskRef.child('completed_date').remove();

    final taskSnapshot = await taskRef.get();
    if (taskSnapshot.exists) {
      final taskData = Map<dynamic, dynamic>.from(taskSnapshot.value as Map);
      final complextivity = taskData['complextivity'] as int? ?? 1;
      final points = complextivity * 5;
      final assignTo = List<String>.from(taskData['assign_to'] ?? []);

      for (final rawEmail in assignTo) {
        final sanitizedEmail = rawEmail.replaceAll('.', ',');
        final memberRef = _db.child('members/$sanitizedEmail');
        
        final memberSnapshot = await memberRef.get();
        if (memberSnapshot.exists) {
          final currentPoints = memberSnapshot.child('points').value as int? ?? 0;
          await memberRef.update({'points': currentPoints - points});
        }
      }
    }
  }

  // Refresh task list
  if (_sortByPriority) {
    await _sortTasksByPriority();
  } else {
    _sortTasksLocally();
  }
}
 
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  title: Text(
    "Details",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  actions: [
    IconButton(
      icon: Icon(Icons.delete, color: Colors.red[300]),
      onPressed: _deleteProject,
    ),
    IconButton(
      icon: Icon(Icons.chat, color: Colors.black),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommonChatScreen())),
    ),
  ],
),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectInfoCard(),
            SizedBox(height: 20),
            _buildWhiteCard(_buildAssignedSection()),
            SizedBox(height: 20),
            _buildWhiteCard(_buildTaskSection()),
            SizedBox(height: 30),
            Center(
  child: ElevatedButton.icon(
    label: Text("Feedback", style: TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () {


      // Navigate to the feedback page and pass the projectId and userEmail
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackDatabaseScreen(memberId: _currentUserEmail.replaceAll('.', ','), projectId: widget.projectId,),
        ),
      );
    },
  ),
),

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

  Widget _buildProjectInfoCard() {
    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 120,
          child: Image.asset('assets/pie chart.png', width: 50, height: 50),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Image.asset('assets/smartphone notifications.png', width: 50, height: 50),
        ),
        Positioned(
          bottom: 70,
          right: 10,
          child: Image.asset('assets/desk calendar.png', width: 50, height: 50),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF7700FF).withOpacity(0.21),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _isEditing
                        ? TextField(
                            controller: _titleController,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _titleController.text,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.check : Icons.edit, size: 20, color: Colors.deepPurple),
                    onPressed: () => _isEditing ? _updateProject() : setState(() => _isEditing = true),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _isEditing
                  ? TextField(
                      controller: _descriptionController,
                      style: TextStyle(color: Colors.black),
                      maxLines: 3,
                    )
                  : Text(
                      _descriptionController.text,
                      style: TextStyle(color: Colors.black),
                    ),
              SizedBox(height: 8),
              
             
Padding(
  padding: const EdgeInsets.symmetric(vertical: 4.0),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        _dueDate != null ? "Due: ${_formatDate(_dueDate!)}" : "No due date set",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _dueDate != null ? Colors.black : Colors.grey[600],
          fontStyle: _dueDate == null ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      SizedBox(width: 8),
      GestureDetector(
        onTap: _updateDueDate,
        child: Icon(
          _dueDate != null ? Icons.edit : Icons.add,
          size: 16,
          color: Colors.deepPurple,
        ),
      ),
    ],
  ),
),


              if (_category != null)
                Text(
                  "Category: $_category",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)}";
    } catch (e) {
      return dateString;
    }
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

Widget _buildAssignedSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          "Assigned to",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      SizedBox(
        height: 80, // Increased height to accommodate names
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _assignedMembers.length + 1,
          itemBuilder: (context, index) {
            // Add button at the end
            if (index == _assignedMembers.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: () async {
                          final selected = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddProjectMembers(
                                projectId: widget.projectId,
                                currentUserEmail: _currentUserEmail,
                                existingMembers: _assignedMembers,
                              ),
                            ),
                          );
                          if (selected != null) {
                            final updatedMembers = List<String>.from(
                              [..._assignedMembers, ...selected],
                            ).toSet().toList();
                            final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
                            await _db
                                .child('members/$sanitizedEmail/projects/${widget.projectId}/assign_to')
                                .set(updatedMembers);
                            setState(() => _assignedMembers = updatedMembers);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }
            // Member avatars
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(_assignedMembers[index]),
                    child: Text(
                      _getInitials(_assignedMembers[index]),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60, // Constrain name width
                    child: Text(
                      _assignedMembers[index].split('@').first,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
 
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Createtaskpage(projectId: widget.projectId),
    ),
  ),
  child: CircleAvatar(
    radius: 20,
    backgroundColor: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
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
        if (_isLoadingTasks)
          Center(child: CircularProgressIndicator())
        else if (_tasks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text("No tasks yet")),
          )
        else
          ..._tasks.entries.map((entry) => _buildTaskItem(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildTaskItem(String taskId, dynamic taskData) {
  final name = taskData['name'] ?? 'Unnamed Task';
  final description = taskData['description'] ?? '';
  final status = taskData['status'] ?? false;
  final assignTo = List<String>.from(taskData['assign_to'] ?? []);
  final remainingHours = _calculateRemainingHours(taskData['due_date']);

  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          projectId: widget.projectId,
          taskId: taskId,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () async {
              // Toggle task status
              final newStatus = !status;
              await _toggleTaskStatus(taskId, newStatus);
            },
            behavior: HitTestBehavior.opaque, // Makes entire area tappable
            child: Icon(
              status ? Icons.check_circle : Icons.radio_button_unchecked,
              color: status ? Colors.blue : Colors.grey,
              size: 24,
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 16,
              decoration: status ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) 
                Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              Text("$remainingHours hr"),
            ],
          ),
          trailing: SizedBox(
            width: 70,
            height: 40,
            child: Stack(
              children: List.generate(assignTo.length, (index) {
                if (index < 3) {
                  return Positioned(
                    left: index * 15,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: _getAvatarColor(assignTo[index]),
                      child: Text(
                        _getInitials(assignTo[index]),
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  );
                } else if (index == 3) {
                  return Positioned(
                    left: 3 * 15,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        '+${assignTo.length - 3}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  );
                }
                return Container();
              }),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: status ? 1 : 0.4,
            backgroundColor: Colors.purple[100],
            color: Colors.purple,
            minHeight: 2,
          ),
        ),
        SizedBox(height: 8),
      ],
    ),
  );
}

  int _calculateRemainingHours(String? dueDate) {
  if (dueDate == null || dueDate.isEmpty) return 0;
  try {
    final deadline = DateTime.parse(dueDate);
    final now = DateTime.now();
    final difference = deadline.difference(now);
    return difference.inHours;
  } catch (e) {
    return 0;
  }
}
  
  Color _getAvatarColor(String email) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    return colors[email.hashCode % colors.length];
  }

  String _getInitials(String email) {
    final parts = email.split('@').first.split('.');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return email.substring(0, 2).toUpperCase();
  }

  Future<void> _updateProject() async {
    final sanitizedEmail = _currentUserEmail.replaceAll('.', ',');
    await _db.child('members/$sanitizedEmail/projects/${widget.projectId}').update({
      'name': _titleController.text,
      'description': _descriptionController.text
    });
    setState(() => _isEditing = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}