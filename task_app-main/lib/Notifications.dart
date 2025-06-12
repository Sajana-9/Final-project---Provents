import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  final String currentUserEmail;
  
  const NotificationsPage({
    required this.currentUserEmail
  });

  @override
  Widget build(BuildContext context) {
    final sanitizedEmail = currentUserEmail.replaceAll('.', ',');
    final notificationsRef = FirebaseDatabase.instance
        .ref()
        .child('members/$sanitizedEmail/notifications');

    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, const Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFF5F33E1)),
            onPressed: () => _showClearConfirmationDialog(context, notificationsRef),
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: notificationsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Text('No notifications yet',
                style: TextStyle(color: Color(0xFF5F33E1))),
            );
          }

          final notificationsMap = Map<dynamic, dynamic>.from(
            snapshot.data!.snapshot.value as Map
          );
          final notifications = notificationsMap.entries.toList()
            ..sort((a, b) => (b.value['timestamp'] as int?)?.compareTo(
              a.value['timestamp'] as int? ?? 0) ?? 0);

          return _buildNotificationList(notifications);
        },
      ),
    );
  }

  Widget _buildNotificationList(List<MapEntry<dynamic, dynamic>> notifications) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNotificationSection(
            "Recent Activities",
            const Color.fromRGBO(119, 0, 255, 1).withOpacity(0.21),
            notifications.map((entry) => _buildNotificationItem(
              Map<String, dynamic>.from(entry.value))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final type = notification['type'];
    final isTaskCompleted = type == 'task_completed';
    final timestamp = notification['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF5F33E1).withOpacity(0.1),
              child: Icon(
                isTaskCompleted ? Icons.task_alt : Icons.group_add,
                color: const Color(0xFF5F33E1)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    notification['completedBy'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5F33E1),
                      fontSize: 16),
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTaskCompleted
                        ? 'Completed "${notification['taskName'] ?? 'Task'}"'
                        : 'Project Join Request',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  // Text(
                  //   isTaskCompleted
                  //       ? 'in "${notification['projectName'] ?? 'Project'}"'
                  //       : 'For "${notification['projectName'] ?? 'Project"'}',
                  //   style: const TextStyle(
                  //     color: Colors.grey,
                  //     fontSize: 12),
                  // ),
                  if (isTaskCompleted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, 
                          color: Colors.amber, 
                          size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '+${notification['pointsEarned'] ?? 0} Points',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: !isTaskCompleted 
                ? _buildRequestActions(notification)
                : null,
          ),
          if (isTaskCompleted) const Divider(height: 1),
          if (isTaskCompleted) Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, 
                  size: 16, 
                  color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Completed on ${DateFormat('MMM dd, yyyy - HH:mm').format(date)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestActions(Map<String, dynamic> notification) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton("Decline", Colors.red, () {
          _handleRequestResponse(notification, false);
        }),
        const SizedBox(width: 8),
        _buildActionButton("Accept", const Color(0xFF5F33E1), () {
          _handleRequestResponse(notification, true);
        }),
      ],
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }

  void _showClearConfirmationDialog(
      BuildContext context, DatabaseReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            },
            child: const Text('Clear', 
              style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleRequestResponse(
      Map<String, dynamic> notification, bool accepted) {
    // Implement your request handling logic here
    // You might want to update project members or send notifications
    final message = accepted ? 'Request accepted' : 'Request declined';
    ScaffoldMessenger.of(GlobalKey<ScaffoldMessengerState>()
        .currentState!
        .context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildNotificationSection(
      String title, Color backgroundColor, List<Widget> notifications) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A8E9E))),
          const SizedBox(height: 10),
          ...notifications,
        ],
      ),
    );
  }
}