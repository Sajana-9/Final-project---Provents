import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MembersPage extends StatefulWidget {
  final String currentUserEmail;
  final List<String> initialSelection;

  const MembersPage({
    required this.currentUserEmail,
    this.initialSelection = const [],
  });

  @override
  _MembersPageState createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<String> _allMembers = [];
  List<String> _filteredMembers = [];
  Set<String> _selectedMembers = Set<String>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMembers.addAll(widget.initialSelection);
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final snapshot = await _db.child('members').get();
    if (snapshot.exists) {
      final membersMap = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _allMembers = membersMap.keys
            .where((key) => key != widget.currentUserEmail.replaceAll('.', ','))
            .map((key) => key.toString().replaceAll(',', '.'))
            .toList();
        _filteredMembers = _allMembers;
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredMembers = _allMembers
          .where((email) => email.toLowerCase().contains(_searchQuery))
          .toList();
    });
  }

  Color _getAvatarColor(String email) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    return colors[email.hashCode % colors.length];
  }

  String _getInitials(String email) {
    final parts = email.split('@').first.split('.');
    return parts.length > 1 
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : email.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        title: Text('Select Members'),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: const Color.fromARGB(255, 0, 0, 0)),
            onPressed: () => Navigator.pop(context, _selectedMembers.toList()),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
              ),
              onChanged: _filterMembers,
            ),
          ),
          if (_selectedMembers.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "${_selectedMembers.length} selected",
                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedMembers.clear()),
                    child: Text("Clear", style: TextStyle(color: Colors.deepPurple)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final email = _filteredMembers[index];
                return CheckboxListTile(
                  value: _selectedMembers.contains(email),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedMembers.add(email);
                      } else {
                        _selectedMembers.remove(email);
                      }
                    });
                  },
                  secondary: CircleAvatar(
                    backgroundColor: _getAvatarColor(email),
                    child: Text(
                      _getInitials(email),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(email),
                  // tileColor: const Color.fromARGB(255, 58, 55, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}