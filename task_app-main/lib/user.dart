import 'package:flutter/material.dart';
import 'auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _sanitizedEmail = '';
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email') ?? '';
      setState(() {
        _sanitizedEmail = email.replaceAll('.', ',');
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }



  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          backgroundColor: Color.fromRGBO(124, 70, 240, 0.15),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "About"),
              Tab(text: "Work"),
              Tab(text: "Activity"),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildProfileHeader(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children:  [
                        AboutSection(),
                        WorkSection(),
                        ActivitySection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('members/$_sanitizedEmail').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: CircularProgressIndicator(),
          );
        }

        final userData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};
        final joinDate = _formatJoinDate(userData['joinDate']);
        print(userData['profileImage'].toString());
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.9,
          child: Row(
            children: [
CircleAvatar(
  radius: 40,
  backgroundColor: Colors.grey[200],
  child: ClipOval(
    child: Image.network(
      userData['profileImage'].toString(),
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset('assets/girly.jpg', width: 80, height: 80, fit: BoxFit.cover);
      },
    ),
  ),
),

              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData['name']?.toString() ?? 'No Name',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 1),
                    Row(
                      children: [
                        SizedBox(width: 8),
                        Text("Joined ",
                            style: TextStyle(fontSize: 16, color: Colors.black)),
                        Text(joinDate,
                            style: TextStyle(fontSize: 16, color: Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditProfileDialog(context, userData),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatJoinDate(dynamic date) {
    try {
      return DateFormat('MMM y').format(DateTime.parse(date.toString()));
    } catch (e) {
      return 'Apr 2025';
    }
  }

  Future<void> _showEditProfileDialog(
      BuildContext context, Map<dynamic, dynamic> userData) async {
    final nameController = TextEditingController(text: userData['name']?.toString() ?? '');
    final imageController = TextEditingController(
        text: userData['profileImage']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: imageController,
              decoration: InputDecoration(labelText: 'Profile Image URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbRef.child('members/$_sanitizedEmail').update({
                'name': nameController.text,
                'profileImage': imageController.text,
              });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}


class AboutSection extends StatefulWidget {
  @override
  _AboutSectionState createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  late TextEditingController bioController;
  late TextEditingController websiteController;
  late TextEditingController phoneController;

  String userEmail = '';
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    bioController = TextEditingController();
    websiteController = TextEditingController();
    phoneController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('user_email') ?? '';
    setState(() {
      userEmail = email.replaceAll('.', ',');
    });
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    DataSnapshot snapshot = await _dbRef.child('members/$userEmail').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        bioController.text = data['bio']?.toString() ?? '';
        websiteController.text = data['website']?.toString() ?? '';
        phoneController.text = data['phone']?.toString() ?? '';
      });
    }
  }

  Future<void> _showEditBioDialog() async {
    TextEditingController tempBioController = 
      TextEditingController(text: bioController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Bio'),
        content: TextField(
          controller: tempBioController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your bio...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbRef.child('members/$userEmail').update({
                'bio': tempBioController.text,
              });
              _fetchUserData();
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditContactDialog() async {
    TextEditingController tempWebsiteController = 
      TextEditingController(text: websiteController.text);
    TextEditingController tempPhoneController = 
      TextEditingController(text: phoneController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Contact Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempWebsiteController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.link),
                labelText: 'Website',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: tempPhoneController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbRef.child('members/$userEmail').update({
                'website': tempWebsiteController.text,
                'phone': tempPhoneController.text,
              });
              _fetchUserData();
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    bioController.dispose();
    websiteController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  TextStyle get _sectionTitleStyle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.grey[800],
  );

  TextStyle get _bodyTextStyle => TextStyle(
    fontSize: 16,
    color: Colors.grey[700],
  );

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : 'Not provided',
              style: _bodyTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BIO", style: _sectionTitleStyle),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: _showEditBioDialog,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            bioController.text.isNotEmpty 
                ? bioController.text
                : 'No bio available',
            style: _bodyTextStyle,
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CONTACT INFORMATION", style: _sectionTitleStyle),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: _showEditContactDialog,
              ),
            ],
          ),
          SizedBox(height: 8),
          Column(
            children: [
              _buildInfoRow(Icons.link, websiteController.text),
              _buildInfoRow(Icons.phone, phoneController.text),
            ],
          ),
        ],
      ),
    );
  }
}



