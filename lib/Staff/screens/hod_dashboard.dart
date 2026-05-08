import 'package:bhc_erp/Staff/common/MentoringFormActivity%20.dart';
import 'package:bhc_erp/Staff/common/StaffBioAttendance.dart';
import 'package:bhc_erp/Staff/common/StudentMentoringSystem.dart';
import 'package:bhc_erp/Staff/common/TimeTable.dart';
import 'package:bhc_erp/Staff/common/class_attendance.dart';
import 'package:bhc_erp/Staff/common/profile.dart';
import 'package:bhc_erp/Staff/common/publications.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';


class HODDashboard extends StatefulWidget {
  const HODDashboard({super.key});

  @override
  State<HODDashboard> createState() => _HODDashboardState();
}

class _HODDashboardState extends State<HODDashboard> {
  String _selectedMenuItem = 'Dashboard';
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  late Future<Map<String, dynamic>> _drawerDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
    _drawerDataFuture = _fetchDrawerData();
  }

  // Helper to safely get the count of research papers from the API data structure
  int _getResearchPaperCount(Map<String, dynamic>? userData) {
    if (userData == null) return 0;

    int count = 0;
    final publications = userData['research_expertise']?['publications'] ??
        userData['publications'];

    if (publications is Map<String, dynamic>) {
      // Summing up all publication types
      count +=
          (publications['journal_articles'] as List<dynamic>?)?.length ?? 0;
      count +=
          (publications['conference_papers'] as List<dynamic>?)?.length ?? 0;
      count += (publications['book_chapters'] as List<dynamic>?)?.length ?? 0;
      count += (publications['books_authored'] as List<dynamic>?)?.length ?? 0;
      count += (publications['edited_volume'] as List<dynamic>?)?.length ?? 0;
      count += (publications['patent'] as List<dynamic>?)?.length ?? 0;
    }
    return count;
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    // Simulate API call for HOD dashboard data
    await Future.delayed(const Duration(milliseconds: 500));

    final authProvider = context.read<AuthProvider>();
    final userData = authProvider.userData;

    final researchPaperCount = _getResearchPaperCount(userData);

    return {
      'facultyMembers': 8,
      'totalCourses': 12,
      'activeProjects': 5,
      'departmentRating': 4.8,
      'researchPapers': researchPaperCount,
      'pendingApprovals': 7,
      'upcomingMeetings': 3,
      'departmentProgress': 75,
      'facultyDistribution': {
        'Professors': 3,
        'Associate Professors': 2,
        'Assistant Professors': 3,
      },
      'recentActivities': [
        {
          'title': 'Faculty meeting conducted',
          'time': '2 hours ago',
          'icon': Icons.meeting_room,
          'color': Colors.blue,
        },
        {
          'title': 'Department report submitted',
          'time': 'Yesterday',
          'icon': Icons.assessment,
          'color': Colors.green,
        },
        {
          'title': 'Research proposal approved',
          'time': '2 days ago',
          'icon': Icons.analytics,
          'color': Colors.purple,
        },
      ],
      'upcomingSchedule': [
        {
          'time': '10:00 AM',
          'subject': 'Department Meeting',
          'type': 'Meeting',
          'room': 'Conference Hall',
          'duration': '1.5 hours',
        },
        {
          'time': '02:00 PM',
          'subject': 'Faculty Review',
          'type': 'Review',
          'room': 'HOD Cabin',
          'duration': '2 hours',
        },
        {
          'time': '04:00 PM',
          'subject': 'Student Grievance',
          'type': 'Grievance',
          'room': 'Department Office',
          'duration': '1 hour',
        },
      ],
    };
  }

  Future<Map<String, dynamic>> _fetchDrawerData() async {
    final authProvider = context.read<AuthProvider>();
    final userData = authProvider.userData;
    final researchPaperCount = _getResearchPaperCount(userData);

    return {
      'facultyMembers': 8,
      'totalCourses': 12,
      'researchPapers': researchPaperCount,
      'supervisedStudents': 45,
      'yearsOfService': _calculateYearsOfService(userData?['joining_date']),
      'department': userData?['department_name'] ?? 'Department',
      'designation': userData?['designation'] ?? 'HOD',
    };
  }

  int _calculateYearsOfService(String? joiningDate) {
    if (joiningDate == null) return 0;
    try {
      DateTime joinDate;
      try {
        joinDate = DateFormat('dd-MM-yyyy').parse(joiningDate);
      } catch (_) {
        joinDate = DateTime.parse(joiningDate);
      }

      final now = DateTime.now();
      int years = now.year - joinDate.year;
      if (now.month < joinDate.month ||
          (now.month == joinDate.month && now.day < joinDate.day)) {
        years--;
      }
      return years;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userData = authProvider.userData;

    String userName = userData?['name'] ?? 'HOD';
    String userEmail = userData?['college_email'] ?? 'hod@bhc.edu.in';
    String designation = userData?['designation'] ?? 'Head of Department';
    String department = userData?['department_name'] ?? 'Department';

    return FutureBuilder<Map<String, dynamic>>(
      future: _drawerDataFuture,
      builder: (context, snapshot) {
        final yearsOfService =
            snapshot.hasData ? snapshot.data!['yearsOfService'] ?? 0 : 0;
        final supervisedStudents =
            snapshot.hasData ? snapshot.data!['supervisedStudents'] ?? 0 : 0;
        final totalCourses =
            snapshot.hasData ? snapshot.data!['totalCourses'] ?? 0 : 0;
        final researchPapers =
            snapshot.hasData ? snapshot.data!['researchPapers'] ?? 0 : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 48, 28, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[800]!, Colors.blue[700]!],
            ),
            borderRadius:
                const BorderRadius.only(topRight: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: Icon(
                          Icons.school, // Changed to school icon for HOD
                          color: Colors.blue[700],
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            userEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green[400],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              designation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          department,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "$yearsOfService Years",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    isLoading
                        ? _buildLoadingStats()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                "Faculty",
                                "$totalCourses", // Using total courses count
                                Icons.people,
                              ),
                              _buildStatItem(
                                "Students",
                                "$supervisedStudents",
                                Icons.school,
                              ),
                              _buildStatItem(
                                "Papers",
                                "$researchPapers",
                                Icons.article,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLoadingStatItem(),
        _buildLoadingStatItem(),
        _buildLoadingStatItem(),
      ],
    );
  }

  Widget _buildLoadingStatItem() {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userData = authProvider.userData;

    String userName = userData?['name'] ?? 'HOD';
    String designation = userData?['designation'] ?? 'Head of Department';
    String department = userData?['department_name'] ?? 'Department';

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        final facultyMembers =
            snapshot.hasData ? snapshot.data!['facultyMembers'] ?? 0 : 0;
        final departmentProgress = snapshot.data?['departmentProgress'] ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF0D47A1), const Color(0xFF1976D2)], // Darker blue for HOD
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${getGreeting()}, ${userName.split(' ')[0]}!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          designation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          department,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.school, // School icon for HOD
                    color: Colors.white,
                    size: 40,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricBadge(
                    icon: Icons.people,
                    label: "$facultyMembers faculty members",
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Department Progress",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "$departmentProgress%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: departmentProgress / 100,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        final facultyMembers =
            snapshot.hasData ? snapshot.data!['facultyMembers'] ?? 0 : 0;
        final totalCourses =
            snapshot.hasData ? snapshot.data!['totalCourses'] ?? 0 : 0;
        final activeProjects =
            snapshot.hasData ? snapshot.data!['activeProjects'] ?? 0 : 0;
        final departmentRating =
            snapshot.hasData ? snapshot.data!['departmentRating'] ?? 0.0 : 0.0;
        final pendingApprovals =
            snapshot.hasData ? snapshot.data!['pendingApprovals'] ?? 0 : 0;
        final researchPapers = snapshot.hasData
            ? snapshot.data!['researchPapers'] ?? 0
            : 0;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildStatCard(
              "Faculty",
              facultyMembers.toString(),
              "Department",
              Icons.people_rounded,
              Colors.blue,
            ),
            _buildStatCard(
              "Courses",
              totalCourses.toString(),
              "Offered",
              Icons.menu_book_rounded,
              Colors.green,
            ),
            _buildStatCard(
              "Projects",
              activeProjects.toString(),
              "Active",
              Icons.work_rounded,
              Colors.orange,
            ),
            _buildStatCard(
              "Rating",
              departmentRating.toString(),
              "Department",
              Icons.star_rounded,
              Colors.purple,
            ),
            _buildStatCard(
              "Pending",
              pendingApprovals.toString(),
              "Approvals",
              Icons.pending_actions_rounded,
              Colors.red,
            ),
            _buildStatCard(
              "Papers",
              researchPapers.toString(),
              "Research",
              Icons.analytics_rounded,
              Colors.brown,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyDistributionChart() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final distribution =
            snapshot.data!['facultyDistribution'] as Map<String, int>;
        final data = distribution.entries.toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Faculty Distribution",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: List.generate(data.length, (index) {
                      final colors = [
                        Colors.blue.shade400,
                        Colors.green.shade400,
                        Colors.orange.shade400,
                        Colors.purple.shade400,
                        Colors.red.shade400,
                      ];
                      final value = data[index].value;
                      final total = distribution.values.reduce((a, b) => a + b);
                      final percentage = (value / total * 100).round();

                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: value.toDouble(),
                        title: '$percentage%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(data.length, (index) {
                  final colors = [
                    Colors.blue.shade400,
                    Colors.green.shade400,
                    Colors.orange.shade400,
                    Colors.purple.shade400,
                    Colors.red.shade400,
                  ];
                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            data[index].key,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${data[index].value} faculty",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Heber ERP - HOD", // Changed from "Staff" to "HOD"
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildProfessionalDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 20),
            _buildFacultyDistributionChart(),
            const SizedBox(height: 20),
            _buildUpcomingSchedule(),
            const SizedBox(height: 20),
            _buildRecentActivities(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildDrawerHeader(context),
            Expanded(child: _buildNavigationSection()),
            _buildDrawerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildNavSection("MAIN", [
            _buildNavItem(
              icon: Icons.dashboard_rounded,
              title: "Dashboard",
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
          ]),
          _buildNavSection("PERSONAL", [
            _buildNavItem(
              icon: Icons.person_rounded,
              title: "My Profile",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StaffProfileScreen(),
                ),
              ),
            ),
            _buildNavItem(
              icon: Icons.article,
              title: 'Publications',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EnhancedPublicationsScreen()),
                );
              },
            ),
          ]),
          _buildNavSection("ACADEMICS", [
           // In your _buildNavItem for "Class Attendance", replace with:
_buildNavItem(
  icon: Icons.calendar_today_rounded,
  title: "Class Attendance",
  onTap: () {
    final authProvider = context.read<AuthProvider>();
    final staffId = authProvider.userData?['staff_id'];
    
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfessionalClassAttendanceScreen(
          staffId: staffId,
          baseApiUrl: "http://117.232.64.75/api",
          refererUrl: "http://10.240.151.162",
        ),
      ),
    );
  },
),
            _buildNavItem(
                icon: Icons.schedule_rounded,
                title: "Timetable",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StaffTimetableScreen()),
                  );
                }),
          ]),
          _buildNavSection("HOD MANAGEMENT", [
            _buildNavItem(
              icon: Icons.business_rounded,
              title: "Department Management",
              onTap: () => _showComingSoonDialog('Department Management'),
            ),
            _buildNavItem(
              icon: Icons.people_alt_rounded,
              title: "Faculty Management",
              onTap: () => _showComingSoonDialog('Faculty Management'),
            ),
            _buildNavItem(
              icon: Icons.school_rounded,
              title: "Student Management",
              onTap: () => _showComingSoonDialog('Student Management'),
            ),
          ]),
          _buildNavSection("MENTORSHIP", [
            // _buildNavItem(
            //   icon: Icons.calendar_today_rounded,
            //   title: "Mentoring Form Activities",
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const MenteeManagementScreen(),
            //       ),
            //     );
            //   },
            // ),
            // _buildNavItem(
            //     icon: Icons.calendar_today_rounded,
            //     title: "Mentee Details Report",
            //     onTap: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //             builder: (context) => const MenteeManagementScreen()),
            //       );
            //     }),
            _buildNavItem(
                icon: Icons.calendar_today_rounded,
                title: "Student Mentoring System",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UnifiedMentoringDashboard()),
                  );
                }),
          ]),
          _buildNavSection("STAFF ATTENDANCE", [
            _buildNavItem(
              icon: Icons.calendar_today_rounded,
              title: "Bio attendance",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StaffBioAttendanceScreen(),
                  ),
                );
              },
            ),
          ]),
          _buildNavSection("REPORTS & ANALYTICS", [
            _buildNavItem(
              icon: Icons.assessment_rounded,
              title: "Department Reports",
              onTap: () => _showComingSoonDialog('Department Reports'),
            ),
            _buildNavItem(
              icon: Icons.analytics_rounded,
              title: "Faculty Performance",
              onTap: () => _showComingSoonDialog('Faculty Performance'),
            ),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "$feature Coming Soon",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "This feature is currently under development and will be available in a future update.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Got It',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected ? Border.all(color: Colors.blue[100]!, width: 1) : null,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[500] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey[700],
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.blue[700] : Colors.grey[800],
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.blue,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        minLeadingWidth: 0,
        horizontalTitleGap: 8,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[100]!),
              color: Colors.red[50],
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red[600],
                  size: 20,
                ),
              ),
              title: const Text(
                "Logout",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              minLeadingWidth: 0,
              horizontalTitleGap: 8,
              onTap: _handleLogout,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Heber ERP v1.0.0",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': Icons.people_alt_rounded,
        'label': 'Faculty\nManagement',
        'color': Colors.blue,
        'onTap': () => _showComingSoonDialog('Faculty Management'),
      },
      {
        'icon': Icons.assessment_rounded,
        'label': 'Department\nReports',
        'color': Colors.green,
        'onTap': () => _showComingSoonDialog('Department Reports'),
      },
      {
        'icon': Icons.business_rounded,
        'label': 'Department\nManagement',
        'color': Colors.orange,
        'onTap': () => _showComingSoonDialog('Department Management'),
      },
      {
        'icon': Icons.analytics_rounded,
        'label': 'Faculty\nPerformance',
        'color': Colors.purple,
        'onTap': () => _showComingSoonDialog('Faculty Performance'),
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "HOD Quick Actions",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actions.map((action) {
              final color = action['color'] as Color;
              final onTap = action['onTap'] as VoidCallback;

              return GestureDetector(
                onTap: onTap,
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSchedule() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final schedule = snapshot.data!['upcomingSchedule'] as List<dynamic>;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...schedule.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['time'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['subject'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(item['type'])
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['type'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getTypeColor(item['type']),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item['room'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (item['duration'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "• ${item['duration']}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.blue;
      case 'review':
        return Colors.green;
      case 'grievance':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget _buildRecentActivities() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final activities = snapshot.data!['recentActivities'] as List<dynamic>;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Recent Activities",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: activities.map((activity) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: activity['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            activity['icon'],
                            color: activity['color'],
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activity['time'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectMenuItem(String menuItem) {
    setState(() {
      _selectedMenuItem = menuItem;
    });
    Navigator.pop(context);
  }

  void _handleLogout() {
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red.shade50!, Colors.orange.shade50!],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Are you sure you want to logout?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await authProvider.logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Logout",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}