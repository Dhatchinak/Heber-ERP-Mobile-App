// staff_timetable_screen.dart - COMPLETELY SAFE VERSION
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


class StaffTimetableScreen extends StatefulWidget {
  const StaffTimetableScreen({super.key});

  @override
  State<StaffTimetableScreen> createState() => _StaffTimetableScreenState();
}

class _StaffTimetableScreenState extends State<StaffTimetableScreen> {
  // API Constants
  final String _baseApiUrl = "https://apierp.bhc.edu.in/api";
  final String _refererUrl = "http://117.232.64.75";

  // State
  List<Map<String, dynamic>> _timetableData = [];
  bool _isLoading = true;
  String _errorMessage = "";

  // Day selection (1-6)
  int _selectedDayOrder = 1;

  // Staff info
  String _staffName = '';
  String _designation = '';
  String _department = '';

  // Statistics
  int _totalClasses = 0;

  // Time slots mapping
  static const Map<int, String> _timeSlots = {
    1: '8:30 – 9:25',
    2: '9:25 – 10:20',
    3: '10:20 – 11:15',
    4: '11:30 – 12:20',
    5: '12:20 – 1:10',
    6: '2:00 – 3:00',
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AuthProvider>();
    final staffId = authProvider.userData?['staff_id'];
    _staffName = authProvider.userData?['name'] ?? 'Staff Member';
    _designation = authProvider.userData?['designation'] ?? '';
    _department = authProvider.userData?['department_name'] ?? '';

    if (staffId != null) {
      await _fetchStaffData(staffId);
    } else {
      setState(() {
        _errorMessage = "Staff ID not found. Please login again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStaffData(String staffId) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });

      final response = await http.get(
        Uri.parse("$_baseApiUrl/staff/$staffId"),
        headers: {
          'Referer': _refererUrl,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Safely extract data with null checks
        final classes = data['class_attend'] as List? ?? [];

        setState(() {
          _timetableData = classes.map((cls) {
            return {
              'dayOrder': cls['dayOrder'] ?? 0,
              'hour': cls['hour'] ?? 0,
              'program_id': cls['program_id']?.toString() ?? 'Unknown',
              'section_name': cls['section_name']?.toString() ?? '',
              'year': cls['year']?.toString() ?? '',
              'room': cls['room']?.toString() ?? '',
              'department_name': cls['department_name']?.toString() ?? '',
            };
          }).toList();

          _staffName = data['name']?.toString() ?? _staffName;
          _designation = data['designation']?.toString() ?? _designation;
          _department = data['department_name']?.toString() ?? _department;
          _totalClasses = _timetableData.length;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load staff data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading timetable: $e";
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getSelectedDayTimetable() {
    final filtered = _timetableData
        .where((cls) => cls['dayOrder'] == _selectedDayOrder)
        .toList();
    filtered.sort((a, b) => (a['hour'] ?? 0).compareTo(b['hour'] ?? 0));
    return filtered;
  }

  int _getClassesForDay(int dayOrder) {
    return _timetableData.where((cls) => cls['dayOrder'] == dayOrder).length;
  }

  Color _getProgramColor(String? program) {
    final theme = context.staffTheme;
    if (program == null) return theme.cyan;

    const programColors = {
      'UG-BSC-CS': Color(0xFF2563EB),
      'UG-BSC-IT': Color(0xFF059669),
      'UG-BBA': Color(0xFF7C3AED),
      'UG-BCOM': Color(0xFFD97706),
      'UG-BCA': Color(0xFF0891B2),
      'PG-MSC-CS': Color(0xFFDC2626),
      'PG-MBA': Color(0xFFDB2777),
    };

    return programColors[program] ?? theme.cyan;
  }

  bool get _isHod {
    final authProvider = context.read<AuthProvider>();
    return authProvider.userRole == UserRole.hod;
  }

  // ==================== UI BUILDING ====================

  @override
  Widget build(BuildContext context) {
    final theme = context.staffThemeWatch;

    return Scaffold(
      backgroundColor: theme.bg,
      drawer: AppDrawer(isHod: _isHod, currentRoute: '/timetable'),
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        toolbarHeight: 64,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child: Icon(Icons.menu_rounded, color: theme.textHigh, size: 18),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Timetable',
              style: TextStyle(
                color: theme.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              _department.isNotEmpty ? _department : 'Schedule',
              style: TextStyle(
                color: theme.cyan.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.green,
                    boxShadow: [
                      BoxShadow(
                          color: theme.green.withOpacity(0.6), blurRadius: 4)
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: theme.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child:
                  Icon(Icons.refresh_rounded, color: theme.textMid, size: 18),
            ),
            onPressed: _initializeData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(StaffThemeProvider theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.cyan,
                backgroundColor: theme.cyan.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Timetable',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fetching your schedule...',
              style: TextStyle(fontSize: 13, color: theme.textMid),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.pink.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.pink.withOpacity(0.22)),
                ),
                child: Icon(Icons.error_outline_rounded,
                    size: 48, color: theme.pink),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to Load Timetable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textHigh,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: theme.textMid, height: 1.4),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _initializeData,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [theme.cyan, theme.violet]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: theme.cyan.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Main content - using SafeArea to ensure proper constraints
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeroBanner(theme),
            const SizedBox(height: 20),
            _buildDayPicker(theme),
            const SizedBox(height: 20),
            _buildScheduleSection(theme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(StaffThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.cyan,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: theme.cyan.withOpacity(0.6), blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WEEKLY SCHEDULE',
                      style: TextStyle(
                        color: theme.cyan.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _staffName,
                  style: TextStyle(
                    color: theme.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _designation,
                  style: TextStyle(color: theme.textMid, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoPill(
                        theme, Icons.school_rounded, _department, theme.cyan),
                    _buildInfoPill(
                      theme,
                      Icons.class_rounded,
                      '$_totalClasses Total Classes',
                      theme.violet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.cyan.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, color: theme.cyan, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Day',
                  style: TextStyle(
                      color: theme.textMid,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '$_selectedDayOrder',
                  style: TextStyle(
                    color: theme.cyan,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(
      StaffThemeProvider theme, IconData icon, String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker(StaffThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: theme.cyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Select Day',
              style: TextStyle(
                color: theme.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Day 1–6 Rotation',
              style: TextStyle(color: theme.textLow, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(6, (index) {
            final dayOrder = index + 1;
            final isSelected = _selectedDayOrder == dayOrder;
            final classCount = _getClassesForDay(dayOrder);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDayOrder = dayOrder;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [theme.cyan, theme.violet])
                        : null,
                    color: isSelected ? null : theme.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : theme.border,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.cyan.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayOrder',
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.textHigh,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DAY',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withOpacity(0.7)
                              : theme.textLow,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (classCount > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : theme.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$classCount',
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(StaffThemeProvider theme) {
    final classes = _getSelectedDayTimetable();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: theme.violet,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Day $_selectedDayOrder — Schedule',
              style: TextStyle(
                color: theme.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cyan.withOpacity(0.25)),
              ),
              child: Text(
                '${classes.length} class${classes.length != 1 ? 'es' : ''}',
                style: TextStyle(
                  color: theme.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (classes.isEmpty)
          _buildEmptyDayCard(theme)
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < classes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildClassCard(theme, classes[i]),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildClassCard(
      StaffThemeProvider theme, Map<String, dynamic> classItem) {
    // Safely extract values with defaults
    final hour = (classItem['hour'] ?? 0) as int;
    final program = (classItem['program_id'] ?? 'Unknown').toString();
    final section = (classItem['section_name'] ?? '').toString();
    final year = (classItem['year'] ?? '').toString();
    final room = (classItem['room'] ?? '').toString();
    final color = _getProgramColor(program);
    final timeSlot = _timeSlots[hour] ?? 'Time not available';

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.12), color.withOpacity(0.05)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$hour',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: timeSlot
                          .split(' – ')
                          .map((time) => Text(
                                time.trim(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Details column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Text(
                          program,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (room.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.elevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.meeting_room_rounded,
                                  size: 10, color: theme.textMid),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: TextStyle(
                                    color: theme.textMid, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Year $year • Section $section',
                    style: TextStyle(
                      color: theme.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.elevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(Icons.access_time_rounded,
                            size: 14, color: theme.textMid),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hour $hour • $timeSlot',
                          style: TextStyle(color: theme.textMid, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayCard(StaffThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.green.withOpacity(0.06),
            theme.green.withOpacity(0.02)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.green.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.green.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: theme.green.withOpacity(0.25)),
            ),
            child:
                Icon(Icons.celebration_rounded, color: theme.green, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            'No Classes Scheduled',
            style: TextStyle(
              color: theme.textHigh,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free day! 🎉',
            style: TextStyle(color: theme.textMid, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
