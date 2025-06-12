import 'package:flutter/material.dart';
import 'detail.dart';
import 'projects.dart';

class EventsScreen extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, String>> events = [
    {
      "title": "Development Planning",
      "organization": "W3 Technologies",
      "date": "20",
      "day": "Mon"
    },
    {
      "title": "Marketing Strategy",
      "organization": "ABC Solutions",
      "date": "22",
      "day": "Wed"
    },
    {
      "title": "Team Meeting",
      "organization": "XYZ Corp",
      "date": "25",
      "day": "Sat"
    },
    {
      "title": "Product Launch",
      "organization": "Innovate Ltd",
      "date": "30",
      "day": "Thu"
    },
  ];

  List<Map<String, String>> selectedEvents = [];
  bool showRemoveButton = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Events",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.add_circle, color: Colors.black, size: 30),
                      onPressed: () async {
                        final selected = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProjectsPage()),
                        );

                        if (selected != null &&
                            selected is List<Map<String, String>>) {
                          setState(() {
                            for (var event in selected) {
                              if (!events.contains(event)) {
                                events.add(event);
                              }
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isSelected = selectedEvents.contains(event);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailPage(projectId: "",),
                            ),
                          );
                        },
                        onLongPress: () {
                          setState(() {
                            if (!isSelected) {
                              selectedEvents.add(event);
                              Future.delayed(Duration(seconds: 3), () {
                                if (selectedEvents.isNotEmpty) {
                                  setState(() {
                                    showRemoveButton = true;
                                  });
                                }
                              });
                            }
                          });
                        },
                        child: EventCard(
                          title: event["title"]!,
                          organization: event["organization"]!,
                          date: event["date"]!,
                          day: event["day"]!,
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (showRemoveButton && selectedEvents.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    events
                        .removeWhere((event) => selectedEvents.contains(event));
                    selectedEvents.clear();
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
                ),
                child: Text(
                  "Remove Selected (${selectedEvents.length})",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String organization;
  final String date;
  final String day;
  final bool isSelected;

  EventCard({
    required this.title,
    required this.organization,
    required this.date,
    required this.day,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.purple],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  date,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  day,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 5),
              Text(
                organization,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
