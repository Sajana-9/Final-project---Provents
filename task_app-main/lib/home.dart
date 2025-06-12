import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'Insights.dart';
import 'add.dart';
import 'budget.dart';
import 'office.dart';
import 'personal.dart';
import 'tasks.dart';
import 'user.dart';
import 'events.dart';
import 'detail.dart';
import 'auth/login.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catogery_projects.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'dart:async'; // Add this import


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showAllTasks = false;
  bool _showAllProjects = false;
  String? userName;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    fetchAndSaveIp(); // Fetch and save IP when the app starts
  }


// In your HomePage or Profile screen
Future<void> _logout() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final googleSignIn = GoogleSignIn();
    
    // Sign out from all providers
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    
    // Clear local storage
    await prefs.clear();
    
    // Navigate to login screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  } catch (e) {
    print('Logout error: $e');
  }
}


  // Fetch IP from Firebase and save to SharedPreferences
Future<void> fetchAndSaveIp() async {
  try {
    // 1. Get IP from Firebase Realtime Database
    final databaseRef = FirebaseDatabase.instance.ref("ip");
    final snapshot = await databaseRef.get();

    if (snapshot.exists) {
      final ip = snapshot.value.toString();

      // 2. Save IP to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ip', ip);
      print("IP saved: $ip");
    } else {
      print("IP not found in Firebase");
    }
  } catch (e) {
    print("Error fetching IP: $e");
  }
}

