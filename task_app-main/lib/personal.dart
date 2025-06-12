import 'package:flutter/material.dart';
import 'projects.dart';
import 'detail.dart';

class Personalprojectscreen extends StatefulWidget {
  @override
  _PersonalprojectscreenState createState() => _PersonalprojectscreenState();
}

class _PersonalprojectscreenState extends State<Personalprojectscreen> {
  List<Map<String, String>> projects = [
    {
      "title": "Uber eats redesign",
      "dueDate": "Thursday, 20 July 2023",
    },
    {
      "title": "nov project",
      "dueDate": "Thursday, 10 July 2023",
    },
  ];

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
          "Personal Projects",
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
                      return ProjectCard(
                        title: projects[index]["title"]!,
                        dueDate: projects[index]["dueDate"]!,
                      );
                    },
                  ),
                ),
              ],
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

  ProjectCard({
    required this.title,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailPage(projectId: "",)),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.4),
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
      ),
    );
  }
}