class WorkSection extends StatefulWidget {
  @override
  _WorkSectionState createState() => _WorkSectionState();
}

class _WorkSectionState extends State<WorkSection> {
  late TextEditingController typeController;
  late TextEditingController locationController;
  late TextEditingController experienceController;

  String userEmail = '';
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    typeController = TextEditingController();
    locationController = TextEditingController();
    experienceController = TextEditingController();
    _loadUserData(); // Don't initialize _statsFuture here
  }

  Future<void> _loadUserData() async {
  final prefs = await SharedPreferences.getInstance();
  String email = prefs.getString('user_email') ?? '';
  userEmail = email.replaceAll('.', ',');

  await _fetchWorkInfo();

  setState(() {
    _statsFuture = _calculateStats(); // Initialize after userEmail is set
  });
}

  Future<void> _fetchWorkInfo() async {
    DataSnapshot snapshot = await _dbRef.child('members/$userEmail').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        typeController.text = data['position']?.toString() ?? 'Software Engineer';
        locationController.text = data['location']?.toString() ?? 'Pasadena, CA';
        experienceController.text = data['experience']?.toString() ?? '4 years';
      });
    }
  }

  Future<Map<String, dynamic>> _calculateStats() async {
    DataSnapshot snapshot = await _dbRef.child('members/$userEmail/projects').get();
    int totalProjects = 0;
    int onTimeTasks = 0;
    int totalTasks = 0;
    int incompleteProjects = 0;
    int points = 0;

    if (snapshot.exists) {
      Map<dynamic, dynamic> projects = snapshot.value as Map<dynamic, dynamic>;
      totalProjects = projects.length;

      projects.forEach((projectId, projectData) {
        bool projectIncomplete = false;
        if (projectData['tasks'] != null) {
          Map<dynamic, dynamic> tasks = Map.from(projectData['tasks']);
          totalTasks += tasks.length;

          tasks.forEach((taskId, task) {
            if (task['status'] == true) {
              if (task['completed_date'] != null && task['due_date'] != null) {
                DateTime dueDate = DateTime.parse(task['due_date']);
                DateTime completedDate = DateTime.parse(task['completed_date']);
                if (completedDate.isBefore(dueDate) || completedDate.isAtSameMomentAs(dueDate)) {
                  onTimeTasks++;
                }
              }
            } else {
              projectIncomplete = true;
            }
          });
        }
        if (projectIncomplete) incompleteProjects++;
      });
    }

    DataSnapshot pointsSnapshot = await _dbRef.child('members/$userEmail/points').get();
    points = pointsSnapshot.exists ? (pointsSnapshot.value as int? ?? 0) : 0;

    return {
      'totalProjects': totalProjects,
      'onTimeRate': totalTasks > 0 ? ((onTimeTasks / totalTasks) * 100).round() : 0,
      'incompleteProjects': incompleteProjects,
      'points': points,
    };
  }

  Future<void> _showEditWorkDialog() async {
    TextEditingController tempType = TextEditingController(text: typeController.text);
    TextEditingController tempLocation = TextEditingController(text: locationController.text);
    TextEditingController tempExperience = TextEditingController(text: experienceController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Work Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempType,
                decoration: InputDecoration(labelText: 'Position'),
              ),
              TextField(
                controller: tempLocation,
                decoration: InputDecoration(labelText: 'Location'),
              ),
              TextField(
                controller: tempExperience,
                decoration: InputDecoration(labelText: 'Experience'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbRef.child('members/$userEmail').update({
                'position': tempType.text,
                'location': tempLocation.text,
                'experience': tempExperience.text,
              });
              _fetchWorkInfo();
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

Widget _buildStatBox(String value, String label) {
  return Expanded(
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF7700FF).withOpacity(0.21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ],
      ),
    ),
  );
}

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("WORK INFORMATION",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: _showEditWorkDialog,
              ),
            ],
          ),
          SizedBox(height: 16),
          Column(
            children: [
              _buildInfoRow(Icons.work, "Position: ${typeController.text}"),
              _buildInfoRow(Icons.location_on, locationController.text),
              _buildInfoRow(Icons.star, "Experience: ${experienceController.text}"),
            ],
          ),
          SizedBox(height: 16),
          Text("STATS",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();

              final stats = snapshot.data!;
              return Column(
                children: [
                  Row(
                    children: [
                      _buildStatBox(stats['totalProjects'].toString(), "Projects"),
                      SizedBox(width: 16),
                      _buildStatBox("${stats['onTimeRate']}%", "On Time Rate"),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatBox(stats['incompleteProjects'].toString(), "Teams"),
                      SizedBox(width: 16),
                      _buildStatBox(stats['points'].toString(), "Points"),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    typeController.dispose();
    locationController.dispose();
    experienceController.dispose();
    super.dispose();
  }
}


class ActivitySection extends StatefulWidget {
  @override
  _ActivitySectionState createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  String userEmail = '';
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> completedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('user_email') ?? '';
    setState(() {
      userEmail = email.replaceAll('.', ',');
    });
    _fetchCompletedTasks();
  }

  Future<void> _fetchCompletedTasks() async {
    DataSnapshot snapshot = await _dbRef.child('members/$userEmail/projects').get();
    List<Map<String, dynamic>> tasks = [];

    if (snapshot.exists) {
      Map<dynamic, dynamic> projects = snapshot.value as Map<dynamic, dynamic>;
      
      projects.forEach((projectId, projectData) {
        if (projectData['tasks'] != null) {
          Map<dynamic, dynamic> taskMap = projectData['tasks'];
          taskMap.forEach((taskId, taskData) {
            if (taskData['status'] == true && taskData['completed_date'] != null) {
              tasks.add({
                'taskName': taskData['name'] ?? 'Unnamed Task',
                'projectName': projectData['name'] ?? 'Unnamed Project',
                'completedDate': taskData['completed_date'],
                'hoursAgo': _calculateHoursAgo(taskData['completed_date']),
              });
            }
          });
        }
      });

      // Sort by completed date (newest first) and take top 5
      tasks.sort((a, b) => b['completedDate'].compareTo(a['completedDate']));
      setState(() {
        completedTasks = tasks.take(5).toList();
      });
    }
  }

  String _calculateHoursAgo(String dateString) {
    try {
      DateTime completedDate = DateTime.parse(dateString);
      Duration difference = DateTime.now().difference(completedDate);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RECENT ACTIVITY", style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          )),
          SizedBox(height: 16),
          if (completedTasks.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("No recent activity", style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              )),
            )
          else
            ...completedTasks.map((task) => 
              _buildActivityItem(
                "Completed '${task['taskName']}' in ${task['projectName']}",
                task['hoursAgo'],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                )),
                SizedBox(height: 4),
                Text(time, style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


Widget _buildInfoRow(IconData icon, String text) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 16, color: Colors.black)),
      ],
    ),
  );
}

Widget _buildStatBox(String value, String label) {
  return Expanded(
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF7700FF).withOpacity(0.21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ],
      ),
    ),
  );
}

Widget _buildActivityItem(String title, String time) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(Icons.circle, color: Colors.blue, size: 8),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: Colors.black)),
            Text(time, style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ],
    ),
  );
}

final TextStyle _sectionTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: Colors.black,
);

final TextStyle _bodyTextStyle = TextStyle(
  fontSize: 16,
  color: Colors.grey[700],
);
