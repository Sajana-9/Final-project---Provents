import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class FeedbackDatabaseScreen extends StatefulWidget {
  final String memberId;
  final String projectId;

  const FeedbackDatabaseScreen({
    required this.memberId,
    required this.projectId,
    Key? key,
  }) : super(key: key);

  @override
  _FeedbackDatabaseScreenState createState() => _FeedbackDatabaseScreenState();
}

class _FeedbackDatabaseScreenState extends State<FeedbackDatabaseScreen> {
  String? ownerName;
  String? projectName;
  String? dueDate;
  List<Map<String, dynamic>> feedbacks = [];
  bool _isLoading = true;
  String? _errorMessage;
  late DatabaseReference _feedbackRef;

  @override
  void initState() {
    super.initState();
    _loadData();
    _feedbackRef = FirebaseDatabase.instance.ref('members/${widget.memberId}/projects/${widget.projectId}/feedbacks');
    _feedbackRef.onValue.listen((event) {
      _loadFeedbacks(event.snapshot);
    });
  }

  void _loadData() async {
    try {
      print('[DEBUG] Starting data loading...');
      print('[DEBUG] Member ID: ${widget.memberId}');
      print('[DEBUG] Project ID: ${widget.projectId}');

      // Load owner name
      final ownerSnapshot = await FirebaseDatabase.instance
          .ref('members/${widget.memberId}/name')
          .get();
      if (ownerSnapshot.exists) {
        ownerName = ownerSnapshot.value.toString();
        print('[DEBUG] Loaded owner name: $ownerName');
      } else {
        print('[WARNING] Owner name not found for member ID: ${widget.memberId}');
      }

      // Load project data
      final projectRef = FirebaseDatabase.instance
          .ref('members/${widget.memberId}/projects/${widget.projectId}');
      final projectSnapshot = await projectRef.get();
      
      if (projectSnapshot.exists) {
        final projectData = projectSnapshot.value as Map<dynamic, dynamic>;
        print('[DEBUG] Raw project data: $projectData');

        projectName = projectData['name']?.toString() ?? 'Unnamed Project';
        dueDate = projectData['due_date']?.toString() ?? 'No due date';
        print('[DEBUG] Parsed project name: $projectName');
        print('[DEBUG] Parsed due date: $dueDate');

      } else {
        print('[ERROR] Project not found at path: ${projectRef.path}');
        _errorMessage = 'Project data not found';
      }
    } catch (e, stack) {
      print('[ERROR] Data load failed: $e');
      print(stack);
      _errorMessage = 'Failed to load data: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadFeedbacks(DataSnapshot snapshot) {
    try {
      if (snapshot.exists) {
        final rawFeedbacks = snapshot.value as Map<dynamic, dynamic>? ?? {};
        print('[DEBUG] Raw feedbacks data: $rawFeedbacks');

        setState(() {
          feedbacks = _parseFeedbacks(rawFeedbacks);
        });
      } else {
        print('[WARNING] No feedback data found.');
      }
    } catch (e) {
      print('[ERROR] Failed to parse feedback data: $e');
    }
  }

  List<Map<String, dynamic>> _parseFeedbacks(Map<dynamic, dynamic> feedbacksData) {
    final List<Map<String, dynamic>> result = [];
    
    feedbacksData.forEach((key, value) {
      print('[DEBUG] Processing feedback entry $key: $value');
      if (value is Map) {
        result.add({
          'rating': value['rating']?.toString() ?? 'N/A',
          'comment': value['comment']?.toString() ?? 'No comment',
          'timestamp': value['timestamp']?.toString() ?? 'Unknown date',
        });
      }
    });

    // Sort by timestamp descending
    result.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return result;
  }

  void _copyFeedbackLink() {
    try {
      final link = 'https://spectacular-madeleine-edcd27.netlify.app/feedback/'
          '${Uri.encodeComponent(widget.memberId)}/'
          '${Uri.encodeComponent(widget.projectId)}';
      
      print('[DEBUG] Generated link: $link');
      Clipboard.setData(ClipboardData(text: link));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard!')),
      );
    } catch (e) {
      print('[ERROR] Failed to copy link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to copy link')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _feedbackRef.onValue.drain();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Feedback Summary"),
        backgroundColor: Colors.deepPurple,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Owner: ${ownerName ?? 'Unknown'}"), 
          Text("Project Name: ${projectName ?? 'Unnamed Project'}"),
          Text("Due Date: ${dueDate ?? 'No due date'}"),
          const SizedBox(height: 20),
          if (feedbacks.isEmpty)
            const Center(child: Text('No feedback available'))
          else
            _buildFeedbackTable(),
          const SizedBox(height: 20),
          _buildCopyButton(),
        ],
      ),
    );
  }

  Widget _buildFeedbackTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Colors.deepPurple),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Rating", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                )
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Comment",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                )
              ),
            ),
          ],
        ),
        ...feedbacks.map((feedback) => TableRow(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.grey),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(feedback['rating']),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(feedback['comment']),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildCopyButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.link),
        label: const Text('Copy Feedback Link'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        onPressed: _copyFeedbackLink,
      ),
    );
  }
}
