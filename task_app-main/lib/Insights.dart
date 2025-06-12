import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:multicast_dns/multicast_dns.dart';
import 'dnsDiscovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';






class InsightsPage extends StatefulWidget {
  @override
  _InsightsPageState createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {

Future<List<LeaderboardEntry>> fetchLeaderboard() async {
  // Get IP from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final String? serverIp = prefs.getString('ip');
  print('Server IP: $serverIp');
  
  if (serverIp == null) {
    throw Exception('No server IP found in SharedPreferences');
  }

  // Make API call using the stored IP
  final response = await http.get(
    Uri.parse('http://$serverIp:5000/leaderboard'),
    headers: {"Content-Type": "application/json"},
  );
  
  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    return data.map((item) => LeaderboardEntry.fromJson(item)).toList();
  } else {
    throw Exception('Failed to load leaderboard: ${response.statusCode}');
  }
}

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<DateTime, int> _heatmapData = {};
  bool _isLoading = true;
  String? _errorMessage;
  // Update state variables
Map<String, int> _monthlyTasks = {};
List<BarChartGroupData> _barGroups = [];
double _maxTasks = 0;
List<String> _monthLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchMonthlyCompletedTasks();
    
  }


// Helper widget for legend dots
Widget _buildLegendDot(Color color, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}
  


  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(Colors.white, Color(0xFF7C46F0), 0.15)!,
      appBar: AppBar(
        title: const Text("Insights", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivityGrid(), 
            const SizedBox(height: 20),
            Expanded(
              child: _buildLeaderboardSection(),
            ),
          ],
        ),
      ),
    );
  }




// Add these state variables at the top of your _InsightsPageState class
Map<String, int> _monthlyCompletedTasks = {};
bool _isLoadingChart = true;

// Add this to your initState()




// Fetch data method
Future<void> _fetchMonthlyCompletedTasks() async {
  setState(() => _isLoadingChart = true);
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    if (userEmail == null) return;

    final sanitizedEmail = userEmail.replaceAll('.', ',');
    final snapshot = await _dbRef.child('members/$sanitizedEmail/projects').get();

    // Initialize all 12 months with zero counts
    final currentYear = DateTime.now().year;
    final Map<String, int> monthlyCounts = {};
    
    for (int month = 1; month <= 12; month++) {
      final key = '$currentYear-${month.toString().padLeft(2, '0')}';
      monthlyCounts[key] = 0;
    }

    if (snapshot.exists) {
      final projects = snapshot.value as Map<dynamic, dynamic>;
      
      projects.forEach((projectId, projectData) {
        final tasks = (projectData as Map)['tasks'] as Map<dynamic, dynamic>?;
        
        tasks?.forEach((taskId, taskData) {
          if (taskData['status'] == true && taskData['completed_date'] != null) {
            try {
              final completedDate = DateTime.parse(taskData['completed_date'].toString());
              // Only count if it's current year
              if (completedDate.year == currentYear) {
                final monthKey = DateFormat('yyyy-MM').format(completedDate);
                if (monthlyCounts.containsKey(monthKey)) {
                  monthlyCounts[monthKey] = monthlyCounts[monthKey]! + 1;
                }
              }
            } catch (e) {
              print('Error parsing date: $e');
            }
          }
        });
      });
    }

    // Prepare chart data in January-December order
    _monthlyCompletedTasks = monthlyCounts;
    
    _barGroups = List.generate(12, (index) {
      final month = index + 1;
      final monthKey = '$currentYear-${month.toString().padLeft(2, '0')}';
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _monthlyCompletedTasks[monthKey]!.toDouble(),
            color: Color(0xFF7C46F0),
            width: 16,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          )
        ],
      );
    });

    _maxTasks = _monthlyCompletedTasks.values.reduce(max).toDouble();
    setState(() => _isLoadingChart = false);

  } catch (e) {
    print('Error loading monthly tasks: $e');
    setState(() => _isLoadingChart = false);
  }
}

// Chart widget
Widget _buildMonthlyChart() {
  if (_isLoadingChart) {
    return Container(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  return Container(
    height: 200,
    padding: EdgeInsets.only(top: 16, bottom: 8),
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: _maxTasks * 1.1,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            // tooltipBgColor: Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final monthIndex = group.x;
              final monthName = DateFormat('MMMM').format(DateTime(2023, monthIndex + 1));
              return BarTooltipItem(
                '$monthName\n',
                TextStyle(color: Colors.white),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final monthIndex = value.toInt();
                if (monthIndex < 0 || monthIndex > 11) return SizedBox();
                final monthName = DateFormat('MMM').format(DateTime(2023, monthIndex + 1));
                return Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    monthName,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > _maxTasks) return SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 28,
              interval: max(1, _maxTasks / 3),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: max(1, _maxTasks / 3),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _barGroups,
      ),
    ),
  );
}
// Updated activity grid with your color theme
Widget _buildActivityGrid() {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Color(0xFF5500FF).withOpacity(0.34),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Monthly Activity",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Tasks completed over last 12 months",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 16),
        _buildMonthlyChart(),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(0xFF7C46F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 4),
            Text(
              "Completed Tasks",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}











  
  Widget _buildColorLegend() {
    return Row(
      children: [
        _legendItem(Colors.grey[300]!, "Low"),
        _legendItem(const Color(0xFF9473F1), "Med"),
        _legendItem(const Color(0xFF7C46F0), "High"),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: fetchLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No leaderboard data available'));
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Team Leaderboard",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildScoreLegend(),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  itemBuilder: (context, index) {
                    return _buildLeaderboardItem(snapshot.data![index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreLegend() {
    return Row(
      children: [
        _scoreLegendItem("SCORE", isHeader: true),
        _scoreLegendItem("TASKS"),
        
      ],
    );
  }

  Widget _scoreLegendItem(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rankColor(entry.rank),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complexity: L3 (${entry.complexity3}) • L4 (${entry.complexity4})',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          _buildMetricColumn("${entry.scorePercentage}%", 
              Color(0xFF7C46F0)),
          _buildMetricColumn("${entry.totalTasks}", Colors.grey[600]!),
        
               
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF7C46F0);
  }
}

class LeaderboardEntry {
  final String name;
  final String email;
  final int rank;
  final double score;
  final int totalTasks;
  final double onTimeRate;
  final int complexity3;
  final int complexity4;

  LeaderboardEntry({
    required this.name,
    required this.email,
    required this.rank,
    required this.score,
    required this.totalTasks,
    required this.onTimeRate,
    required this.complexity3,
    required this.complexity4,
  });

  double get scorePercentage => (score * 100).clamp(0, 100);

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      rank: json['rank'] ?? 0,
      score: (json['score'] as num).toDouble(),
      totalTasks: json['total_tasks'] ?? 0,
      onTimeRate: (json['on_time_rate'] as num).toDouble(),
      complexity3: json['complexity_3'] ?? 0,
      complexity4: json['complexity_4'] ?? 0,
    );
  }
}