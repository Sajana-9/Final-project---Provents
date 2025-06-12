import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'detail.dart';
import 'projects.dart';

class CategoryProjectsScreen extends StatefulWidget {
  final String category;

  const CategoryProjectsScreen({required this.category});

  @override
  _CategoryProjectsScreenState createState() => _CategoryProjectsScreenState();
}

class _CategoryProjectsScreenState extends State<CategoryProjectsScreen> {
  List<Map<String, dynamic>> selectedProjects = [];
  bool showRemoveButton = false;
Future<void> _removeCategoryFromProject(String projectId) async {
  final prefs = await SharedPreferences.getInstance();
  final currentUserEmail = prefs.getString('user_email');

  if (currentUserEmail == null) return;

  final sanitizedEmail = currentUserEmail.replaceAll('.', ',');
  final _db = FirebaseDatabase.instance.ref();

  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    // Set category to "Uncategorized" instead of null
    await _db.child('members/$sanitizedEmail/projects/$projectId/catogory')
      .set("Uncategorized");

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Project moved to Uncategorized')),
    );
  } catch (e) {
    // Close loading dialog if still open
    if (mounted) Navigator.pop(context);
    
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    final DatabaseReference _db = FirebaseDatabase.instance.ref();
    String? currentUserEmail;

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
            stream: _db.child('members/$sanitizedEmail/projects').onValue,
            builder: (context, projectSnapshot) {
              if (projectSnapshot.hasError) {
                return Center(child: Text("Error loading projects"));
              }

              if (projectSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final List<Map<String, dynamic>> projects = [];
              if (projectSnapshot.hasData && projectSnapshot.data!.snapshot.value != null) {
                final projectsMap = projectSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                projectsMap.forEach((projectId, projectData) {
                  if (projectData['catogory'] == widget.category) {
                    projects.add({
                      'id': projectId,
                      'title': projectData['name'] ?? 'Untitled Project',
                      'dueDate': projectData['due_date'] ?? 'No due date',
                    });
                  }
                });
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
                    widget.category,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.black, size: 30),
                      onPressed: () async {
                        final selected = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProjectsPage()),
                        );
                        // Handle project addition
                      },
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isSelected = selectedProjects.contains(project);
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailPage(projectId: project['id']),
                            ),
                          );
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("Remove from Category"),
                              content: Text("Remove this project from ${widget.category} category?"),
                              actions: [
                                TextButton(
                                  child: Text("Cancel"),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                TextButton(
                                  child: Text("Remove", style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _removeCategoryFromProject(project['id']);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                        child: ProjectCard(
                          title: project['title'],
                          dueDate: project['dueDate'],
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String dueDate;
  final bool isSelected;

  const ProjectCard({
    required this.title,
    required this.dueDate,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.deepPurple.withOpacity(0.7)
            : Colors.purple.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Due date: $dueDate",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}