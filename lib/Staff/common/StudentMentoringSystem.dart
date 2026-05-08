import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';

class MentoringSessionsPage extends StatefulWidget {
  const MentoringSessionsPage({super.key});

  @override
  State<MentoringSessionsPage> createState() => _MentoringSessionsPageState();
}

class _MentoringSessionsPageState extends State<MentoringSessionsPage>
    with TickerProviderStateMixin {
  List<dynamic> _allSessions = [];
  List<dynamic> _filteredSessions = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNetworkError = false;
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedStudent;
  DateTime? _selectedDate;
  List<String> _availableStatuses = [
    'All',
    'completed',
    'scheduled',
    'cancelled'
  ];
  List<String> _availableStudents = [];
  final ScrollController _scrollController = ScrollController();
  bool _showFilters = true;
  int _totalSessions = 0;
  double _loadingProgress = 0.0;
  bool _showProgressBar = true;

  // Animation controllers
  late AnimationController _scrollAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  double _lastScrollOffset = 0;

  // Color Scheme
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _secondaryColor = const Color(0xFF0D47A1);
  final Color _backgroundColor = Colors.grey.shade50;
  final Color _cardColor = Colors.white;
  final Color _textPrimary = Colors.grey.shade800;
  final Color _textSecondary = Colors.grey.shade600;
  final Color _borderColor = Colors.grey.shade200;

  // Mentor Info
  Map<String, dynamic>? _currentMentor;
  Map<String, dynamic>? _mentorStats;
  String? _currentStaffId;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _scrollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _scrollAnimationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _scrollAnimationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchSessionsData();
    _scrollController.addListener(_scrollListener);

    // Start progress animation
    _progressAnimationController.repeat(reverse: true);

    // Pre-warm the animation controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollAnimationController.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _scrollAnimationController.dispose();
    _progressAnimationController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      final scrollDelta = offset - _lastScrollOffset;
      _lastScrollOffset = offset;

      // Animate based on scroll position
      final showFiltersOnly = offset > 100;

      // Smooth animation for showing/hiding content
      if (showFiltersOnly != !_showFilters) {
        setState(() {
          _showFilters = !showFiltersOnly;
        });

        // Animate the transition
        if (showFiltersOnly) {
          _scrollAnimationController.forward();
        } else {
          _scrollAnimationController.reverse();
        }
      }
    }
  }

  Future<void> _fetchSessionsData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _hasNetworkError = false;
        _loadingProgress = 0.0;
        _showProgressBar = true;
      });

      // Simulate progress updates
      _updateProgress(0.1);

      final authProvider = context.read<AuthProvider>();
      final departmentCode = authProvider.userData?['department_code'];
      final userData = authProvider.userData;
      final staffId = userData?['staff_id'];

      _updateProgress(0.3);

      // Store current staff ID for filtering
      _currentStaffId = staffId;

      // Set current mentor from user data
      if (userData != null) {
        setState(() {
          _currentMentor = {
            'staff_id': staffId ?? '',
            'staff_name': userData['name'] ?? 'Mentor',
            'designation': userData['designation'] ?? 'Faculty',
            'staff_email': userData['college_email'] ?? '',
            'department': userData['department_name'] ?? '',
          };
        });
      }

      _updateProgress(0.5);

      if (departmentCode == null) {
        throw Exception('Department information not available');
      }

      final response = await http.get(
        Uri.parse(
            'http://117.232.64.75/api/staff/mentorship/get_department_session/$departmentCode'),
        headers: {
          'Referer': 'http://10.240.151.162',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      _updateProgress(0.7);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        _updateProgress(0.8);

        if (data['success'] == true) {
          final allSessions = data['data'] as List<dynamic>;
          final totalSessions = data['total_sessions'] as int;

          // FILTER: Only get sessions for the current mentor
          final List<dynamic> mentorSessions = allSessions.where((session) {
            return session['mentor_id'] == staffId;
          }).toList();

          // Extract unique students from mentor's sessions only
          final Set<String> students = {};
          int completedCount = 0;
          int scheduledCount = 0;
          int cancelledCount = 0;

          for (var session in mentorSessions) {
            if (session['student_name'] != null) {
              students
                  .add('${session['student_name']} (${session['student_id']})');
            }

            // Count by status
            final status = session['status'] ?? '';
            if (status == 'completed') completedCount++;
            if (status == 'scheduled') scheduledCount++;
            if (status == 'cancelled') cancelledCount++;
          }

          // Calculate mentor stats
          final uniqueStudents = students.length;

          _updateProgress(0.9);

          // Small delay for smooth transition
          await Future.delayed(const Duration(milliseconds: 300));

          setState(() {
            _allSessions = mentorSessions; // Only mentor's sessions
            _filteredSessions = mentorSessions;
            _totalSessions =
                mentorSessions.length; // Use mentor's session count, not total
            _availableStudents = ['All', ...students.toList()..sort()];
            _loadingProgress = 1.0;
            _isLoading = false;

            // Set mentor stats
            _mentorStats = {
              'total_sessions': mentorSessions.length,
              'completed_sessions': completedCount,
              'scheduled_sessions': scheduledCount,
              'cancelled_sessions': cancelledCount,
              'unique_students': uniqueStudents,
            };
          });

          // Hide progress bar after completion
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _showProgressBar = false;
              });
            }
          });
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load sessions: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _hasNetworkError = true;
        _isLoading = false;
        _showProgressBar = false;
      });
    }
  }

  void _updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _loadingProgress = progress;
      });
    }
  }

  Future<void> _refreshData() async {
    await _fetchSessionsData();
  }

  void _applyFilters() {
    List<dynamic> filtered = _allSessions;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((session) {
        return session['student_name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            session['student_id'].toString().contains(_searchQuery);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != null && _selectedStatus != 'All') {
      filtered = filtered
          .where((session) => session['status'] == _selectedStatus)
          .toList();
    }

    // Student filter
    if (_selectedStudent != null && _selectedStudent != 'All') {
      final studentId = _selectedStudent!.split('(').last.replaceAll(')', '');
      filtered = filtered
          .where((session) => session['student_id'].toString() == studentId)
          .toList();
    }

    // Date filter
    if (_selectedDate != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      filtered = filtered.where((session) {
        final sessionDate = DateTime.parse(session['session_date']).toLocal();
        final sessionDateStr = DateFormat('yyyy-MM-dd').format(sessionDate);
        return sessionDateStr == selectedDateStr;
      }).toList();
    }

    setState(() {
      _filteredSessions = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = null;
      _selectedStudent = null;
      _selectedDate = null;
      _filteredSessions = _allSessions;
    });
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryColor,
      elevation: 0,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Mentoring Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (_isLoading && _showProgressBar)
                SizedBox(
                  height: 2,
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: _isLoading ? null : _refreshData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              // Compact Filters (shows when scrolling down)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showFilters ? 0 : null,
                curve: Curves.fastOutSlowIn,
                child: _showFilters
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildCompactFilters(),
                      ),
              ),

              // Main Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Mentor Info Card (like dashboard)
                      if (_currentMentor != null && _showFilters)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showFilters ? 1.0 : 0.0,
                          child: Container(
                            child: _buildMentorInfoCard(),
                          ),
                        ),

                      // Stats Overview
                      if (_showFilters)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showFilters ? 1.0 : 0.0,
                          child: _buildStatsOverview(),
                        ),

                      // Full Filters Card (shows only initially)
                      if (_showFilters)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showFilters ? 1.0 : 0.0,
                          child: Container(
                            child: _buildFiltersCard(),
                          ),
                        ),

                      // Sessions List
                      _buildAnimatedSessionsList(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ============ ENHANCED LOADING OVERLAY ============
          if (_isLoading && _showProgressBar) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ==================== LOADING OVERLAY ====================
  Widget _buildLoadingOverlay() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon
              AnimatedBuilder(
                animation: _progressAnimationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _progressAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor,
                            _secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.meeting_room,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Loading Text
              Text(
                'Loading Sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Fetching your mentoring sessions...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Progress Bar Container
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    // Animated Background
                    AnimatedBuilder(
                      animation: _progressAnimationController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade200,
                                Colors.blue.shade400,
                              ],
                              stops: [0.2, 1.0],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              transform: GradientRotation(
                                _progressAnimation.value * 6.28319,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),

                    // Progress Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: 280 * _loadingProgress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor,
                            _secondaryColor,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Progress Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${(_loadingProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Loading Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _loadingProgress > 0.3 + (index * 0.2)
                          ? _primaryColor
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== MENTOR INFO CARD ====================
  Widget _buildMentorInfoCard() {
    final mentorName = _currentMentor?['staff_name'] ?? 'Mentor';
    final designation = _currentMentor?['designation'] ?? 'Faculty';
    final department = _currentMentor?['department'] ?? '';
    final email = _currentMentor?['staff_email'] ?? '';
    final totalSessions = _mentorStats?['total_sessions'] ?? 0;
    final completedSessions = _mentorStats?['completed_sessions'] ?? 0;
    final uniqueStudents = _mentorStats?['unique_students'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (designation.isNotEmpty)
                      Text(
                        designation,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (department.isNotEmpty)
                      Text(
                        department,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMentorStatItem(
                  value: '$totalSessions',
                  label: 'Total Sessions',
                  icon: Icons.meeting_room,
                ),
                _buildMentorStatItem(
                  value: '$completedSessions',
                  label: 'Completed',
                  icon: Icons.check_circle,
                ),
                _buildMentorStatItem(
                  value: '$uniqueStudents',
                  label: 'Students',
                  icon: Icons.group,
                ),
              ],
            ),
          ),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.email,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMentorStatItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATS OVERVIEW ====================
  Widget _buildStatsOverview() {
    final completedSessions = _mentorStats?['completed_sessions'] ?? 0;
    final scheduledSessions = _mentorStats?['scheduled_sessions'] ?? 0;
    final uniqueStudents = _mentorStats?['unique_students'] ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // First Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'My Sessions',
                  value: _totalSessions.toString(),
                  icon: Icons.meeting_room,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'My Students',
                  value: uniqueStudents.toString(),
                  icon: Icons.group,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Completed',
                  value: completedSessions.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'Scheduled',
                  value: scheduledSessions.toString(),
                  icon: Icons.schedule,
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FILTERS CARD ====================
  Widget _buildFiltersCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search my sessions by student name or ID...',
                hintStyle: TextStyle(color: _textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: _textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Filter Options
          Column(
            children: [
              // Status Filter
              _buildFilterDropdown(
                label: 'Session Status',
                value: _selectedStatus,
                items: _availableStatuses,
                icon: Icons.flag,
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  _applyFilters();
                },
              ),

              const SizedBox(height: 12),

              // Student Filter
              _buildFilterDropdown(
                label: 'Filter by Student',
                value: _selectedStudent,
                items: _availableStudents,
                icon: Icons.school,
                onChanged: (value) {
                  setState(() => _selectedStudent = value);
                  _applyFilters();
                },
              ),

              const SizedBox(height: 12),

              // Date Filter
              _buildDateFilter(),

              const SizedBox(height: 16),

              // Clear Filters Button
              if (_selectedStatus != null ||
                  _selectedStudent != null ||
                  _selectedDate != null ||
                  _searchQuery.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _clearFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _backgroundColor,
                      foregroundColor: _textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: _borderColor),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.clear_all, size: 16),
                        SizedBox(width: 8),
                        Text('Clear All Filters'),
                      ],
                    ),
                  ),
                ),

              // Results Counter
              if (_allSessions.isNotEmpty && !_isLoading)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(top: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Sessions: ${_allSessions.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Showing: ${_filteredSessions.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down,
                        color: _textSecondary, size: 22),
                    hint: Text(
                      'All',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      ...items.where((item) => item != 'All').map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Date',
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: _textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _selectedDate != null ? _textPrimary : _textSecondary,
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() => _selectedDate = null);
                      _applyFilters();
                    },
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }

  // ==================== COMPACT FILTERS ====================
  Widget _buildCompactFilters() {
    return Column(
      children: [
        // Search Bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search my sessions...',
              hintStyle: TextStyle(color: _textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.search, color: _textSecondary, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Quick Status Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'completed', 'scheduled'].map((status) {
              final isSelected = _selectedStatus == status ||
                  (status == 'All' && _selectedStatus == null);

              return Container(
                margin: const EdgeInsets.only(right: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  child: ChoiceChip(
                    label: Text(
                      status == 'All' ? 'All' : status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : _textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (status == 'All') {
                          _selectedStatus = null;
                        } else {
                          _selectedStatus = selected ? status : null;
                        }
                      });
                      _applyFilters();
                    },
                    backgroundColor:
                        isSelected ? _getStatusColor(status) : Colors.white,
                    selectedColor: _getStatusColor(status),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color:
                            isSelected ? _getStatusColor(status) : _borderColor,
                        width: 1,
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade600;
      case 'scheduled':
        return Colors.orange.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return _primaryColor;
    }
  }

  // ==================== ANIMATED SESSIONS LIST ====================
  Widget _buildAnimatedSessionsList() {
    if (_isLoading && !_showProgressBar) {
      return _buildShimmerList();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_allSessions.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredSessions.isEmpty) {
      return _buildEmptyResultsState();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List Header with fade animation
          AnimatedOpacity(
            opacity: _showFilters ? 0.7 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Mentoring Sessions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    '${_filteredSessions.length} sessions',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated Session Cards with staggered entry
          ..._filteredSessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 50)),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(
                bottom: 12,
                top: index == 0 ? 0 : 4,
              ),
              transform: Matrix4.translationValues(
                  0,
                  _showFilters
                      ? 0
                      : 10 * (1 - _scrollAnimationController.value),
                  0),
              child: Opacity(
                opacity: 0.9 + (0.1 * _scrollAnimationController.value),
                child: _buildSessionCard(session),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(6, (index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 4),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.white,
              period: const Duration(milliseconds: 1500),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

 Widget _buildSessionCard(Map<String, dynamic> session) {
  final sessionDate = DateTime.parse(session['session_date']).toLocal();
  final nextSessionDate = session['next_session_date'] != null
      ? DateTime.parse(session['next_session_date']).toLocal()
      : null;
  final status = session['status'] ?? 'scheduled';
  final studentName = session['student_name'] ?? 'Unknown Student';
  final studentId = session['student_id']?.toString() ?? '';
  final details = session['details_matters'] is List &&
          (session['details_matters'] as List).isNotEmpty
      ? (session['details_matters'] as List).first
      : null;

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                0.05 + (0.05 * _scrollAnimationController.value)),
            blurRadius: 6 + (2 * _scrollAnimationController.value),
            offset: Offset(0, 2 + (1 * _scrollAnimationController.value)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Add a slight delay for tap animation
            Future.delayed(const Duration(milliseconds: 100), () {
              _showStudentProfile(context, studentId, session);
            });
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: _primaryColor.withOpacity(0.1),
          highlightColor: _primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: 0.9 + (0.1 * _scrollAnimationController.value),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: $studentId',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Session Details
                Row(
                  children: [
                    _buildSessionDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Session Date',
                      value: DateFormat('dd MMM yyyy').format(sessionDate),
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildSessionDetailItem(
                      icon: Icons.next_plan,
                      label: 'Next Session',
                      value: nextSessionDate != null
                          ? DateFormat('dd MMM yyyy').format(nextSessionDate)
                          : 'Not scheduled',
                      color: _secondaryColor,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Session Summary
                if (details != null && details['attendance'] != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance: ${details['attendance']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (session['mentor_feedback'] != null &&
                            session['mentor_feedback'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Feedback: ${session['mentor_feedback']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Footer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created: ${DateFormat('dd MMM yyyy').format(DateTime.parse(session['createdAt']).toLocal())}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: _primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person,
                              size: 14, color: _primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}



  Widget _buildSessionDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== ERROR & EMPTY STATES ====================
  Widget _buildEmptyResultsState() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Sessions Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'No sessions match your filters',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _clearFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.shade100, width: 2),
            ),
            child: Icon(
              _hasNetworkError
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 40,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _hasNetworkError ? 'Connection Error' : 'Something Went Wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              color: _primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Sessions Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'You haven\'t conducted any mentoring sessions yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // ==================== SESSION DETAILS DIALOG ====================
  void _showSessionDetails(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          SessionDetailsSheet(session: session, primaryColor: _primaryColor),
    );
  }
  
void _showStudentProfile(BuildContext context, String studentId,
    Map<String, dynamic> sessionData) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          StudentProfileScreen(
        studentId: studentId,
        initialData: {
          'student_id': studentId,
          'student_name': sessionData['student_name'],
          'program_type': sessionData['program_type'] ?? 'UG',
          'batch': sessionData['batch'] ?? '',
          'stream': sessionData['stream'] ?? '',
          'active_status': true,
        },
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}
}

// ==================== STUDENT MENTORING PROFILE SCREEN ====================
// Shows mentoring-related information (Sessions, Feedback, etc.)

// ==================== STUDENT MENTORING PROFILE SCREEN ====================
// Shows mentoring-focused information with session details embedded

// ==================== STUDENT MENTORING PROFILE SCREEN ====================
// Redesigned to look like Mentoring Form/Activity interface

class StudentProfileScreen extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> initialData;

  const StudentProfileScreen({
    super.key,
    required this.studentId,
    required this.initialData,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _studentDataFuture;
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  String? _photoUrl;
  List<dynamic> _mentoringSessions = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Color Scheme
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _secondaryColor = const Color(0xFF0D47A1);
  final Color _accentPurple = const Color(0xFF7209B7);
  final Color _successBlue = const Color(0xFF4CC9F0);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212529);
  final Color _textSecondary = const Color(0xFF6C757D);
  final Color _borderColor = const Color(0xFFE9ECEF);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _studentDataFuture = _fetchStudentData();
    _loadPhoto();
    _fetchMentoringSessions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final url = 'http://117.232.64.75/photos/uploads/${widget.studentId}';
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _photoUrl = url;
        });
      }
    } catch (e) {
      // Ignore photo loading errors
    }
  }

  Future<void> _fetchMentoringSessions() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final departmentCode = authProvider.userData?['department_code'];
      final staffId = authProvider.userData?['staff_id'];

      if (departmentCode == null || staffId == null) return;

      final response = await http.get(
        Uri.parse(
            'http://117.232.64.75/api/staff/mentorship/get_department_session/$departmentCode'),
        headers: {
          'Referer': 'http://10.240.151.162',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final allSessions = data['data'] as List<dynamic>;

          final studentSessions = allSessions.where((session) {
            return session['student_id'].toString() == widget.studentId &&
                session['mentor_id'] == staffId;
          }).toList();

          studentSessions.sort((a, b) {
            final dateA = DateTime.parse(a['session_date']);
            final dateB = DateTime.parse(b['session_date']);
            return dateB.compareTo(dateA);
          });

          setState(() {
            _mentoringSessions = studentSessions;
          });
        }
      }
    } catch (e) {
      // Ignore errors for sessions
    }
  }

  Future<Map<String, dynamic>> _fetchStudentData() async {
    try {
      final response = await http.get(
        Uri.parse('http://117.232.64.75/api/students/${widget.studentId}'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return widget.initialData;
    } catch (e) {
      return widget.initialData;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMentoringStatsInHeader() {
    final totalSessions = _mentoringSessions.length;
    final completedSessions = _mentoringSessions
        .where((session) => session['status'] == 'completed')
        .length;
    final scheduledSessions = _mentoringSessions
        .where((session) => session['status'] == 'scheduled')
        .length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItemHeader(
            value: totalSessions.toString(),
            label: 'Total\nSessions',
            color: _primaryColor,
          ),
          _buildStatItemHeader(
            value: completedSessions.toString(),
            label: 'Completed',
            color: Colors.green.shade600,
          ),
          _buildStatItemHeader(
            value: scheduledSessions.toString(),
            label: 'Scheduled',
            color: Colors.orange.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemHeader({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _textPrimary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, int index) {
    final sessionDate = DateTime.parse(session['session_date']).toLocal();
    final status = session['status'] ?? 'scheduled';
    final details = session['details_matters'] is List &&
            (session['details_matters'] as List).isNotEmpty
        ? (session['details_matters'] as List).first
        : {};

    Color getStatusColor(String status) {
      switch (status) {
        case 'completed':
          return Colors.green.shade600;
        case 'scheduled':
          return Colors.orange.shade600;
        case 'cancelled':
          return Colors.red.shade600;
        default:
          return _primaryColor;
      }
    }

    IconData getStatusIcon(String status) {
      switch (status) {
        case 'completed':
          return Icons.check_circle;
        case 'scheduled':
          return Icons.schedule;
        case 'cancelled':
          return Icons.cancel;
        default:
          return Icons.meeting_room;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildInfoCard(
        title: 'Session ${index + 1}',
        icon: getStatusIcon(status),
        iconColor: getStatusColor(status),
        children: [
          // Status and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(sessionDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: getStatusColor(status).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Session Details
          if (details.isNotEmpty) ...[
            Text(
              'Session Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildSessionDetails(details),
          ],

          // Mentor Feedback
          if (session['mentor_feedback'] != null &&
              session['mentor_feedback'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Mentor Feedback',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                session['mentor_feedback'].toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                ),
              ),
            ),
          ],

          // Positive Traits
          if (session['positive_traits'] != null &&
              session['positive_traits'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              label: 'Positive Traits',
              value: session['positive_traits'].toString(),
            ),
          ],

          // Corrective Measures
          if (session['corrective_measures'] != null &&
              session['corrective_measures'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              label: 'Areas for Improvement',
              value: session['corrective_measures'].toString(),
            ),
          ],

          // Next Session
          if (session['next_session_date'] != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow(
              label: 'Next Session',
              value: DateFormat('dd MMM yyyy').format(
                DateTime.parse(session['next_session_date']).toLocal(),
              ),
            ),
          ],

          // Date Information
          const SizedBox(height: 16),
          Divider(color: _borderColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${DateFormat('dd MMM yyyy').format(
                  DateTime.parse(session['createdAt']).toLocal(),
                )}',
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
              Text(
                'Updated: ${DateFormat('dd MMM yyyy').format(
                  DateTime.parse(session['updatedAt']).toLocal(),
                )}',
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
        index: 2 + index,
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: _textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionDetails(Map<String, dynamic> details) {
    final List<Widget> widgets = [];

    if (details['attendance'] != null &&
        details['attendance'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Attendance',
        value: details['attendance'].toString(),
      ));
    }

    if (details['academicPerformance'] != null &&
        details['academicPerformance'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Academic Performance',
        value: details['academicPerformance'].toString(),
      ));
    }

    if (details['arrears'] != null && details['arrears'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Arrears',
        value: details['arrears'].toString(),
      ));
    }

    if (details['personalGoals'] != null &&
        details['personalGoals'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Personal Goals',
        value: details['personalGoals'].toString(),
      ));
    }

    if (details['professionalGoals'] != null &&
        details['professionalGoals'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Professional Goals',
        value: details['professionalGoals'].toString(),
      ));
    }

    if (details['talents'] != null && details['talents'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Talents & Skills',
        value: details['talents'].toString(),
      ));
    }

    if (details['others'] != null && details['others'].toString().isNotEmpty) {
      widgets.add(_buildDetailRow(
        label: 'Other Matters',
        value: details['others'].toString(),
      ));
    }

    return widgets;
  }

  Widget _buildStudentInfoCard() {
    final data = _studentData ?? widget.initialData;

    return _buildInfoCard(
      title: 'Student Information',
      icon: Icons.person,
      iconColor: _primaryColor,
      children: [
        _buildInfoRow(
          'Full Name',
          data['name'] ?? data['student_name'] ?? 'Unknown',
          isImportant: true,
        ),
        _buildInfoRow('Student ID', widget.studentId),

        // Contact Info
        if (data['contact'] != null) ...[
          if (data['contact']['student_email'] != null)
            _buildInfoRow('Email', data['contact']['student_email']),
          if (data['contact']['mobile_no'] != null)
            _buildInfoRow('Mobile', data['contact']['mobile_no'].toString()),
        ],

        // Academic Info
        const SizedBox(height: 8),
        Text(
          'Academic Information',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Program Type', data['program_type'] ?? 'UG'),
        _buildInfoRow('Batch', data['batch'] ?? 'Not specified'),
        _buildInfoRow('Stream', data['stream'] ?? 'Not specified'),
        if (data['current_academic'] != null) ...[
          if (data['current_academic']['program_name'] != null)
            _buildInfoRow(
              'Program',
              data['current_academic']['program_name'],
            ),
          if (data['current_academic']['department_name'] != null)
            _buildInfoRow(
              'Department',
              data['current_academic']['department_name'],
            ),
          if (data['current_academic']['section'] != null)
            _buildInfoRow('Section', data['current_academic']['section']),
        ],
      ],
      index: 0,
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
    required int index,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      transform: Matrix4.translationValues(
        0,
        _isLoading ? 20.0 : 0.0,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isImportant = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: _textPrimary,
              fontWeight: isImportant ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ));
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _backgroundColor,
    appBar: AppBar(
      backgroundColor: _primaryColor,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _secondaryColor],
          ),
        ),
      ),
      title: const Text(
        'Student Profile',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          onPressed: () {},
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _studentDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? widget.initialData;
        _studentData = data;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  children: [
                    // Profile Header with UPDATED background color and added statistics
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE3F2FD), // Changed to lighter blue
                            Color(0xFFBBDEFB), // Changed to lighter blue
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Profile Image
                          AnimatedScale(
                            scale: _isLoading ? 0.8 : 1.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            child: Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _primaryColor, width: 3),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: _photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: _photoUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: _primaryColor.withOpacity(0.1),
                                          child: Icon(
                                            Icons.person,
                                            color: _primaryColor,
                                            size: 40,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: _primaryColor.withOpacity(0.1),
                                          child: Icon(
                                            Icons.person,
                                            color: _primaryColor,
                                            size: 40,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: _primaryColor.withOpacity(0.1),
                                        child: Icon(
                                          Icons.person,
                                          color: _primaryColor,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _isLoading ? 0 : 1,
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              data['name'] ?? data['student_name'],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedOpacity(
                            opacity: _isLoading ? 0 : 1,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              'ID: ${widget.studentId}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                          
                          // Mentoring Statistics in Header
                          if (_mentoringSessions.isNotEmpty)
                            AnimatedOpacity(
                              opacity: _isLoading ? 0 : 1,
                              duration: const Duration(milliseconds: 700),
                              child: _buildMentoringStatsInHeader(),
                            ),
                        ],
                      ),
                    ),

                    // Information Cards
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Student Information Card
                          AnimatedOpacity(
                            opacity: _isLoading ? 0 : 1,
                            duration: const Duration(milliseconds: 400),
                            child: _buildStudentInfoCard(),
                          ),

                          // Mentoring Sessions Cards
                          if (_mentoringSessions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              opacity: _isLoading ? 0 : 1,
                              duration: const Duration(milliseconds: 600),
                              child: Text(
                                'Mentoring Sessions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._mentoringSessions
                                .asMap()
                                .entries
                                .map((entry) =>
                                    _buildSessionCard(entry.value, entry.key))
                                .toList(),
                          ],

                          // Empty State for Sessions
                          if (_mentoringSessions.isEmpty)
                            AnimatedOpacity(
                              opacity: _isLoading ? 0 : 1,
                              duration: const Duration(milliseconds: 600),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.meeting_room_outlined,
                                      size: 60,
                                      color: _textSecondary.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Mentoring Sessions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No mentoring sessions have been conducted with this student yet.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}


}
// ==================== SESSION DETAILS SHEET ====================
class SessionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> session;
  final Color primaryColor;

  const SessionDetailsSheet(
      {super.key, required this.session, required this.primaryColor});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade600;
      case 'scheduled':
        return Colors.orange.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionDate = DateTime.parse(session['session_date']).toLocal();
    final nextSessionDate = session['next_session_date'] != null
        ? DateTime.parse(session['next_session_date']).toLocal()
        : null;
    final createdAt = DateTime.parse(session['createdAt']).toLocal();
    final updatedAt = DateTime.parse(session['updatedAt']).toLocal();
    final status = session['status'] ?? 'scheduled';
    final details = session['details_matters'] is List &&
            (session['details_matters'] as List).isNotEmpty
        ? (session['details_matters'] as List).first
        : {};

    final textPrimary = Colors.grey.shade800;
    final textSecondary = Colors.grey.shade600;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.meeting_room,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session['student_name'] ?? 'Unknown Student',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'ID: ${session['student_id']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    _getStatusColor(status).withOpacity(0.3)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                  ],
                ),
              ),

              // Details
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Session Information
                      _buildDetailSection(
                        title: 'Session Information',
                        icon: Icons.info,
                        color: primaryColor,
                        children: [
                          _buildDetailRow('Session Date',
                              DateFormat('dd MMMM yyyy').format(sessionDate)),
                          if (nextSessionDate != null)
                            _buildDetailRow(
                                'Next Session',
                                DateFormat('dd MMMM yyyy')
                                    .format(nextSessionDate)),
                          _buildDetailRow(
                              'Mentor ID', session['mentor_id'] ?? 'N/A'),
                          _buildDetailRow('Student Email',
                              session['student_email'] ?? 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Details & Matters
                      if (details.isNotEmpty)
                        _buildDetailSection(
                          title: 'Session Details',
                          icon: Icons.description,
                          color: Colors.green.shade600,
                          children: [
                            if (details['attendance'] != null &&
                                details['attendance'].toString().isNotEmpty)
                              _buildDetailRow('Attendance',
                                  details['attendance'].toString()),
                            if (details['academicPerformance'] != null &&
                                details['academicPerformance']
                                    .toString()
                                    .isNotEmpty)
                              _buildDetailRow('Academic Performance',
                                  details['academicPerformance'].toString()),
                            if (details['arrears'] != null &&
                                details['arrears'].toString().isNotEmpty)
                              _buildDetailRow(
                                  'Arrears', details['arrears'].toString()),
                            if (details['personalGoals'] != null &&
                                details['personalGoals'].toString().isNotEmpty)
                              _buildDetailRow('Personal Goals',
                                  details['personalGoals'].toString()),
                            if (details['professionalGoals'] != null &&
                                details['professionalGoals']
                                    .toString()
                                    .isNotEmpty)
                              _buildDetailRow('Professional Goals',
                                  details['professionalGoals'].toString()),
                            if (details['talents'] != null &&
                                details['talents'].toString().isNotEmpty)
                              _buildDetailRow(
                                  'Talents', details['talents'].toString()),
                            if (details['others'] != null &&
                                details['others'].toString().isNotEmpty)
                              _buildDetailRow('Other Matters',
                                  details['others'].toString()),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Mentor Feedback
                      _buildDetailSection(
                        title: 'Mentor Assessment',
                        icon: Icons.feedback,
                        color: Colors.orange.shade600,
                        children: [
                          if (session['mentor_feedback'] != null &&
                              session['mentor_feedback'].toString().isNotEmpty)
                            _buildDetailRow('Feedback',
                                session['mentor_feedback'].toString()),
                          if (session['positive_traits'] != null &&
                              session['positive_traits'].toString().isNotEmpty)
                            _buildDetailRow('Positive Traits',
                                session['positive_traits'].toString()),
                          if (session['corrective_measures'] != null &&
                              session['corrective_measures']
                                  .toString()
                                  .isNotEmpty)
                            _buildDetailRow('Corrective Measures',
                                session['corrective_measures'].toString()),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Metadata
                      _buildDetailSection(
                        title: 'System Information',
                        icon: Icons.history,
                        color: Colors.grey.shade600,
                        children: [
                          _buildDetailRow(
                              'Created',
                              DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(createdAt)),
                          _buildDetailRow(
                              'Last Updated',
                              DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(updatedAt)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
