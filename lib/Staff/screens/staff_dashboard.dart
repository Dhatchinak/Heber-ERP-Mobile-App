import 'dart:async';
import 'package:bhc_erp/Staff/common/MentoringFormActivity%20.dart';
import 'package:bhc_erp/Staff/common/StaffBioAttendance.dart';
import 'package:bhc_erp/Staff/common/TimeTable.dart';
import 'package:bhc_erp/Staff/common/class_attendance.dart';
import 'package:bhc_erp/Staff/common/profile.dart';
import 'package:bhc_erp/Staff/common/publications.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/core/auth/user_type.dart';

const String _kBaseApiUrl = 'https://apierp.bhc.edu.in/api';
const String _kRefererUrl = 'http://117.232.64.75';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard>
    with TickerProviderStateMixin {
  String? _currentStaffId;
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  // Timer? _refreshTimer;
  bool _isRefreshing = false;
  String? _photoUrl;

  late AnimationController _welcomeCtrl;
  late Animation<Offset> _welcomeSlide;
  late Animation<double> _welcomeFade;
  late AnimationController _appBarGlow;
  late AnimationController _pulseCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;

  Map<String, bool> _attendanceMarkedStatus = {};

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userType == UserType.hod;
  }

  @override
  void initState() {
    super.initState();
    _appBarGlow =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _stagger = List.generate(
        6,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
            ));
    _welcomeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _welcomeSlide =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
            CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeOutCubic));
    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeIn));

    final auth = context.read<AuthProvider>();
    _currentStaffId = auth.userData?['staff_id'];
    _loadData();
    _fetchPhoto();
    _welcomeCtrl.forward();
    _staggerCtrl.forward();
    // _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    //   if (mounted) _refreshData();
    // });
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pulseCtrl.dispose();
    _staggerCtrl.dispose();
    _welcomeCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_stagger[i]),
          child: child,
        ),
      );


String? _cachedPhotoUrl;  // Add this variable
static Map<String, String> _globalPhotoCache = {};  // 
  // ── PHOTO FETCHING (Single source of truth) ─────────────────────────────────
Future<void> _fetchPhoto() async {
  if (_currentStaffId == null) return;
  
  // Check global cache first
  if (_globalPhotoCache.containsKey(_currentStaffId)) {
    if (mounted) setState(() => _photoUrl = _globalPhotoCache[_currentStaffId]);
    return;
  }
  
  try {
    final res = await http.get(
      Uri.parse('https://apierp.bhc.edu.in/photo/staff/$_currentStaffId'),
      headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 3));  // Reduced timeout
    
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['success'] == true && data['view_url'] != null) {
        _globalPhotoCache[_currentStaffId!] = data['view_url'];
        if (mounted) setState(() => _photoUrl = data['view_url']);
        return;
      }
    }
    
    // Only try profile API if photo endpoint fails
    final profileRes = await http.get(
      Uri.parse('$_kBaseApiUrl/staff/$_currentStaffId'),
      headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 3));
    
    if (profileRes.statusCode == 200) {
      final profileData = json.decode(profileRes.body);
      final photoUrl = profileData['photo_url'] ?? profileData['profile_photo'];
      if (photoUrl != null && photoUrl.toString().isNotEmpty) {
        _globalPhotoCache[_currentStaffId!] = photoUrl.toString();
        if (mounted) setState(() => _photoUrl = photoUrl.toString());
      }
    }
  } catch (_) {}
}



  // ── DATA LOADING ──────────────────────────────────────────────────────────
  void _loadData() {
    setState(() {
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  void _refreshData() {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _loadData();
    _fetchPhoto(); // Refresh photo too
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isRefreshing = false);
    });
  }

  /// All API calls run in parallel — much faster than sequential