// Retrieve saved IP from SharedPreferences
Future<String?> getSavedIp() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('ip'); // Returns null if not set
}

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'Guest';
      userEmail = prefs.getString('user_email') ?? 'No email';
    });
  }

  @override
  Widget build(BuildContext context) {
    final double fullWidth = MediaQuery.of(context).size.width - 32;

    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 20),
              _buildTaskProgressCard(context),
              SizedBox(height: 20),
              _buildCard(
                'Add',
                Icons.add,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProjectPage()),
                  );
                },
                width: fullWidth,
                isCentered: true,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCard('Budget', Icons.attach_money_sharp, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Budget()),
                    );
                  }, width: (fullWidth - 8) / 2),
                  _buildCard('Insights', CupertinoIcons.graph_square_fill, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => InsightsPage()),
                    );
                  }, width: (fullWidth - 8) / 2),
                ],
              ),
              SizedBox(height: 20),
              _buildSectionTitle("In Progress", 4),
              _buildInProgressTasks(),
              SizedBox(height: 5),
              _buildSectionTitle("Categories", 3),
              _buildTaskGroups(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage('assets/girly.jpg'),
          ),
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(userName ?? "Guest",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskProgressCard(BuildContext context) {
 
  String? sanitizedEmail = userEmail?.replaceAll('.', ',');

  DatabaseReference userRef = FirebaseDatabase.instance.ref('members/$sanitizedEmail');
  print('[DEBUG] Firebase path: members/$sanitizedEmail');

  return StreamBuilder<DatabaseEvent>(
    stream: userRef.onValue,
    builder: (context, snapshot) {
      double progress = 0.0;
      String progressText = "No pending tasks";
      int percentage = 0;
      int totalTasks = 0;
      int completedTasks = 0;
      final DateTime now = DateTime.now();

      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
        Map<dynamic, dynamic> userData = 
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

        if (userData['projects'] != null) {
          Map<dynamic, dynamic> projects = userData['projects'] as Map;
          projects.forEach((projectId, projectData) {
            final tasks = (projectData as Map)['tasks'] as Map? ?? {};
            tasks.forEach((taskId, taskData) {
              // Null-safe assignment check
              final assignees = (taskData['assign_to'] as List?) ?? [];
              if (assignees.contains(sanitizedEmail)) {
                final dueDateStr = taskData['due_date']?.toString();
                if (dueDateStr != null) {
                  try {
                    final dueDate = DateTime.parse(dueDateStr);
                    final taskDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
                    final currentDate = DateTime(now.year, now.month, now.day);

                    if (taskDueDate.isAfter(currentDate) || taskDueDate.isAtSameMomentAs(currentDate)) {
                      totalTasks++;
                      if ((taskData['status'] as bool?) ?? false) {
                        completedTasks++;
                      }
                    }
                  } catch (e) {
                    print('Error parsing date: $e');
                  }
                }
              }
            });
          });
        }

        if (totalTasks > 0) {
          progress = completedTasks / totalTasks;
          percentage = (progress * 100).round();
          progressText = "$percentage%";
        }
      }

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalTasks == 0 
                    ? "No pending tasks!"
                    : percentage == 100
                      ? "All tasks completed!\nGreat job!"
                      : "Complete ${totalTasks - completedTasks} tasks\nbefore deadline!",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TasksPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: Text("View Tasks",
                      style: TextStyle(color: Colors.deepPurple)),
                ),
              ],
            ),
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  Text(progressText,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
 
  Widget _buildSectionTitle(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(width: 5),
            if (title == "Categories")
              GestureDetector(
                onTap: () => _addNewCategory(context),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: Colors.deepPurple, shape: BoxShape.circle),
                  child: Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
        
      ],
    );
  }

  void _addNewCategory(BuildContext context) {

  String? sanitizedEmail = userEmail?.replaceAll('.', ',');
  final memberRef = FirebaseDatabase.instance.ref('members/$sanitizedEmail/categories');

  showDialog(
    context: context,
    builder: (context) {
      String newCategory = "";
      return AlertDialog(
        title: const Text("Add New Category"),
        content: TextField(
          decoration: const InputDecoration(
            hintText: "Enter category name",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => newCategory = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (newCategory.isNotEmpty) {
                try {
                  // Get current categories
                  final snapshot = await memberRef.get();
                  final currentCategories = snapshot.value as List? ?? [];

                  // Check if category already exists
                  if (currentCategories.contains(newCategory)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$newCategory" already exists')),
                    );
                    return;
                  }

                  // Add new category to the list
                  await memberRef.set([...currentCategories, newCategory]);

                  if (mounted) Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$newCategory" added successfully')),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
              }
            },
            child: const Text("Add"),
          ),
        ],
      );
    },
  );
}
  
  Widget _buildInProgressTasks() {
    final DatabaseReference _db = FirebaseDatabase.instance.ref();
    String? currentUserEmail;

    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final prefs = snapshot.data as SharedPreferences;
          currentUserEmail = prefs.getString('user_email');
          
          if (currentUserEmail == null) {
            return Center(child: Text("User not logged in"));
          }

          final sanitizedEmail = currentUserEmail!.replaceAll('.', ',');
          
          return StreamBuilder(
            stream: _db.child('members/$sanitizedEmail/projects').onValue,
            builder: (context, projectSnapshot) {
              if (projectSnapshot.hasError) {
                return Center(child: Text("Error loading projects"));
              }

              if (projectSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!projectSnapshot.hasData || projectSnapshot.data!.snapshot.value == null) {
                return Center(child: Text("No projects found"));
              }

              final projectsMap = projectSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final projects = projectsMap.entries.map((entry) {
                return {
                  'id': entry.key,
                  'title': entry.value['name'] ?? 'No Name',
                  'category': entry.value['catogory'] ?? 'No Category',
                  'color': _getCategoryColor(entry.value['catogory'] ?? 'Other'),
                };
              }).toList();

              return Column(
                children: [
                  ...projects.take(_showAllProjects ? projects.length : 2).map((project) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailPage(projectId: project['id']),
                          ),
                        );
                      },
                      child: _buildTaskCard(
                        project['title'],
                        project['category'],
                        project['color'],
                      ),
                    );
                  }).toList(),
                  if (projects.length > 2)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllProjects = !_showAllProjects;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showAllProjects ? "Show Less" : "Show More",
                            style: TextStyle(color: Colors.deepPurple),
                          ),
                          Icon(
                            _showAllProjects ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }

