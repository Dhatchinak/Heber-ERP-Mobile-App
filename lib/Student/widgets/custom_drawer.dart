import 'dart:convert';

import 'package:bhc_erp/Student/screens/academic_calendar.dart';
import 'package:bhc_erp/login/screens/unified_login_screen.dart';
import 'package:bhc_erp/Student/screens/EndSemExamResult.dart';
import 'package:bhc_erp/Student/screens/attendance_screen.dart';
import 'package:bhc_erp/Student/screens/main_page.dart';
import 'package:bhc_erp/Student/screens/manage_leaves.dart';
import 'package:bhc_erp/Student/screens/mentor_screen.dart';
import 'package:bhc_erp/Student/screens/profile_info.dart';
import 'package:bhc_erp/Student/screens/seating_arangements.dart';
import 'package:bhc_erp/Student/screens/subjects.dart';
import 'package:bhc_erp/Student/screens/time_table.dart';
import 'package:bhc_erp/Student/services/CacheService.dart';
import 'package:bhc_erp/Student/services/photo_service.dart';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomDrawer extends StatefulWidget {
  final String rollNo;
  final String studentName;
  final String? currentRoute;
  final Future<Map<String, dynamic>> Function()? fetchDrawerData;
  final Future<String?> Function()? getPhotoFuture;
  final Future<void> Function()? onRefreshPhoto;

  const CustomDrawer({
    super.key,
    required this.rollNo,
    required this.studentName,
    this.currentRoute,
    this.fetchDrawerData,
    this.getPhotoFuture,
    this.onRefreshPhoto,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  late Future<Map<String, dynamic>> _drawerDataFuture;
  String _rollNo = '';
  String _studentName = '';
  String? _photoUrl;
  bool _photoLoading = true;

  @override
  void initState() {
    super.initState();
    _rollNo = widget.rollNo.trim();
    _studentName = widget.studentName;

    if (widget.fetchDrawerData != null) {
      // Dashboard passes cached future — use directly
      _drawerDataFuture = widget.fetchDrawerData!();
    } else {
      // Other screens — will re-assign after prefs load in _initData()
      _drawerDataFuture = Future.value(_defaultDrawerData());
    }
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRollNo = prefs.getString('rollNo') ?? '';
    final savedName = prefs.getString('studentName') ?? '';

    // Synchronous state update
    if (mounted) {
      setState(() {
        if (_rollNo.isEmpty) _rollNo = savedRollNo;
        if (_studentName.isEmpty) _studentName = savedName;
      });
    }

    // Fetch drawer data (only for non-dashboard screens)
    if (widget.fetchDrawerData == null && mounted) {
      // Fetch the future (this is async, but we don't await it here)
      final future = _fetchFallbackDrawerData();
      // Update state synchronously with the future
      if (mounted) {
        setState(() {
          _drawerDataFuture = future;
        });
      }
    }

    await _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    if (mounted) setState(() => _photoLoading = true);

    try {
      // Use widget's getPhotoFuture if provided (from dashboard — already cached)
      if (widget.getPhotoFuture != null) {
        final url = await widget.getPhotoFuture!()
            .timeout(const Duration(seconds: 6), onTimeout: () => null);
        if (mounted)
          setState(() {
            _photoUrl = url;
            _photoLoading = false;
          });
        return;
      }

      // Otherwise load from cache or fetch
      final effectiveRollNo = _rollNo.isNotEmpty
          ? _rollNo
          : (await SharedPreferences.getInstance()).getString('rollNo') ?? '';

      if (effectiveRollNo.isEmpty) {
        if (mounted) setState(() => _photoLoading = false);
        return;
      }

      String? url = await PhotoService.getCachedPhotoUrl(effectiveRollNo);
      if (url == null) {
        url = await PhotoService.getStudentPhotoUrl(effectiveRollNo)
            .timeout(const Duration(seconds: 8), onTimeout: () => null);
        if (url != null) {
          await PhotoService.cacheStudentPhoto(effectiveRollNo)
              .timeout(const Duration(seconds: 5), onTimeout: () {});
        }
      }

      if (mounted)
        setState(() {
          _photoUrl = url;
          _photoLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchFallbackDrawerData() async {
    try {
      final rollNo = _rollNo.isNotEmpty
          ? _rollNo
          : (await SharedPreferences.getInstance()).getString('rollNo') ?? '';
      if (rollNo.isEmpty) return _defaultDrawerData();

      // All 3 fetches in parallel with individual short timeouts
      final results = await Future.wait([
        _fetchCalendarData(),
        _fetchAttendanceData(rollNo),
        _fetchStudentProfile(rollNo),
      ]).timeout(const Duration(seconds: 10), onTimeout: () => [{}, {}, {}]);

      final calData = results[0] as Map<String, dynamic>;
      final attData = results[1] as Map<String, dynamic>;
      final profile = results[2] as Map<String, dynamic>;

      final semInfo = _calcSemInfo(calData);
      final att = _calcAttendancePct(attData);

      // Fetch courses in parallel too — don't await sequentially
      final courses = await _fetchCoursesCount(profile)
          .timeout(const Duration(seconds: 8), onTimeout: () => 0);

      return {
        'currentSemester': semInfo['semester'],
        'currentSemesterName': semInfo['semesterName'],
        'weeksCompleted': semInfo['weeksCompleted'],
        'totalWeeks': semInfo['totalWeeks'],
        'currentSemesterCourses': courses,
        'currentCGPA': 0.0,
        'attendancePercentage': att,
        'isCurrentSemester': true,
        'usingFallback': profile.isEmpty,
      };
    } catch (e) {
      debugPrint('DrawerFallback error: $e');
      return _defaultDrawerData();
    }
  }

  // Fetch real student profile for drawer
  Future<Map<String, dynamic>> _fetchStudentProfile(String rollNo) async {
    try {
      final resp = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/students/$rollNo'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200)
        return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  // Fetch real subject count from subjects API
  Future<int> _fetchCoursesCount(Map<String, dynamic> profileResp) async {
    try {
      final studentData = profileResp['data'] as Map<String, dynamic>?;
      if (studentData == null) return 6;
      final currentAcademic =
          studentData['current_academic'] as Map<String, dynamic>?;
      final programName = currentAcademic?['degree_name'] as String? ?? '';
      final section = currentAcademic?['section'] as String? ?? 'A';
      final batch = studentData['batch'] as String? ?? '';

      // Calculate academic year from batch
      int year = 1;
      if (batch.isNotEmpty) {
        final parts = batch.split('-');
        if (parts.length == 2) {
          final startYear = int.tryParse(parts[0]) ?? DateTime.now().year;
          final now = DateTime.now();
          final diff = now.year - startYear + (now.month >= 6 ? 1 : 0);
          year = diff.clamp(1, 4);
        }
      }

      final resp = await http
          .post(
            Uri.parse('https://apierp.bhc.edu.in/api/students/subjects/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Referer': 'http://117.232.64.75',
            },
            body: jsonEncode({
              'program_name': programName,
              'year': year.toString(),
              'section_name': section,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final subjects = data['data']['subjects'] as List<dynamic>?;
          if (subjects != null && subjects.isNotEmpty) return subjects.length;
        }
      }
    } catch (e) {
      debugPrint('DrawerCourses error: $e');
    }
    return 6;
  }

  Map<String, dynamic> _defaultDrawerData() {
    // Dynamically detect semester from current month
    final month = DateTime.now().month;
    final isOdd = month >= 6 && month <= 11;
    return {
      'currentSemester': isOdd ? 1 : 2,
      'currentSemesterName': isOdd ? 'Odd Semester' : 'Even Semester',
      'weeksCompleted': 0,
      'totalWeeks': 16,
      'currentSemesterCourses': 0, // 0 = loading, will be replaced by real data
      'currentCGPA': 0.0,
      'attendancePercentage': 0.0,
      'isCurrentSemester': true,
      'usingFallback': true,
    };
  }

  String _getOrdinalSemester(int semester) {
    const suffixes = [
      '',
      '1st',
      '2nd',
      '3rd',
      '4th',
      '5th',
      '6th',
      '7th',
      '8th'
    ];
    return semester < suffixes.length ? suffixes[semester] : '${semester}th';
  }

  void _navigateTo(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ─── PHOTO WIDGET ─────────────────────────────────────────────────────────
  Widget _buildPhotoWidget(ThemeProvider c) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.cyan.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(color: c.cyan.withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: ClipOval(
        child: _photoLoading
            ? Container(
                color: c.elevated,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.cyan,
                    ),
                  ),
                ),
              )
            : _photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    fit: BoxFit.cover,
                    width: 64,
                    height: 64,
                    httpHeaders: PhotoService.headers,
                    placeholder: (_, __) => Container(
                      color: c.elevated,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.cyan,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildAvatarFallback(c),
                  )
                : _buildAvatarFallback(c),
      ),
    );
  }

  Widget _buildAvatarFallback(ThemeProvider c) {
    final initials = _studentName.isNotEmpty
        ? _studentName
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    return Container(
      color: c.cyan.withOpacity(0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: c.cyan,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ─── LOGOUT ──────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    CacheService.clear();
    final c = Provider.of<ThemeProvider>(context, listen: false);
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(c.isDarkMode ? 0.7 : 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.pink.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: c.pink.withOpacity(0.15), blurRadius: 30)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.pink.withOpacity(0.15),
                      c.pinkDim.withOpacity(0.08)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.pink.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.pink.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.power_settings_new_rounded,
                          color: c.pink, size: 30),
                    ),
                    const SizedBox(height: 16),
                    Text("Sign Out?",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.textHigh)),
                    const SizedBox(height: 8),
                    Text(
                      "You'll need to sign in again to access your account",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: c.textMid, height: 1.4),
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
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.border),
                          foregroundColor: c.textMid,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.pink,
                          foregroundColor:
                              c.isDarkMode ? Colors.white : c.textHigh,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 16),
                            SizedBox(width: 6),
                            Text("Logout",
                                style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );

    if (shouldLogout == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: c.pink),
                ),
                const SizedBox(height: 20),
                Text("Signing out...",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textMid)),
              ],
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1200));
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await PhotoService.clearAllCachedPhotos();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const UnifiedLoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final isDashboard = widget.currentRoute == '/dashboard';
    final isProfile = widget.currentRoute == '/profile';
    final isTimetable = widget.currentRoute == '/timetable';
    final isSubjects = widget.currentRoute == '/subjects';
    final isMentor = widget.currentRoute == '/mentor';
    final isAttendance = widget.currentRoute == '/attendance';
    final isLeave = widget.currentRoute == '/leave';
    final isExamResults = widget.currentRoute == '/exam-results';
    final isSeating = widget.currentRoute == '/seating';
    final isCalendar = widget.currentRoute == '/calendar';

    final displayRollNo = _rollNo.isNotEmpty ? _rollNo : widget.rollNo;
    final displayName =
        _studentName.isNotEmpty ? _studentName : widget.studentName;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(right: BorderSide(color: c.border, width: 1)),
        ),
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.elevated, c.elevated2],
                ),
                border: Border(bottom: BorderSide(color: c.border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo
                      _buildPhotoWidget(c),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: c.textHigh,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Roll No chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.cyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: c.cyan.withOpacity(0.3)),
                              ),
                              child: Text(
                                displayRollNo.isNotEmpty
                                    ? displayRollNo
                                    : 'Loading...',
                                style: TextStyle(
                                  color: c.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: c.green, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Active Student",
                                  style: TextStyle(
                                      color: c.textMid,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── STATS ────────────────────────────────────────────────
                  FutureBuilder<Map<String, dynamic>>(
                    future: _drawerDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingStats(c); // Add loading state
                      }

                      if (snapshot.hasError) {
                        return _buildErrorStats(c); // Add error state
                      }

                      final data = snapshot.data ?? _defaultDrawerData();
                      final semester = data?['currentSemester'] ?? 1;
                      final semesterName =
                          data?['currentSemesterName'] ?? 'Semester';
                      final weeksCompleted = data?['weeksCompleted'] ?? 0;
                      final totalWeeks = data?['totalWeeks'] ?? 16;
                      final courses = data?['currentSemesterCourses'] ?? 6;
                      final attendancePct =
                          (data?['attendancePercentage'] ?? 0.0) as double;
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(semesterName,
                                    style: TextStyle(
                                        color: c.textHigh,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text("Week $weeksCompleted/$totalWeeks",
                                    style: TextStyle(
                                        color: c.textMid, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalWeeks > 0
                                    ? (weeksCompleted / totalWeeks)
                                        .clamp(0.0, 1.0)
                                    : 0,
                                backgroundColor: c.border,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(c.cyan),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            isLoading
                                ? Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: c.cyan),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _drawerStat(
                                        (data?['usingFallback'] == true)
                                            ? (semesterName.replaceAll(
                                                ' Semester',
                                                '')) // "Even" or "Odd"
                                            : _getOrdinalSemester(
                                                semester), // "2nd" when profile loaded
                                        "SEM",
                                        c.violet,
                                        c,
                                      ),
                                      _vDivider(c),
                                      _drawerStat(
                                          courses == 0 ? "…" : "$courses",
                                          "COURSES",
                                          c.cyan,
                                          c),
                                      _vDivider(c),
                                      _drawerStat(
                                          "${attendancePct.toStringAsFixed(0)}%",
                                          "ATTEND",
                                          c.green,
                                          c),
                                    ],
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── NAV ITEMS ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    _navGroup("MAIN", [
                      _navItem(Icons.dashboard_rounded, "Dashboard", c.cyan,
                          isDashboard, c,
                          onTap: () => _navigateTo(MainPage(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                    ]),
                    _navGroup("ACADEMICS", [
                      _navItem(Icons.person_rounded, "My Profile", c.violet,
                          isProfile, c,
                          onTap: () => _navigateTo(ProfileScreen(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                      _navItem(Icons.schedule_rounded, "Timetable", c.cyan,
                          isTimetable, c,
                          onTap: () => _navigateTo(
                              TimetableScreen(rollNo: displayRollNo))),
                      // In custom_drawer.dart - UPDATE THIS:
                      _navItem(Icons.subject_rounded, "Subjects", c.green,
                          isSubjects, c,
                          onTap: () => _navigateTo(SubjectsPage(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                      _navItem(Icons.school_rounded, "Student Mentor", c.amber,
                          isMentor, c,
                          onTap: () => _navigateTo(MentorScreen(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                    ]),
                    _navGroup("ATTENDANCE", [
                      _navItem(Icons.calendar_today_rounded, "Daily Attendance",
                          c.cyan, isAttendance, c,
                          onTap: () => _navigateTo(AttendanceScreen(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                      _navItem(Icons.leave_bags_at_home_rounded,
                          "Leave Management", c.pink, isLeave, c,
                          onTap: () => _navigateTo(LeaveManagementScreen(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                    ]),
                    _navGroup("EXAMINATIONS", [
                      _navItem(Icons.grade_rounded, "Exam Results", c.green,
                          isExamResults, c,
                          onTap: () => _navigateTo(ExamResultsPage(
                              studentName: displayName,
                              rollNo: displayRollNo))),
                      _navItem(Icons.chair_rounded, "Seating Arrangement",
                          c.violet, isSeating, c,
                          onTap: () => _navigateTo(SeatingArrangementPage(
                              studentName: displayName,
                              rollNo: displayRollNo))),
                    ]),
                    _navGroup("CAMPUS", [
                      _navItem(Icons.event_rounded, "Academic Calendar",
                          c.amber, isCalendar, c,
                          onTap: () => _navigateTo(AcademicCalendarScreen(
                              rollNo: displayRollNo,
                              studentName: displayName))),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── FOOTER ──────────────────────────────────────────────────────
            _buildDrawerFooter(c),
          ],
        ),
      ),
    );
  }

  Widget _drawerStat(String value, String label, Color color, ThemeProvider c) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: c.textLow,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _vDivider(ThemeProvider c) =>
      Container(width: 1, height: 28, color: c.border);

  Widget _navGroup(String title, List<Widget> items) {
    final c = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(title,
              style: TextStyle(
                  color: c.textLow,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ),
        ...items,
      ],
    );
  }

  Widget _navItem(IconData icon, String title, Color color, bool isSelected,
      ThemeProvider c,
      {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: color.withOpacity(0.25)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 0,
        horizontalTitleGap: 12,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : c.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.4) : c.border,
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Icon(icon, color: isSelected ? color : c.textMid, size: 17),
        ),
        title: Text(title,
            style: TextStyle(
              color: isSelected ? color : c.textMid,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            )),
        trailing: isSelected
            ? Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.6), size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerFooter(ThemeProvider c) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.cyan.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 12,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: c.cyan,
                      size: 17,
                    ),
                  ),
                  title: Text(
                    themeProvider.isDarkMode ? "Dark Mode" : "Light Mode",
                    style: TextStyle(
                        color: c.textHigh,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: c.cyan,
                    activeTrackColor: c.cyan.withOpacity(0.3),
                    inactiveThumbColor: c.textMid,
                    inactiveTrackColor: c.border,
                  ),
                  onTap: () => themeProvider.toggleTheme(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.pink.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.pink.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 12,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.pink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded, color: c.pink, size: 17),
                  ),
                  title: Text("Logout",
                      style: TextStyle(
                          color: c.pink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  onTap: _handleLogout,
                ),
              ),
              const SizedBox(height: 10),
              Text("Heber ERP v1.0.0",
                  style: TextStyle(
                      color: c.textLow, fontSize: 11, letterSpacing: 0.5)),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchCalendarData() async {
    try {
      final now = DateTime.now();
      final ay = '${now.year}-${now.year + 1}';
      final resp = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/academic_calendar/$ay'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null)
          return body['data'];
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> _fetchAttendanceData(String rollNo) async {
    try {
      final resp = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/students/attendance/$rollNo'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200)
        return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

// In custom_drawer.dart - REPLACE _calcSemInfo method:
Map<String, dynamic> _calcSemInfo(Map<String, dynamic> cal) {
  final now = DateTime.now();
  
  // Try to detect from calendar dates first
  if (cal.isNotEmpty) {
    for (final entry in [
      {'key': 'sem_odd', 'sem': 1, 'name': 'Odd Semester'},
      {'key': 'sem_even', 'sem': 2, 'name': 'Even Semester'},
    ]) {
      final sem = cal[entry['key']] as Map<String, dynamic>?;
      if (sem != null && sem['startDate'] != null && sem['endDate'] != null) {
        try {
          final s = DateTime.parse(sem['startDate']);
          final e = DateTime.parse(sem['endDate']);
          if (now.isAfter(s.subtract(const Duration(days: 1))) &&
              now.isBefore(e.add(const Duration(days: 1)))) {
            final totalWeeks = ((e.difference(s).inDays) / 7).ceil().clamp(1, 26);
            final weeksCompleted = now.isBefore(s)
                ? 0
                : ((now.difference(s).inDays) / 7).floor().clamp(0, totalWeeks);
            return {
              'semester': entry['sem'],
              'semesterName': entry['name'],
              'weeksCompleted': weeksCompleted,
              'totalWeeks': totalWeeks,
            };
          }
        } catch (e) {
          debugPrint('Error parsing dates: $e');
        }
      }
    }
  }
  
  // Fallback: use month-based detection
  final isOdd = now.month >= 6 && now.month <= 11;
  final currentYear = now.year;
  DateTime startDate;
  DateTime endDate;
  
  if (isOdd) {
    startDate = DateTime(currentYear, 6, 1);
    endDate = DateTime(currentYear, 11, 30);
  } else {
    startDate = DateTime(currentYear, 12, 1);
    endDate = DateTime(currentYear + 1, 5, 31);
  }
  
  final totalWeeks = ((endDate.difference(startDate).inDays) / 7).ceil().clamp(1, 26);
  final weeksCompleted = now.isBefore(startDate)
      ? 0
      : ((now.difference(startDate).inDays) / 7).floor().clamp(0, totalWeeks);
  
  return {
    'semester': isOdd ? 1 : 2,
    'semesterName': isOdd ? 'Odd Semester' : 'Even Semester',
    'weeksCompleted': weeksCompleted,
    'totalWeeks': totalWeeks,
  };
}


  double _calcAttendancePct(Map<String, dynamic> data) {
    try {
      // Shape A: { attendance: [ {sem_even: [...], sem_odd: [...]} ] }
      if (data['attendance'] is List) {
        final list = data['attendance'] as List;
        if (list.isEmpty) return 0.0;
        double totalAbsent = 0.0;
        int totalDays = 0;
        for (final yearItem in list) {
          for (final semKey in ['sem_even', 'sem_odd']) {
            final semList = yearItem[semKey] as List? ?? [];
            for (final dayObj in semList) {
              if (dayObj is! Map<String, dynamic>) continue;
              dayObj.forEach((_, dayData) {
                if (dayData is! Map<String, dynamic>) return;
                final hours = dayData['hours'] as List? ?? [];
                if (hours.isEmpty) return;
                totalDays++;
                final present = hours
                    .where((h) =>
                        h['status']?.toString().toLowerCase() == 'present')
                    .length;
                final absent = hours.length - present;
                if (absent >= 3)
                  totalAbsent += 1.0;
                else if (absent >= 1) totalAbsent += 0.5;
              });
            }
          }
        }
        return totalDays > 0
            ? ((totalDays - totalAbsent) / totalDays) * 100
            : 0.0;
      }

      // Shape B: { success: true, data: [ { attendance: { sem_even: [...] } } ] }
      if (data['success'] == true && data['data'] is List) {
        final dataList = data['data'] as List;
        if (dataList.isEmpty) return 0.0;
        final att = dataList[0]['attendance'];
        if (att is Map<String, dynamic>) {
          double totalAbsent = 0.0;
          int totalDays = 0;
          for (final semKey in ['sem_even', 'sem_odd']) {
            final semList = att[semKey] as List? ?? [];
            for (final dayObj in semList) {
              if (dayObj is! Map<String, dynamic>) continue;
              dayObj.forEach((_, dayData) {
                if (dayData is! Map) return;
                final hours = (dayData as Map)['hours'] as List? ?? [];
                if (hours.isEmpty) return;
                totalDays++;
                final present = hours
                    .where((h) =>
                        h['status']?.toString().toLowerCase() == 'present')
                    .length;
                final absent = hours.length - present;
                if (absent >= 3)
                  totalAbsent += 1.0;
                else if (absent >= 1) totalAbsent += 0.5;
              });
            }
          }
          return totalDays > 0
              ? ((totalDays - totalAbsent) / totalDays) * 100
              : 0.0;
        }
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }
  
Widget _buildLoadingStats(ThemeProvider c) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.bg.withOpacity(0.5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    ),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.cyan),
      ),
    ),
  );
}

Widget _buildErrorStats(ThemeProvider c) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.bg.withOpacity(0.5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.pink.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: c.pink, size: 24),
        const SizedBox(height: 8),
        Text(
          "Failed to load stats",
          style: TextStyle(color: c.textMid, fontSize: 12),
        ),
      ],
    ),
  );
}}
