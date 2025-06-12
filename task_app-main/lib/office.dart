import 'package:flutter/material.dart';
import 'detail.dart';
import 'projects.dart';

class OfficeProjectsScreen extends StatefulWidget {
  @override
  _OfficeProjectsScreenState createState() => _OfficeProjectsScreenState();
}

class _OfficeProjectsScreenState extends State<OfficeProjectsScreen> {
  List<Map<String, String>> projects = [
    {
      "title": "Green sky Website Dev",
      "dueDate": "Thursday, 20 July 2023",
    },
    {
      "title": "Grocery app design",
      "dueDate": "Thursday, 10 July 2023",
    },
  ];

  List<Map<String, String>> selectedProjects = [];

  bool showRemoveButton = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "Office projects",
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
              final selectedProjects = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProjectsPage()),
              );

              print("Returned Selected Projects: $selectedProjects");

              if (selectedProjects != null &&
                  selectedProjects is List<Map<String, String>>) {
                setState(() {
                  for (var project in selectedProjects) {
                    if (!projects.contains(project)) {
                      projects.add(project);
                    }
                  }
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Expanded(
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
                                builder: (context) => DetailPage(projectId: "",)),
                          );
                        },
                        onLongPress: () {
                          setState(() {
                            if (!isSelected) {
                              selectedProjects.add(project);

                              Future.delayed(Duration(seconds: 3), () {
                                if (selectedProjects.isNotEmpty) {
                                  setState(() {
                                    showRemoveButton = true;
                                  });
                                }
                              });
                            }
                          });
                        },
                        child: ProjectCard(
                          title: project["title"]!,
                          dueDate: project["dueDate"]!,
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (showRemoveButton && selectedProjects.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    projects.removeWhere(
                        (project) => selectedProjects.contains(project));
                    selectedProjects.clear();
                    showRemoveButton = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  "Remove Selected (${selectedProjects.length})",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String dueDate;
  final bool isSelected;

  ProjectCard({
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
