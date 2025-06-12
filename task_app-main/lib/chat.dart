import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CommonChatScreen extends StatefulWidget {
  @override
  _CommonChatScreenState createState() => _CommonChatScreenState();
}

class _CommonChatScreenState extends State<CommonChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ScrollController _scrollController = ScrollController();
  String _currentUserId = '';
  String _currentUserName = '';
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupChatListener();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_email')?.replaceAll('.', ',') ?? '';
      _currentUserName = prefs.getString('user_name') ?? 'User';
    });
  }

  void _setupChatListener() {
    _dbRef.child('chat').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Map<String, dynamic>> messages = [];
      
      data.forEach((timestamp, messageData) {
        messages.add({
          'text': messageData['text']?.toString() ?? '',
          'senderId': messageData['senderId']?.toString() ?? '',
          'senderName': messageData['senderName']?.toString() ?? 'Unknown',
          'time': _formatTime(timestamp.toString()),
          'timestamp': timestamp,
        });
      });

      // Sort by timestamp (oldest first)
      messages.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      setState(() {
        _messages = messages;
      });

      // Scroll to bottom when new message arrives
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      return DateFormat('hh:mm a').format(date);
    } catch (e) {
      return 'Now';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'text': _messageController.text.trim(),
      'senderId': _currentUserId,
      'senderName': _currentUserName,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    try {
      await _dbRef.child('chat').push().set(message);
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        title: Text('Team Chat'),
        backgroundColor: Color.fromRGBO(124, 70, 240, 0.15),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text(
                _currentUserName.isNotEmpty ? _currentUserName[0] : 'U',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['senderId'] == _currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey,
                                  child: Text(
                                    message['senderName'].isNotEmpty 
                                      ? message['senderName'][0] 
                                      : 'U',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  message['senderName'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) SizedBox(width: 30), // Offset for avatar
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Color(0xFF7C46F0) : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                  bottomLeft: isMe ? Radius.circular(20) : Radius.circular(0),
                                  bottomRight: isMe ? Radius.circular(0) : Radius.circular(20),
                                ),
                              ),
                              child: Text(
                                message['text'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              message['time'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}