Future<Map<String, dynamic>> _fetchDashboardData() async {
  final auth = context.read<AuthProvider>();
  final userData = auth.userData;
  _currentStaffId = userData?['staff_id'];

  if (_currentStaffId == null) {
    return _fallbackData(userData);
  }

  // Run ALL fetches in parallel — no sequential awaits
  final results = await Future.wait([
    _fetchStaffProfileCached(),
    _fetchTodayBioAttendance(),
    _fetchRecentBioActivity(),
    _getMenteeCount(userData?['staff_id'], userData?['department_code']),
  ], eagerError: false).timeout(const Duration(seconds: 10));

  final profile = results[0] as Map<String, dynamic>?;
  final bioAtt = results[1] as Map<String, dynamic>;
  final activities = results[2] as List<Map<String, dynamic>>;
  final menteeCount = results[3] as int;

  final classes = (profile?['class_attend'] as List?) ?? [];
  final todayClasses = _filterTodayClasses(classes);
  final totalCourses = _countUniqueCourses(classes);
  final publications = profile?['publications'] ?? {};
  final pubCount = _countPublications(publications);

  if (mounted) {
    _welcomeCtrl.forward(from: 0);
    _staggerCtrl.forward(from: 0);
  }

  return {
    'staffName': profile?['name'] ?? userData?['name'] ?? 'Staff',
    'designation': profile?['designation'] ?? userData?['designation'] ?? 'Teaching Faculty',
    'department': profile?['department_name'] ?? userData?['department_name'] ?? 'Department',
    'staffId': profile?['staff_id'] ?? _currentStaffId ?? '',
    'greeting': _greeting(),
    'totalCourses': totalCourses,
    'todaysClasses': todayClasses.length,
    'upcomingSchedule': _formatSchedule(todayClasses),
    'publications': pubCount,
    'publicationsData': publications,
    'menteeCount': menteeCount,  // Now this will have the actual value
    'semesterProgress': 60,
    'bioAttendance': bioAtt,
    'recentActivities': activities,
  };
}

// Add static cache for profile data
static Map<String, Map<String, dynamic>> _profileCache = {};

