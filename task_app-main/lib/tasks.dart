import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Notifications.dart';

class TasksPage extends StatefulWidget {
  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Color customPurple = Color(0xFF5F33E1);
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String selectedFilter = "All";
  String selectedDate = "";
  String _currentUserEmail = '';
  List<Map<String, dynamic>> allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now().day.toString();
    _loadCurrentUser();
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
        _currentUserEmail = email.replaceAll('.', ',');
      });
      
      _loadTasks();
    } catch (e) {
      print("Error loading current user: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final today = DateTime.now();
      final fiveDaysLater = today.add(Duration(days: 5));
      
      final userTasksSnapshot = await _db.child('members/$_currentUserEmail/projects').get();
      
      if (userTasksSnapshot.exists) {
        final projects = userTasksSnapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> loadedTasks = [];
        
        projects.forEach((projectId, projectData) {
          if (projectData['tasks'] != null) {
            final tasks = projectData['tasks'] as Map<dynamic, dynamic>;
            
            tasks.forEach((taskId, taskData) {
              if (taskData['due_date'] != null) {
                final dueDate = DateTime.parse(taskData['due_date']);
                
                if (dueDate.isAfter(today.subtract(Duration(days: 1))) && 
                    dueDate.isBefore(fiveDaysLater.add(Duration(days: 1)))) {
                  
                  loadedTasks.add({
                    "id": taskId,
                    "projectId": projectId,
                    "category": projectData['name'] ?? 'No Category',
                    "title": taskData['name'] ?? 'No Title',
                    "time": _formatTime(dueDate),
                    "status": taskData['status'] ?? false,
                    "date": dueDate.day.toString(),
                    "due_date": taskData['due_date'],
                    "color": taskData['status'] == true ? Colors.green : Colors.orange,
                  });
                }
              }
            });
          }
        });
        
        setState(() {
          allTasks = loadedTasks;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  List<Map<String, dynamic>> _getFilteredTasks() {
    return allTasks.where((task) {
      bool matchesDate = task["date"] == selectedDate;
      bool matchesFilter = selectedFilter == "All" || 
                         (selectedFilter == "Done" && task["status"] == true) ||
                         (selectedFilter == "Todo" && task["status"] == false);
      return matchesDate && matchesFilter;
    }).toList();
  }

  List<Map<String, String>> _getDateOptions() {
    final today = DateTime.now();
    final dates = List.generate(5, (index) {
      final date = today.add(Duration(days: index));
      return {
        "day": date.day.toString(),
        "week": _getWeekday(date.weekday),
        "full_date": date.toIso8601String().split('T').first,
      };
    });
    
    return dates;
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Tasks",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationsPage(currentUserEmail: _currentUserEmail,)),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            _buildDatePicker(),
            SizedBox(height: 16),
            _buildFilterButtons(),
            SizedBox(height: 16),
            Expanded(
              child: _getFilteredTasks().isEmpty
                  ? Center(child: Text("No tasks found for selected date"))
                  : ListView.builder(
                      itemCount: _getFilteredTasks().length,
                      itemBuilder: (context, index) {
                        final task = _getFilteredTasks()[index];
                        return _buildTaskCard(
                          task["category"],
                          task["title"],
                          task["time"],
                          task["status"] ? "Done" : "In Progress",
                          task["color"],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final dates = _getDateOptions();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates.map((date) {
          bool isSelected = date["day"] == selectedDate;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDate = date["day"]!;
              });
            },
            child: Container(
              width: 60,
              height: 80,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? customPurple : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(date["week"]!, style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text(
                    date["day"]!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

Widget _buildFilterButtons() {
  List<String> filters = ["All", "Todo", "Done"];

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: filters.map((filter) {
      bool isSelected = filter == selectedFilter;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? customPurple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: customPurple),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : customPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}


  Widget _buildTaskCard(
      String category, String title, String time, String status, Color color) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: customPurple, size: 16),
                SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(
                      fontSize: 14,
                      color: customPurple,
                      fontWeight: FontWeight.bold),
                ),
                Spacer(),
                _buildStatusTag(status, color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}