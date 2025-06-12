import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

class ProjectsPage extends StatefulWidget {
  @override
  _ProjectsPageState createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Map<String, dynamic>> allProjects = [];
  List<Map<String, dynamic>> selectedProjects = [];
  String? userEmail;
  bool isLoading = true;
  String? targetCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('user_email');
    targetCategory = prefs.getString('selected_catogery');
    
    if (userEmail == null) {
      setState(() => isLoading = false);
      return;
    }

    await _loadUserProjects();
    setState(() => isLoading = false);
  }

  Future<void> _loadUserProjects() async {
    final sanitizedEmail = userEmail!.replaceAll('.', ',');
    final projectsRef = FirebaseDatabase.instance.ref('members/$sanitizedEmail/projects');

    try {
      final snapshot = await projectsRef.get();
      if (snapshot.exists) {
        final projectsMap = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> loadedProjects = [];

        projectsMap.forEach((projectId, projectData) {
          loadedProjects.add({
            'id': projectId,
            'title': projectData['name'] ?? 'Untitled Project',
            'dueDate': _formatDate(projectData['due_date']),
            'description': projectData['description'] ?? '',
            'category': projectData['catogory'] ?? 'Uncategorized',
          });
        });

        setState(() => allProjects = loadedProjects);
      }
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'No due date';
    try {
      final parsedDate = DateTime.parse(date.toString());
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _updateProjectsCategory() async {
    if (selectedProjects.isEmpty || targetCategory == null || userEmail == null) {
      return;
    }

    final sanitizedEmail = userEmail!.replaceAll('.', ',');
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    final batchUpdates = <String, dynamic>{};

    for (final project in selectedProjects) {
      final projectPath = 'members/$sanitizedEmail/projects/${project['id']}/catogory';
      batchUpdates[projectPath] = targetCategory;
    }

    try {
      await dbRef.update(batchUpdates);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${selectedProjects.length} projects')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update projects: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          "All",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          if (selectedProjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () async {
                  await _updateProjectsCategory();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('selected_catogery');
                  Navigator.pop(context, selectedProjects.length);
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black,
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : allProjects.isEmpty
                ? Center(
                    child: Text(
                      "No projects found",
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (targetCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allProjects.length,
                          itemBuilder: (context, index) {
                            final project = allProjects[index];
                            final isSelected = selectedProjects.any((p) => p['id'] == project['id']);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedProjects.removeWhere((p) => p['id'] == project['id']);
                                  } else {
                                    selectedProjects.add(project);
                                  }
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(bottom: 20),
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.deepPurple.withOpacity(0.5)
                                      : Color(0xFF7700FF).withOpacity(0.21),
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
                                      project["title"],
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Due: ${project["dueDate"]}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    if (project["category"] != null && project["category"].isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          "Current: ${project["category"]}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
}