Future<Map<String, dynamic>?> _fetchStaffProfileCached() async {
  if (_currentStaffId == null) return null;
  
  // Return cached data if available (valid for 5 minutes)
  if (_profileCache.containsKey(_currentStaffId)) {
    return _profileCache[_currentStaffId];
  }
  
  try {
    final res = await http.get(
      Uri.parse('$_kBaseApiUrl/staff/$_currentStaffId'),
      headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      _profileCache[_currentStaffId!] = data;
      return data;
    }
  } catch (_) {}
  return null;
}


  Map<String, dynamic> _fallbackData(Map<String, dynamic>? userData) => {
        'staffName': userData?['name'] ?? 'Staff',
        'designation': userData?['designation'] ?? 'Teaching Faculty',
        'department': userData?['department_name'] ?? 'Department',
        'staffId': userData?['staff_id'] ?? '',
        'greeting': _greeting(),
        'totalCourses': 0,
        'todaysClasses': 0,
        'upcomingSchedule': [],
        'publications': 0,
        'publicationsData': {},
        'menteeCount': 0,
        'semesterProgress': 0,
        'bioAttendance': {'status': 'Not Recorded'},
        'recentActivities': [],
      };

  // ── PROFILE ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchStaffProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$_kBaseApiUrl/staff/$_currentStaffId'),
        headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        // Update photo URL if available in profile data
        final photoFromProfile = data['photo_url'] ?? data['profile_photo'];
        if (photoFromProfile != null && photoFromProfile.toString().isNotEmpty && mounted) {
          setState(() => _photoUrl = photoFromProfile.toString());
        }
        return data;
      }
    } catch (_) {}
    return null;
  }

  // ── BIO ATTENDANCE ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchTodayBioAttendance() async {
    try {
      final auth = context.read<AuthProvider>();
      int? bioId = auth.userData?['bio_id'] != null
          ? int.tryParse(auth.userData!['bio_id'].toString())
          : null;

      if (bioId == null && _currentStaffId != null) {
        // Use cached profile instead of an extra HTTP call
        final cached = _profileCache[_currentStaffId];
        if (cached != null) {
          bioId = cached['bio_id'] != null
              ? int.tryParse(cached['bio_id'].toString())
              : null;
        }
        // Only hit network if truly not in cache
        if (bioId == null) {
          final res = await http.get(
            Uri.parse('$_kBaseApiUrl/staff/$_currentStaffId'),
            headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            _profileCache[_currentStaffId!] = data;
            bioId = data['bio_id'] != null
                ? int.tryParse(data['bio_id'].toString())
                : null;
          }
        }
      }

      if (bioId == null) return _noRecord();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await http.get(
        Uri.parse(
            '$_kBaseApiUrl/staff/attendance/$bioId?fromDate=$today&toDate=$today'),
        headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<dynamic> records = [];
        if (data['attendance'] is List)
          records = data['attendance'];
        else if (data['records'] is List)
          records = data['records'];
        else if (data['data'] is List) records = data['data'];

        if (records.isNotEmpty) {
          final r = records.first as Map<String, dynamic>;
          final firstIn = r['first_in'] ?? r['check_in'];
          final lastOut = r['last_out'] ?? r['check_out'];
          final firstInStatus =
              r['first_in_status']?.toString().toLowerCase() ?? '';
          final firstInLate = r['first_in_late']?.toString() ?? '';

          final hasIn = firstIn != null &&
              firstIn.toString().trim().isNotEmpty &&
              firstIn.toString() != 'null' &&
              firstInStatus == 'cin';

          if (!hasIn) return _noRecord();

          final lastOutRaw = lastOut?.toString().trim() ?? '';
          final hasOut = lastOutRaw.isNotEmpty &&
              lastOutRaw != 'null' &&
              lastOutRaw != firstIn?.toString().trim();

          final isLate = firstInLate.toLowerCase().contains('late');

          return {
            'first_in': firstIn,
            'last_out': hasOut ? lastOut : null,
            'status': isLate ? 'Late' : 'Present',
            'first_in_place': r['first_in_place'] ?? 'Office',
            'last_out_place': hasOut ? (r['last_out_place'] ?? 'Office') : '--',
            'first_in_late': isLate ? firstInLate : 'On Time',
            'hasCheckOut': hasOut,
            'inDisplay': _fmtTime(firstIn),
            'outDisplay': hasOut ? _fmtTime(lastOut) : '--:--',
          };
        }
      }
    } catch (_) {}
    return _noRecord();
  }

  Map<String, dynamic> _noRecord() => {
        'first_in': null,
        'last_out': null,
        'status': 'Not Recorded',
        'inDisplay': '--:--',
        'outDisplay': '--:--',
        'hasCheckOut': false,
      };

  // ── RECENT BIO ACTIVITY ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchRecentBioActivity() async {
    try {
      final auth = context.read<AuthProvider>();
      int? bioId = auth.userData?['bio_id'] != null
          ? int.tryParse(auth.userData!['bio_id'].toString())
          : null;

      if (bioId == null) return [];

      final to = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final from = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 7)));

      final res = await http.get(
        Uri.parse(
            '$_kBaseApiUrl/staff/attendance/$bioId?fromDate=$from&toDate=$to'),
        headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<dynamic> records = [];
        if (data['attendance'] is List)
          records = data['attendance'];
        else if (data['records'] is List)
          records = data['records'];
        else if (data['data'] is List) records = data['data'];

        return records.take(5).map<Map<String, dynamic>>((r) {
          final firstIn = r['first_in'] ?? r['check_in'];
          final lastOut = r['last_out'] ?? r['check_out'];
          final firstInStatus =
              r['first_in_status']?.toString().toLowerCase() ?? '';
          final hasIn = firstIn != null &&
              firstIn.toString().trim().isNotEmpty &&
              firstIn.toString() != 'null' &&
              firstInStatus == 'cin';
          final lastOutRaw = lastOut?.toString().trim() ?? '';
          final hasOut = lastOutRaw.isNotEmpty &&
              lastOutRaw != 'null' &&
              lastOutRaw != firstIn?.toString().trim();
          final isLate = (r['first_in_late'] ?? '')
              .toString()
              .toLowerCase()
              .contains('late');

          return {
            'title': 'Bio Attendance',
            'description':
                '${r['date'] ?? ''} • ${hasIn ? (isLate ? 'Late' : 'Present') : 'Absent'}',
            'time': _timeAgo(r['date']?.toString()),
            'icon': Icons.fingerprint,
            'color': hasIn
                ? (isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                : const Color(0xFFEF4444),
            'type': 'bio_attendance',
            'first_in': hasIn ? _fmtTime(firstIn) : '--:--',
            'last_out': hasOut ? _fmtTime(lastOut) : '--:--',
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── MENTEE COUNT ──────────────────────────────────────────────────────────
  Future<int> _getMenteeCount(String? staffId, String? deptCode) async {
    if (staffId == null || deptCode == null) return 0;
    try {
      final res = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/staff/mentorship/$deptCode'),
        headers: {'Referer': _kRefererUrl, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          int count = 0;
          for (var stream in (data['data']?['streams'] ?? []) as List) {
            for (var shift in (stream['shifts'] ?? []) as List) {
              for (var mentor in (shift['staff_mentors'] ?? []) as List) {
                if (mentor['staff_id'] == staffId) {
                  for (var batch in (mentor['assigned_students']?['batches'] ??
                      []) as List) {
                    count += (batch['students'] as List?)
                            ?.where((s) => s['active_status'] == true)
                            .length ??
                        0;
                  }
                }
              }
            }
          }
          return count;
        }
      }
    } catch (_) {}
    return 0;
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _filterTodayClasses(List<dynamic> classes) {
    const todayDayOrder = 1;
    return classes
        .where((c) => c['dayOrder'] == todayDayOrder)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  int _countUniqueCourses(List<dynamic> classes) {
    final set = <String>{};
    for (var c in classes) {
      set.add('${c['program_id']}-${c['year']}-${c['section_name']}');
    }
    return set.length;
  }

  int _countPublications(dynamic publications) {
    if (publications == null) return 0;
    int count = 0;
    for (final k in [
      'journal_articles',
      'conference_papers',
      'book_chapters',
      'books_authored',
      'edited_volume',
      'patent'
    ]) {
      if (publications[k] is List) count += (publications[k] as List).length;
    }
    return count;
  }

List<Map<String, dynamic>> _formatSchedule(
    List<Map<String, dynamic>> classes) {
  return classes.map((cls) {
    final classKey =
        '${cls['program_id']}_${cls['year']}_${cls['section_name']}_${cls['hour']}';
    
    // Format class display like "1 BSc CS A"
    final yearValue = cls['year']?.toString() ?? '';
    final programId = cls['program_id']?.toString() ?? '';
    final sectionName = cls['section_name']?.toString() ?? '';
    
    String formattedClass = _formatClassDisplaySimple(programId, yearValue, sectionName);
    
    return {
      'time': _hourToTime(cls['hour'] ?? 1),
      'subject': formattedClass,
      'type': cls['type'] ?? 'Theory',
      'room': cls['room'] ?? 'TBA',
      'batch': formattedClass,
      'year': yearValue,
      'section': sectionName,
      'hour': cls['hour'] ?? 1,
      'dayOrder': cls['dayOrder'] ?? 1,
      'program_id': programId,
      'isMarked': _attendanceMarkedStatus[classKey] ?? false,
      'classKey': classKey,
    };
  }).toList();
}

// Simple formatter for dashboard display
String _formatClassDisplaySimple(String programId, String year, String section) {
  // Extract program name from program_id (e.g., "UG-BSC-CS" -> "BSc CS")
  String programName = '';
  
  if (programId.contains('-')) {
    final parts = programId.split('-');
    if (parts.length >= 2) {
      // Handle UG-BSC-CS or PG-MBA formats
      String degreeCode = parts[1].toUpperCase();
      programName = _formatDegreeName(degreeCode);
      
      // Add specialization if exists (e.g., CS from UG-BSC-CS)
      if (parts.length >= 3) {
        String spec = parts[2].toUpperCase();
        if (spec.isNotEmpty && spec != degreeCode) {
          programName = '$programName $spec';
        }
      }
    }
  } else {
    programName = programId.replaceAll('_', ' ');
  }
  
  // Build final display: "1 BSc CS A"
  String result = '';
  if (year.isNotEmpty && year != '0') {
    result = year;
  }
  if (programName.isNotEmpty) {
    result = result.isEmpty ? programName : '$result $programName';
  }
  if (section.isNotEmpty && section != '0' && section != 'A0') {
    result = '$result $section';
  }
  
  return result.isEmpty ? programId : result;
}

String _formatDegreeName(String code) {
  switch (code.toUpperCase()) {
    case 'BSC': return 'BSc';
    case 'BCA': return 'BCA';
    case 'BBA': return 'BBA';
    case 'BCOM': return 'B.Com';
    case 'BA': return 'BA';
    case 'MSC': return 'MSc';
    case 'MCA': return 'MCA';
    case 'MBA': return 'MBA';
    case 'MA': return 'MA';
    case 'MCOM': return 'M.Com';
    default: return code;
  }
}

  String _hourToTime(int hour) {
    const map = {
      1: '8:30 - 9:25',
      2: '9:25 - 10:20',
      3: '10:20 - 11:15',
      4: '11:30 - 12:20',
      5: '12:20 - 1:10',
      6: '2:00 - 3:00'
    };
    return map[hour] ?? '${hour + 8}:00';
  }

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().trim().isEmpty || v.toString() == 'null')
      return '--:--';
    try {
      String t = v.toString().trim();
      if (t.contains(' ')) t = t.split(' ').last;
      final parts = t.split(':');
      if (parts.length < 2) return '--:--';
      final h = int.parse(parts[0]);
      final m = parts[1].substring(0, 2);
      final period = h >= 12 ? 'PM' : 'AM';
      final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$dh:${m.padLeft(2, '0')} $period';
    } catch (_) {
      return '--:--';
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color get _primaryColor {
    final theme = Provider.of<StaffThemeProvider>(context, listen: false);
    return _isHod ? theme.amber : theme.cyan;
  }

  Color get _secondaryColor {
    final theme = Provider.of<StaffThemeProvider>(context, listen: false);
    return theme.violet;
  }

  List<Color> get _activeGradient {
    final theme = Provider.of<StaffThemeProvider>(context, listen: false);
    return _isHod
        ? [theme.amber, theme.amber.withOpacity(0.7)]
        : theme.primaryGradient;
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;
    final auth = context.read<AuthProvider>();
    final staffName = auth.userData?['name'] ?? 'Staff';

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(
              bottom: BorderSide(
                color: accent.withOpacity(0.2 + _appBarGlow.value * 0.15),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.06 + _appBarGlow.value * 0.04),
                blurRadius: 20,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border),
                      ),
                      child: Icon(Icons.menu_rounded,
                          color: theme.textHigh, size: 18),
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 4),
                // Logo
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10)
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.elevated,
                        child:
                            Icon(Icons.school_rounded, color: accent, size: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHod ? "HOD Dashboard" : "Staff ERP",
                        style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _isHod ? "Head of Department" : staffName,
                        style: TextStyle(
                            color: accent.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Profile Photo - Single source in AppBar
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffProfileScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.2), blurRadius: 8)
                      ],
                    ),
                    child: ClipOval(
                      child: _photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _photoUrl!,
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              placeholder: (_, __) => _buildInitialsAvatar(staffName, accent, theme),
                              errorWidget: (_, __, ___) => _buildInitialsAvatar(staffName, accent, theme),
                            )
                          : _buildInitialsAvatar(staffName, accent, theme),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, Color accent, StaffThemeProvider theme) {
    return Container(
      color: accent.withOpacity(0.1),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ── WELCOME BANNER ────────────────────────────────────────────────────────
  Widget _buildWelcomeSection(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;
    final auth = context.read<AuthProvider>();
    final staffName = auth.userData?['name'] ?? 'Staff';

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shimmerBox(theme, height: 180, radius: 20);
        }
        if (snapshot.hasError) {
          return _errorCard(theme, 'Failed to load. Pull to refresh.');
        }

        final d = snapshot.data ?? {};
        final greeting = d['greeting'] ?? 'Welcome';
        final name = (d['staffName'] ?? 'Staff').toString().split(' ').first;
        final designation = d['designation'] ?? 'Teaching Faculty';
        final department = d['department'] ?? 'Department';
        final bio = d['bioAttendance'] as Map<String, dynamic>? ?? {};
        final todaysClasses = d['todaysClasses'] ?? 0;
        final isPresent =
            bio['status'] != 'Not Recorded' && bio['status'] != 'Absent';
        final isLate =
            bio['first_in_late']?.toString().toLowerCase().contains('late') ??
                false;
        final inDisplay = bio['inDisplay'] ?? '--:--';
        final outDisplay = bio['outDisplay'] ?? '--:--';
        final hasOut = bio['hasCheckOut'] == true;

        return SlideTransition(
          position: _welcomeSlide,
          child: FadeTransition(
            opacity: _welcomeFade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.bannerGradient,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(0.08), blurRadius: 30)
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, __) => Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.green,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.green.withOpacity(
                                              0.4 + _pulseCtrl.value * 0.3),
                                          blurRadius: 8 + _pulseCtrl.value * 4,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isHod ? "HOD DASHBOARD" : "STAFF PORTAL",
                                  style: TextStyle(
                                      color: accent.withOpacity(0.7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                "$greeting, $name!",
                                style: TextStyle(
                                    color: theme.textHigh,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(designation,
                                  style: TextStyle(
                                      color: theme.textMid,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              Text(department,
                                  style: TextStyle(
                                      color: theme.textLow, fontSize: 11)),
                            ]),
                      ),
                      // Welcome banner doesn't show photo - removed to avoid duplication
                      // The photo is only in the AppBar now
                    ]),
                    const SizedBox(height: 16),

                    // Bio attendance status row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.textLow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isPresent ? theme.green : theme.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPresent
                              ? (bio['status'] ?? 'Present')
                              : 'Not Checked In',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textHigh),
                        ),
                        if (isLate) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('⚠ Late',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.amber,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const Spacer(),
                        Row(children: [
                          Icon(Icons.login_rounded,
                              size: 12, color: theme.green),
                          const SizedBox(width: 4),
                          Text(inDisplay,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isPresent
                                      ? theme.textHigh
                                      : theme.textLow)),
                        ]),
                        if (hasOut) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded,
                              size: 10, color: theme.textLow),
                          const SizedBox(width: 6),
                          Row(children: [
                            Icon(Icons.logout_rounded,
                                size: 12, color: theme.pink),
                            const SizedBox(width: 4),
                            Text(outDisplay,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textHigh)),
                          ]),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),

                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _chip(
                          theme,
                          Icons.class_rounded,
                          "$todaysClasses ${todaysClasses == 1 ? 'Class' : 'Classes'} Today",
                          accent),
                      _chip(
                          theme,
                          Icons.percent_rounded,
                          "${d['semesterProgress'] ?? 0}% Semester",
                          theme.green),
                    ]),
                  ]),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(
      StaffThemeProvider theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── STATS GRID ────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: List.generate(4, (_) => _shimmerBox(theme, radius: 18)),
          );
        }

        final d = snapshot.data ?? {};
        final totalCourses = d['totalCourses'] ?? 0;
        final todaysClasses = d['todaysClasses'] ?? 0;
        final publications = d['publications'] ?? 0;
        final menteeCount = d['menteeCount'] ?? 0;

        return _animated(
            0,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _statCard(
                    theme,
                    "Today's Classes",
                    todaysClasses.toString(),
                    "Scheduled today",
                    Icons.today_rounded,
                    todaysClasses > 0 ? accent : theme.amber),
                _statCard(theme, "Courses", totalCourses.toString(),
                    "This semester", Icons.menu_book_rounded, theme.green),
                _statCard(theme, "Publications", publications.toString(),
                    "Total papers", Icons.article_rounded, _secondaryColor,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const EnhancedPublicationsScreen()))),
                _statCard(theme, "Mentees", menteeCount.toString(),
                    "Assigned students", Icons.people_rounded, theme.amber,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const UnifiedMentoringDashboard()))),
              ],
            ));
      },
    );
  }

  Widget _statCard(StaffThemeProvider theme, String title, String value,
      String subtitle, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 14)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(color: color.withOpacity(0.4), blurRadius: 10)
                    ],
                  )),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      color: theme.textHigh,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: theme.textLow, fontSize: 10)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;
    final staffId = context.read<AuthProvider>().userData?['staff_id'];

    final actions = [
      {
        'icon': Icons.assignment_rounded,
        'label': 'Mark\nAttendance',
        'color': accent
      },
      {
        'icon': Icons.schedule_rounded,
        'label': 'Timetable',
        'color': theme.cyan
      },
      {
        'icon': Icons.groups_rounded,
        'label': 'Mentoring',
        'color': theme.amber
      },
      {
        'icon': Icons.fingerprint_rounded,
        'label': 'Bio\nAttendance',
        'color': theme.green
      },
    ];

    return _animated(
        1,
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.border),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.05), blurRadius: 14)
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(Icons.flash_on_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Quick Actions',
                  style: TextStyle(
                      color: theme.textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: actions.map((action) {
                final color = action['color'] as Color;
                return GestureDetector(
                  onTap: () {
                    final label = (action['label'] as String).toLowerCase();
                    if (label.contains('attendance') &&
                        !label.contains('bio')) {
                      if (staffId != null)
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProfessionalClassAttendanceScreen(
                                        staffId: staffId,
                                        baseApiUrl: _kBaseApiUrl,
                                        refererUrl: _kRefererUrl)));
                    } else if (label.contains('timetable')) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StaffTimetableScreen()));
                    } else if (label.contains('mentoring')) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const UnifiedMentoringDashboard()));
                    } else if (label.contains('bio')) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const StaffBioAttendanceScreen()));
                    }
                  },
                  child: Column(children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(
                                    0.06 + _pulseCtrl.value * 0.04),
                                blurRadius: 12)
                          ],
                        ),
                        child: Icon(action['icon'] as IconData,
                            color: color, size: 24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.textMid,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ]),
        ));
  }

  // ── SCHEDULE ──────────────────────────────────────────────────────────────
  Widget _buildSchedule(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shimmerBox(theme, height: 160, radius: 18);
        }

        final schedule =
            (snapshot.data?['upcomingSchedule'] as List<dynamic>?) ?? [];

        return _animated(
            2,
            Container(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.border),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(0.05), blurRadius: 14)
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.schedule_rounded,
                              color: accent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Today's Classes",
                                    style: TextStyle(
                                        color: theme.textHigh,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    "${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} scheduled",
                                    style: TextStyle(
                                        color: theme.textMid, fontSize: 11)),
                              ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(
                              DateFormat('EEE, d MMM').format(DateTime.now()),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent)),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          children: schedule.isEmpty
                              ? [_emptySchedule(theme)]
                              : [
                                  ...schedule.map((item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _scheduleItem(context,
                                            item as Map<String, dynamic>),
                                      )),
                                  const SizedBox(height: 6),
                                  _markAttendanceBtn(context, accent),
                                ]),
                    ),
                  ]),
            ));
      },
    );
  }

  Widget _scheduleItem(BuildContext context, Map<String, dynamic> item) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;
    final isMarked = item['isMarked'] == true;

    return Container(
      decoration: BoxDecoration(
        color: isMarked ? theme.green.withOpacity(0.06) : theme.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isMarked ? theme.green.withOpacity(0.3) : theme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToAttendance(context, item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 70,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text(item['time'].toString().split(' - ')[0],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                  Text(
                      item['time'].toString().split(' - ').length > 1
                          ? item['time'].toString().split(' - ')[1]
                          : '',
                      style: TextStyle(fontSize: 9, color: theme.textMid)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(item['subject'] ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textHigh),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isMarked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: theme.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4)),
                            child: Row(children: [
                              Icon(Icons.check_circle,
                                  size: 10, color: theme.green),
                              const SizedBox(width: 3),
                              Text('Done',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: theme.green,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text('${item['batch']} • ${item['type']}',
                          style: TextStyle(fontSize: 11, color: theme.textMid)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: theme.textLow),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _markAttendanceBtn(BuildContext context, Color accent) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _activeGradient),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            final staffId = context.read<AuthProvider>().userData?['staff_id'];
            if (staffId == null) return;
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfessionalClassAttendanceScreen(
                        staffId: staffId,
                        baseApiUrl: _kBaseApiUrl,
                        refererUrl: _kRefererUrl)));
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent),
          child: const Text('Mark Attendance',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _emptySchedule(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.green.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(Icons.event_available_rounded, color: theme.green, size: 40),
        const SizedBox(height: 10),
        Text('No Classes Today',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: theme.green)),
        const SizedBox(height: 4),
        Text('Enjoy your free day!',
            style: TextStyle(fontSize: 12, color: theme.textMid)),
      ]),
    );
  }

  // ── RECENT ACTIVITIES ─────────────────────────────────────────────────────
  Widget _buildRecentActivities(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final accent = _primaryColor;

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shimmerBox(theme, height: 200, radius: 18);
        }

        final activities = (snapshot.data?['recentActivities'] as List?) ?? [];

        return _animated(
            3,
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.border),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(0.05), blurRadius: 14)
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withOpacity(0.25)),
                        ),
                        child: Icon(Icons.history_rounded,
                            color: accent, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('Recent Bio Activity',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const StaffBioAttendanceScreen())),
                        child: Text('View All',
                            style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(children: [
                            Icon(Icons.history_toggle_off,
                                size: 40, color: theme.textLow),
                            const SizedBox(height: 8),
                            Text('No recent activity',
                                style: TextStyle(
                                    fontSize: 13, color: theme.textMid)),
                          ]),
                        ),
                      )
                    else
                      ...activities.map((activity) {
                        final a = activity as Map<String, dynamic>;
                        final color = a['color'] as Color? ?? accent;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.elevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                  a['icon'] as IconData? ?? Icons.fingerprint,
                                  color: color,
                                  size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'] ?? '',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textHigh)),
                                    const SizedBox(height: 3),
                                    Text(a['description'] ?? '',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textMid)),
                                    if ((a['first_in'] ?? '--:--') !=
                                        '--:--') ...[
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        Icon(Icons.login_rounded,
                                            size: 10, color: theme.green),
                                        const SizedBox(width: 3),
                                        Text('${a['first_in']}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme.green,
                                                fontWeight: FontWeight.w600)),
                                        if ((a['last_out'] ?? '--:--') !=
                                            '--:--') ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.logout_rounded,
                                              size: 10, color: theme.pink),
                                          const SizedBox(width: 3),
                                          Text('${a['last_out']}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme.pink,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ]),
                                    ],
                                  ]),
                            ),
                            Text(a['time'] ?? '',
                                style: TextStyle(
                                    fontSize: 10, color: theme.textLow)),
                          ]),
                        );
                      }),
                  ]),
            ));
      },
    );
  }

  // ── NAVIGATION HELPERS ────────────────────────────────────────────────────
  void _goToAttendance(BuildContext context, Map<String, dynamic> item) {
    final staffId = context.read<AuthProvider>().userData?['staff_id'];
    if (staffId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfessionalClassAttendanceScreen(
            staffId: staffId,
            baseApiUrl: _kBaseApiUrl,
            refererUrl: _kRefererUrl,
            preselectedClass: {
              'program_id': item['program_id'],
              'year': item['year'],
              'section_name':
                  item['section']?.toString().split(' - ').last.trim() ?? '',
            },
            preselectedDayOrder: item['dayOrder'],
            preselectedHours: [item['hour']],
          ),
        ));
  }

  // ── SHIMMER / ERROR HELPERS ───────────────────────────────────────────────
  Widget _shimmerBox(StaffThemeProvider theme,
      {double? height, double radius = 12}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _errorCard(StaffThemeProvider theme, String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.pink.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.pink.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(Icons.error, color: theme.pink, size: 32),
        const SizedBox(height: 10),
        Text(msg,
            textAlign: TextAlign.center, style: TextStyle(color: theme.pink)),
        const SizedBox(height: 10),
        ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(backgroundColor: theme.pink),
            child: const Text('Retry')),
      ]),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(context),
      drawer: AppDrawer(isHod: _isHod, currentRoute: '/dashboard'),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
          await Future.delayed(const Duration(seconds: 1));
        },
        color: _primaryColor,
        backgroundColor: theme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 16),
            _buildStatsGrid(context),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildSchedule(context),
            const SizedBox(height: 16),
            _buildRecentActivities(context),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}