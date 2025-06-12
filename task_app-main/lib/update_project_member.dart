import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddProjectMembers extends StatefulWidget {
  final String projectId;
  final String currentUserEmail;
  final List<String> existingMembers;

  const AddProjectMembers({
    required this.projectId,
    required this.currentUserEmail,
    required this.existingMembers,
  });

  @override
  _AddProjectMembersState createState() => _AddProjectMembersState();
}

class _AddProjectMembersState extends State<AddProjectMembers> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<String> _allMembers = [];
  List<String> _filteredMembers = [];
  Set<String> _selectedMembers = Set<String>();
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMembers.addAll(widget.existingMembers);
    _loadAvailableMembers();
  }

  Future<void> _loadAvailableMembers() async {
    try {
      final snapshot = await _db.child('members').get();
      if (snapshot.exists) {
        final membersMap = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _allMembers = membersMap.keys
              .where((key) => key != widget.currentUserEmail.replaceAll('.', ','))
              .map((key) => key.toString().replaceAll(',', '.'))
              .toList();
          _filteredMembers = _allMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading members: $e");
      setState(() => _isLoading = false);
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

  Future<void> _saveSelectedMembers() async {
    try {
      final sanitizedEmail = widget.currentUserEmail.replaceAll('.', ',');
      await _db.child('members/$sanitizedEmail/projects/${widget.projectId}/assign_to')
          .set(_selectedMembers.toList());
      Navigator.pop(context, _selectedMembers.toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update members: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        title: Text('Add Members'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSelectedMembers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
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
                        // tileColor: Colors.white,
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