Color _getCategoryColor(String category) {
  final random = Random(category.hashCode);
  // Generate colors from a hue spectrum (0-360 degrees)
  return HSVColor.fromAHSV(
    1.0,
    random.nextDouble() * 360,  // Hue (0-360)
    0.7 + random.nextDouble() * 0.3,  // Saturation (0.7-1.0)
    0.8 + random.nextDouble() * 0.2,  // Value/Brightness (0.8-1.0)
  ).toColor();
}

  Widget _buildTaskCard(String title, String category, Color progressColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:const Color.fromRGBO(119, 0, 255, 1).withOpacity(0.21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: TextStyle(fontSize: 14, color: Colors.grey)),
          SizedBox(height: 5),
          Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          LinearProgressIndicator(
              value: 1,
              color: progressColor,
              backgroundColor: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, VoidCallback onTap,
      {double? width, bool isCentered = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      width: width ?? double.infinity,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.grey, offset: Offset(0, 0), blurRadius: 1),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment:
                isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 19),
              SizedBox(width: 10),
              Text(title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskGroups(BuildContext context) {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  return FutureBuilder(
    future: SharedPreferences.getInstance(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final prefs = snapshot.data as SharedPreferences;
        final currentUserEmail = prefs.getString('user_email');

        if (currentUserEmail == null) {
          return Center(child: Text("User not logged in"));
        }

        final sanitizedEmail = currentUserEmail.replaceAll('.', ',');
        
        return StreamBuilder(
          stream: _db.child('members/$sanitizedEmail').onValue,
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return Center(child: Text("Error loading categories"));
            }

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
              return Center(child: Text("No categories found"));
            }

            final userData = userSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            
            // Get categories list from the categories node
            final categories = (userData['categories'] as List?)?.cast<String>() ?? [];
            
            // Get projects data to calculate task counts
            final projectsMap = userData['projects'] as Map<dynamic, dynamic>? ?? {};
            
            // Calculate task counts per category
            Map<String, int> taskCounts = {};
            Map<String, int> completedCounts = {};
            
            projectsMap.forEach((_, project) {
              final category = project['catogory']?.toString() ?? 'Uncategorized';
              final tasks = project['tasks'] as Map<dynamic, dynamic>? ?? {};
              
              taskCounts[category] = (taskCounts[category] ?? 0) + tasks.length;
              
              tasks.forEach((_, task) {
                if ((task['status'] as bool?) ?? false) {
                  completedCounts[category] = (completedCounts[category] ?? 0) + 1;
                }
              });
            });
            
            // Combine both user categories and project categories
            final allCategories = {
              ...categories,
              ...taskCounts.keys.where((c) => !categories.contains(c))
            }.toList();
            
            if (allCategories.isEmpty) {
              return Center(child: Text("No categories available"));
            }

            return Column(
              children: allCategories.map((category) {
                final totalTasks = taskCounts[category] ?? 0;
                final completedTasks = completedCounts[category] ?? 0;
                final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
                
                return _buildTaskGroup(
                  category,
                  totalTasks,
                  progress,
                  _getCategoryColor(category),
                  context,
                  () async { // Changed to callback function
                    // Store selected category in SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_catogery', category);
                    
                    // Navigate to category screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProjectsScreen(category: category),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        );
      }
      return Center(child: CircularProgressIndicator());
    },
  );
}

 Widget _buildTaskGroup(
  String title, 
  int tasks, 
  double progress,
  Color progressColor, 
  BuildContext context, 
  VoidCallback? onTap,
) {
  return GestureDetector(
    onTap: onTap,
    onLongPress: () => _showDeleteCategoryDialog(context, title),
    child: Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 4,
            offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$tasks Tasks", style: TextStyle(color: Colors.grey)),
        trailing: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                color: progressColor,
                backgroundColor: Colors.grey[300]),
              Text("${(progress * 100).toInt()}%",
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> _showDeleteCategoryDialog(BuildContext context, String categoryName) async {
  final completer = Completer<bool>();
  String? sanitizedEmail = userEmail?.replaceAll('.', ',');
  final memberRef = FirebaseDatabase.instance.ref('members/$sanitizedEmail');

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Delete Category"),
        content: Text("Are you sure you want to delete the category '$categoryName'? All projects in this category will be moved to 'Uncategorized'."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              completer.complete(false);
            },
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(child: CircularProgressIndicator()),
                );

                // 1. Get current data
                final snapshot = await memberRef.get();
                final userData = snapshot.value as Map<dynamic, dynamic>;
                final currentCategories = (userData['categories'] as List?)?.cast<String>() ?? [];
                final projectsMap = userData['projects'] as Map<dynamic, dynamic>? ?? {};

                // 2. Prepare updates
                final Map<String, dynamic> updates = {};

                // 2a. Update categories list
                final updatedCategories = currentCategories.where((c) => c != categoryName).toList();
                updates['categories'] = updatedCategories;

                // 2b. Find and update affected projects
                projectsMap.forEach((projectId, projectData) {
                  if (projectData['catogory'] == categoryName) {
                    updates['projects/$projectId/catogory'] = 'Uncategorized'; // or set to null
                  }
                });

                // 3. Execute all updates atomically
                await memberRef.update(updates);

                // 4. Close dialogs
                Navigator.pop(context); // Close loading dialog
                Navigator.pop(context); // Close delete confirmation dialog

                completer.complete(true);
              } catch (e) {
                Navigator.pop(context); // Close loading dialog if still open
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting category: ${e.toString()}')),
                  );
                }
                completer.complete(false);
              }
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );

  return completer.future;
}

}