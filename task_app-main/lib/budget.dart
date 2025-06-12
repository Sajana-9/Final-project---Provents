import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Budget extends StatefulWidget {
  @override
  _BudgetState createState() => _BudgetState();
}

class _BudgetState extends State<Budget> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String? _userEmail;
  Map<String, dynamic> _budgetData = {
    'totalEarnings': 0.0,
    'totalSpendings': 0.0,
    'targetBudget': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

 Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('user_email');
    });
    
    if (_userEmail != null) {
      final userPath = _userEmail!.replaceAll('.', ',');
      _db.child('members/$userPath/budget').onValue.listen((event) {
        final snapshotValue = event.snapshot.value;
        
        setState(() {
          _budgetData = {
            'totalEarnings': _parseFirebaseValue((snapshotValue as Map?)?['totalEarnings']),
            'totalSpendings': _parseFirebaseValue((snapshotValue as Map?)?['totalSpendings']),
            'targetBudget': _parseFirebaseValue((snapshotValue as Map?)?['targetBudget']),
          };
        });
      });
    }
  }

  double _parseFirebaseValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

double get _targetPercentage {
  final earnings = _getDoubleValue('totalEarnings');
  final targetBudget = _getDoubleValue('targetBudget');

  if (targetBudget <= 0) return 0.0;
  return (earnings / targetBudget) * 100;
}


  double _getDoubleValue(String key) {
    final value = _budgetData[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Text(
                  "Budget Tracking",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildBudgetCard(
              title: "Total Earnings",
              amount: "\$${_budgetData['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}",
              icon: Icons.attach_money,
              cardColor: Colors.green,
              iconColor: Colors.greenAccent,
              fieldPath: 'totalEarnings',
            ),
            SizedBox(height: 16),
            _buildBudgetCard(
              title: "Total Spendings",
              amount: "\$${_budgetData['totalSpendings']?.toStringAsFixed(2) ?? '0.00'}",
              icon: Icons.money_off,
              cardColor: Color.fromARGB(255, 246, 90, 79),
              iconColor: Color.fromARGB(255, 246, 19, 3),
              fieldPath: 'totalSpendings',
            ),
            SizedBox(height: 16),
            _buildBudgetCard(
              title: "Target Budget",
              amount: "\$${_budgetData['targetBudget']?.toStringAsFixed(2) ?? '0.00'}",
              icon: Icons.flag,
              cardColor: Color(0xFF7700FF).withOpacity(0.21),
              iconColor: Colors.purple,
              fieldPath: 'targetBudget',
            ),
            SizedBox(height: 16),
            _buildProgressCard(
              title: "Target Percentage",
              percentage: _targetPercentage,
              cardColor: Colors.white,
              progressColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color cardColor,
    required Color iconColor,
    required String fieldPath,
  }) {
    return Container(
      height: 140,
      child: Stack(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, size: 60, color: iconColor),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.edit, color: Colors.black54),
              onPressed: () => _showEditDialog(context, title, fieldPath),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required double percentage,
    required Color cardColor,
    required Color progressColor,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: progressColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            SizedBox(height: 8),
            Text(
              "${percentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, String fieldPath) {
    TextEditingController controller = TextEditingController(
      text: _budgetData[fieldPath]?.toString() ?? '0.00'
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit $title"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: "Enter new value",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                final value = double.tryParse(controller.text) ?? 0.0;
                if (_userEmail != null) {
                  _db.child('members/${_userEmail!.replaceAll('.', ',')}/budget/$fieldPath')
                      .set(value);
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}