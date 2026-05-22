import 'dart:ui' as ui;

import 'package:bhc_erp/Student/screens/academic_calendar.dart';
import 'package:bhc_erp/login/screens/unified_login_screen.dart';
import 'package:bhc_erp/Student/screens/EndSemExamResult.dart';
import 'package:bhc_erp/Student/screens/attendance_screen.dart';
import 'package:bhc_erp/Student/screens/manage_leaves.dart';
import 'package:bhc_erp/Student/screens/mentor_screen.dart';
import 'package:bhc_erp/Student/screens/seating_arangements.dart';
import 'package:bhc_erp/Student/screens/subjects.dart';
import 'package:bhc_erp/Student/screens/time_table.dart';
import 'package:bhc_erp/Student/services/photo_service.dart';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:bhc_erp/Student/widgets/student_photo_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as CacheService;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_info.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseApiUrl = 'https://apierp.bhc.edu.in';
const String refererUrl = 'http://117.232.64.75';

// In-memory profile cache to avoid duplicate API calls
Map<String, dynamic>? _cachedProfile;
String? _cachedProfileRoll;

// _C is now handled dynamically via ThemeProvider in build methods

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? rollNo = prefs.getString('rollNo');
  String? studentName = prefs.getString('studentName');
  String? dob = prefs.getString('dob');
  runApp(MyApp(rollNo: rollNo, studentName: studentName, dob: dob));
}

class MyApp extends StatelessWidget {
  final String? rollNo;
  final String? studentName;
  final String? dob;
  const MyApp({super.key, this.rollNo, this.studentName, this.dob});

  @override
  Widget build(BuildContext context) {
    // ThemeProvider is registered in the root MultiProvider (main.dart).
    // We just return the page directly — no nested MaterialApp needed.
    if (rollNo != null && studentName != null && dob != null) {
      return MainPage(rollNo: rollNo!, studentName: studentName!);
    }
    return const UnifiedLoginScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class MainPage extends StatefulWidget {
  final String rollNo;
  final String studentName;
  const MainPage({super.key, required this.rollNo, required this.studentName});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  late Future<String?> _photoFuture;
  late Future<Map<String, dynamic>> _drawerDataFuture;
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  late Future<Map<String, dynamic>> _calendarDataFuture;

  late AnimationController _appBarGlow;

  @override
  void initState() {
    super.initState();
    PhotoService.setCurrentStudent(widget.rollNo);
    _appBarGlow =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _photoFuture = PhotoService.getCachedPhotoUrl();
    _calendarDataFuture = _fetchAcademicCalendar();
    // Both dashboard and drawer share the same calendar future;
    // profile is cached internally so only one HTTP call is made.
    _drawerDataFuture = _fetchDashboardDataForDrawer();
    _dashboardDataFuture = _fetchDashboardData();
    _cacheStudentPhoto();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    super.dispose();
  }

// Fix _refreshPhoto - convert to async to match CustomDrawer signature
  Future<void> _refreshPhoto() async {
    await PhotoService.clearCachedPhoto();
    await PhotoService.cacheStudentPhoto(widget.rollNo);
    if (mounted) {
      final photoFuture = PhotoService.getCachedPhotoUrl();
      setState(() {
        _photoFuture = photoFuture;
      });
    }
  }

// Also update _cacheStudentPhoto to NOT call setState
  Future<void> _cacheStudentPhoto() async {
    await PhotoService.cacheStudentPhoto(widget.rollNo);
    if (mounted) {
      // ✅ Resolve the future OUTSIDE setState first
      final photoFuture = PhotoService.getCachedPhotoUrl();
      setState(() {
        _photoFuture =
            photoFuture; // ← Now this is just a variable assignment, no async
      });
    }
  }

  Future<Map<String, dynamic>> _fetchAcademicCalendar() async {
    try {
      final currentYear = DateTime.now().year;
      final nextYear = currentYear + 1;
      final academicYear = '$currentYear-$nextYear';
      final url = Uri.parse(
        "$baseApiUrl/api/academic_calendar/$academicYear",
      );
      final response = await http.get(
        url,
        headers: {
          'Referer': refererUrl,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null)
          return data['data'];
      }
      return {};
    } catch (e) {
      debugPrint('Error fetching academic calendar: $e');
      return {};
    }
  }

  Map<String, dynamic> _calculateCurrentSemesterInfo(
    Map<String, dynamic> calendarData,
  ) {
    final now = DateTime.now();
    if (calendarData.isEmpty) {
      final month = now.month;
      final isOddSemester = month >= 6 && month <= 11;
      return {
        'semester': isOddSemester ? 1 : 2,
        'semesterName': isOddSemester ? 'Odd Semester' : 'Even Semester',
        'startDate': isOddSemester
            ? DateTime(now.year, 6, 1)
            : DateTime(now.year, 12, 1),
        'endDate': isOddSemester
            ? DateTime(now.year, 11, 30)
            : DateTime(now.year + 1, 5, 31),
        'isCurrent': true,
      };
    }
    final oddSemester = calendarData['sem_odd'];
    if (oddSemester != null &&
        oddSemester['startDate'] != null &&
        oddSemester['endDate'] != null) {
      final oddStart = DateTime.parse(oddSemester['startDate']);
      final oddEnd = DateTime.parse(oddSemester['endDate']);
      if (now.isAfter(oddStart.subtract(const Duration(days: 1))) &&
          now.isBefore(oddEnd.add(const Duration(days: 1)))) {
        return {
          'semester': 1,
          'semesterName': 'Odd Semester',
          'startDate': oddStart,
          'endDate': oddEnd,
          'isCurrent': true,
          'semesterData': oddSemester,
        };
      }
    }
    final evenSemester = calendarData['sem_even'];
    if (evenSemester != null &&
        evenSemester['startDate'] != null &&
        evenSemester['endDate'] != null) {
      final evenStart = DateTime.parse(evenSemester['startDate']);
      final evenEnd = DateTime.parse(evenSemester['endDate']);
      if (now.isAfter(evenStart.subtract(const Duration(days: 1))) &&
          now.isBefore(evenEnd.add(const Duration(days: 1)))) {
        return {
          'semester': 2,
          'semesterName': 'Even Semester',
          'startDate': evenStart,
          'endDate': evenEnd,
          'isCurrent': true,
          'semesterData': evenSemester,
        };
      }
    }
    final month = now.month;
    final isOddSemester = month >= 6 && month <= 11;
    return {
      'semester': isOddSemester ? 1 : 2,
      'semesterName': isOddSemester ? 'Odd Semester' : 'Even Semester',
      'startDate':
          isOddSemester ? DateTime(now.year, 6, 1) : DateTime(now.year, 12, 1),
      'endDate': isOddSemester
          ? DateTime(now.year, 11, 30)
          : DateTime(now.year + 1, 5, 31),
      'isCurrent': true,
    };
  }

  int _calculateWeeksCompleted(Map<String, dynamic> semesterInfo) {
    try {
      final startDate = semesterInfo['startDate'] as DateTime;
      final today = DateTime.now();
      if (today.isBefore(startDate)) return 0;
      return ((today.difference(startDate).inDays) / 7).floor().clamp(0, 26);
    } catch (e) {
      return 0;
    }
  }

  int _calculateTotalWeeks(Map<String, dynamic> semesterInfo) {
    try {
      final startDate = semesterInfo['startDate'] as DateTime;
      final endDate = semesterInfo['endDate'] as DateTime;
      return ((endDate.difference(startDate).inDays) / 7).ceil().clamp(1, 26);
    } catch (e) {
      return 16;
    }
  }

  int _calculateCurrentDayOrder(Map<String, dynamic> semesterInfo) {
    try {
      final semesterData = semesterInfo['semesterData'];
      if (semesterData == null || !semesterInfo['isCurrent']) return 0;
      final startDate = semesterInfo['startDate'] as DateTime;
      final today = DateTime.now();
      if (today.isBefore(startDate)) return 0;
      final nonWorkingDays = _getAllNonWorkingDays(semesterData);
      int workingDayCount = 0;
      DateTime currentDay = startDate;
      while (currentDay.isBefore(today) || currentDay.isAtSameMomentAs(today)) {
        if (_isWorkingDay(currentDay, nonWorkingDays)) workingDayCount++;
        currentDay = currentDay.add(const Duration(days: 1));
      }
      return workingDayCount > 0 ? ((workingDayCount - 1) % 5) + 1 : 0;
    } catch (e) {
      return 0;
    }
  }

  bool _isWorkingDay(DateTime date, Set<String> nonWorkingDays) {
    if (date.weekday == 6 || date.weekday == 7) return false;
    return !nonWorkingDays.contains(_formatDateForComparison(date));
  }

  Set<String> _getAllNonWorkingDays(Map<String, dynamic> semesterData) {
    Set<String> nonWorkingDays = {};
    final holidays = semesterData['holidays'] as List<dynamic>? ?? [];
    for (final holiday in holidays) {
      try {
        final startDate = DateTime.parse(holiday['startDate']);
        final endDate = DateTime.parse(holiday['endDate']);
        DateTime current = startDate;
        while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
          nonWorkingDays.add(_formatDateForComparison(current));
          current = current.add(const Duration(days: 1));
        }
      } catch (e) {}
    }
    final exams = semesterData['exams'] as Map<String, dynamic>? ?? {};
    exams.forEach((key, examData) {
      if (examData != null) {
        try {
          final startDate = DateTime.parse(examData['startDate']);
          final endDate = DateTime.parse(examData['endDate']);
          DateTime current = startDate;
          while (
              current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
            nonWorkingDays.add(_formatDateForComparison(current));
            current = current.add(const Duration(days: 1));
          }
        } catch (e) {}
      }
    });
    return nonWorkingDays;
  }

  String _formatDateForComparison(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _fetchTodayAttendance() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = Uri.parse(
        "$baseApiUrl/api/students/attendance/${widget.rollNo}",
      );
      final response = await http.get(
        url,
        headers: {
          'Referer': refererUrl,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final attendance = body['attendance'] as List<dynamic>? ?? [];
      for (final yearItem in attendance) {
        for (final semKey in ['sem_even', 'sem_odd']) {
          final semList = yearItem[semKey] as List<dynamic>? ?? [];
          for (final dayObj in semList) {
            if (dayObj is Map && dayObj.containsKey(today)) {
              final info = dayObj[today] as Map<String, dynamic>;
              final hours = info['hours'] as List<dynamic>? ?? [];
              return hours.map((h) => Map<String, dynamic>.from(h)).toList();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching today attendance: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    try {
      // Run all independent fetches in parallel
      final results = await Future.wait([
        _calendarDataFuture, // already cached future
        _fetchStudentProfile(),
        _fetchExamResults(),
        _fetchAttendanceData(),
        _fetchTodayAttendance(),
      ]);

      final calendarData = results[0] as Map<String, dynamic>;
      final studentProfile = results[1] as Map<String, dynamic>;
      final examResults = results[2] as List<ExamResult>;
      final attendanceData = results[3] as Map<String, dynamic>;
      final todayAttendance = results[4] as List<Map<String, dynamic>>;
      final currentSemesterNumber = calendarData.isNotEmpty
          ? _calculateFallbackSemester(calendarData) // trust calendar first
          : _calculateCurrentSemesterNumber(studentProfile, calendarData);
      final semesterInfo = _calculateCurrentSemesterInfo(calendarData);
      final weeksCompleted = _calculateWeeksCompleted(semesterInfo);
      final totalWeeks = _calculateTotalWeeks(semesterInfo);
      final dayOrder = _calculateCurrentDayOrder(semesterInfo);
      final attendancePercentage = await _calculateCurrentSemesterAttendance(
          attendanceData, calendarData, currentSemesterNumber);
      final currentSemesterCourses =
          await _getCurrentSemesterCourses(examResults, currentSemesterNumber);

      return {
        'examResults': examResults,
        'attendanceData': attendanceData,
        'attendancePercentage': attendancePercentage,
        'currentSemester': currentSemesterNumber,
        'currentSemesterName': semesterInfo['semesterName'],
        'weeksCompleted': weeksCompleted,
        'totalWeeks': totalWeeks,
        'dayOrder': dayOrder,
        'isCurrentSemester': semesterInfo['isCurrent'] ?? true,
        'currentSemesterCourses': currentSemesterCourses,
        'todayAttendance': todayAttendance,
        'calendarData': calendarData,
      };
    } catch (e) {
      debugPrint('Error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchDashboardDataForDrawer() async {
    try {
      // Run in parallel
      final results = await Future.wait([
        _calendarDataFuture,
        _fetchStudentProfile(),
        _fetchExamResults(),
        _fetchAttendanceData(),
      ]);

      final calendarData = results[0] as Map<String, dynamic>;
      final studentProfile = results[1] as Map<String, dynamic>;
      final examResults = results[2] as List<ExamResult>;
      final attendanceData = results[3] as Map<String, dynamic>;

      final currentSemesterNumber =
          _calculateCurrentSemesterNumber(studentProfile, calendarData);
      final semesterInfo = _calculateCurrentSemesterInfo(calendarData);
      final currentCGPA = _calculateCurrentCGPA(examResults);
      double attendancePercentage = _calculateSimpleAttendance(attendanceData);
      if (attendancePercentage == 0.0) {
        // Try the fuller calculation as fallback
        attendancePercentage = await _calculateCurrentSemesterAttendance(
            attendanceData, calendarData, currentSemesterNumber);
      }

// Also add to returned map for debugging:
      debugPrint(
          'Drawer: sem=$currentSemesterNumber att=$attendancePercentage');
      final currentSemesterCourses =
          await _getCurrentSemesterCourses(examResults, currentSemesterNumber);

      return {
        'currentSemester': currentSemesterNumber,
        'currentSemesterName': semesterInfo['semesterName'],
        'weeksCompleted': _calculateWeeksCompleted(semesterInfo),
        'totalWeeks': _calculateTotalWeeks(semesterInfo),
        'dayOrder': _calculateCurrentDayOrder(semesterInfo),
        'currentSemesterCourses': currentSemesterCourses,
        'currentCGPA': currentCGPA,
        'attendancePercentage': attendancePercentage,
        'isCurrentSemester': semesterInfo['isCurrent'] ?? true,
        'usingFallback':
            studentProfile.isEmpty || studentProfile['data'] == null,
      };
    } catch (e) {
      return {
        'currentSemester': 1,
        'currentSemesterName': 'Odd Semester',
        'weeksCompleted': 0,
        'totalWeeks': 16,
        'dayOrder': 0,
        'currentSemesterCourses': 6,
        'currentCGPA': 0.0,
        'attendancePercentage': 0.0,
        'isCurrentSemester': true,
        'usingFallback': true,
      };
    }
  }

  Future<Map<String, dynamic>> _fetchStudentProfile() async {
    if (_cachedProfileRoll == widget.rollNo && _cachedProfile != null) {
      return _cachedProfile!;
    }
    try {
      final url = Uri.parse("$baseApiUrl/api/students/${widget.rollNo}");
      final response = await http.get(url, headers: {
        'Referer': refererUrl,
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedProfile = data;
        _cachedProfileRoll = widget.rollNo;
        return data;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

int _calculateCurrentSemesterNumber(
  Map<String, dynamic> studentProfile,
  Map<String, dynamic> calendarData,
) => _calculateFallbackSemester(calendarData); 

// {
//     try {
//       if (studentProfile.isEmpty)
//         return _calculateFallbackSemester(calendarData);
//       final studentData = studentProfile['data'];
//       if (studentData == null) return _calculateFallbackSemester(calendarData);
//       final admissionDateStr = studentData['admission_date'];
//       final batch = studentData['batch'] as String?;
//       final currentAcademic =
//           studentData['current_academic'] as Map<String, dynamic>?;
//       final degreeType = currentAcademic?['degree_type'] as String?;
//       DateTime admissionDate;
//       if (admissionDateStr != null) {
//         admissionDate = DateTime.parse(admissionDateStr);
//       } else if (batch != null) {
//         final startYear =
//             int.tryParse(batch.split('-').first) ?? DateTime.now().year;
//         admissionDate = DateTime(startYear, 6, 1);
//       } else {
//         return _calculateFallbackSemester(calendarData);
//       }
//       final semesterInfo = _calculateCurrentSemesterInfo(calendarData);
//       final currentSemesterStart = semesterInfo['startDate'] as DateTime;
//       final monthsDifference =
//           (currentSemesterStart.year - admissionDate.year) * 12 +
//               (currentSemesterStart.month - admissionDate.month);
//       int currentSemester;
//       if (monthsDifference < 6)
//         currentSemester = 1;
//       else if (monthsDifference < 12)
//         currentSemester = 2;
//       else if (monthsDifference < 18)
//         currentSemester = 3;
//       else if (monthsDifference < 24)
//         currentSemester = 4;
//       else if (monthsDifference < 30)
//         currentSemester = 5;
//       else
//         currentSemester = 6;
//       final totalProgramSemesters = degreeType == 'PG' ? 4 : 6;
//       return currentSemester.clamp(1, totalProgramSemesters);
//     } catch (e) {
//       return _calculateFallbackSemester(calendarData);
//     }
//   }



  int _calculateFallbackSemester(Map<String, dynamic> calendarData) {
    final info = _calculateCurrentSemesterInfo(calendarData);
    // 'semester' key is 1=odd, 2=even — correct
    return info['semester'] as int;
  }

  Future<int> _fetchCurrentSemesterCoursesCount() async {
    try {
      final studentProfile = await _fetchStudentProfile();
      if (studentProfile.isEmpty) return 6;
      final studentData = studentProfile['data'];
      if (studentData == null) return 6;
      final currentAcademic =
          studentData['current_academic'] as Map<String, dynamic>?;
      final programName = currentAcademic?['degree_name'] as String? ?? '';
      final section = currentAcademic?['section'] as String? ?? 'A';
      final batch = studentData['batch'] as String? ?? '';

      String getAcademicYear(String batchRange) {
        if (batchRange.isEmpty) return "1";
        final parts = batchRange.split('-');
        if (parts.length != 2) return "1";
        final startYear = int.tryParse(parts[0]) ?? DateTime.now().year;
        final now = DateTime.now();
        int diff = now.year - startYear;
        if (now.month < 6)
          diff = diff; // even sem, same year count
        else
          diff += 1; // odd sem start, next year
        // For API: year 1 = first academic year, year 2 = second, etc.
        final academicYear = ((diff + 1) / 2).ceil().clamp(1, 4);
        return academicYear.toString();
      }

      final year = getAcademicYear(batch);
      final url = Uri.parse('$baseApiUrl/api/students/subjects/');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Referer': refererUrl,
            },
            body: json.encode({
              'program_name': programName,
              'year': year,
              'section_name': section,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final subjects = data['data']['subjects'] as List<dynamic>?;
          return subjects?.length ?? 6;
        }
      }
      return 6;
    } catch (e) {
      debugPrint('Error fetching courses count: $e');
      return 6;
    }
  }

  Future<int> _getCurrentSemesterCourses(
    List<ExamResult> examResults,
    int currentSemester,
  ) async {
    try {
      return await _fetchCurrentSemesterCoursesCount();
    } catch (e) {
      if (examResults.isEmpty) return 6;
      final previousSemester = currentSemester - 1;
      final previousCourses = examResults
          .where((result) => result.semester == previousSemester)
          .length;
      return previousCourses > 0 ? previousCourses : 6;
    }
  }

  Future<List<ExamResult>> _fetchExamResults() async {
    try {
      final response = await http.get(
        Uri.parse('$baseApiUrl/api/students/exams/ese/${widget.rollNo}'),
        headers: {"Referer": refererUrl, "Accept": "application/json"},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data =
            ExamResultsResponse.fromJson(json.decode(response.body)).data;
        return data;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    try {
      final response = await http.get(
        Uri.parse("$baseApiUrl/api/students/attendance/${widget.rollNo}"),
        headers: {'Referer': refererUrl, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<double> _calculateCurrentSemesterAttendance(
    Map<String, dynamic> attendanceData,
    Map<String, dynamic> calendarData,
    int currentSemester,
  ) async {
    try {
      // Your API: { attendance: [ { sem_even: [...], sem_odd: [...] } ] }
      List<dynamic> yearList = [];
      if (attendanceData['attendance'] is List) {
        yearList = attendanceData['attendance'] as List;
      } else if (attendanceData['data'] is List) {
        final d = (attendanceData['data'] as List);
        if (d.isNotEmpty && d[0]['attendance'] is Map) {
          // Shape B — wrap in list so loop below works
          yearList = [d[0]['attendance']];
        }
      }
      if (yearList.isEmpty) return 0.0;

      final semKey = currentSemester == 1 ? 'sem_odd' : 'sem_even';
      List<dynamic> records = [];
      for (final item in yearList) {
        if (item[semKey] is List && (item[semKey] as List).isNotEmpty) {
          records = item[semKey] as List;
          break;
        }
      }
      // Fallback: try other semester
      if (records.isEmpty) {
        final fallback = currentSemester == 1 ? 'sem_even' : 'sem_odd';
        for (final item in yearList) {
          if (item[fallback] is List && (item[fallback] as List).isNotEmpty) {
            records = item[fallback] as List;
            break;
          }
        }
      }
      if (records.isEmpty) return 0.0;

      double totalAbsent = 0.0;
      int totalDays = 0;
      for (final dayObj in records) {
        if (dayObj is! Map<String, dynamic>) continue;
        dayObj.forEach((_, info) {
          if (info is! Map<String, dynamic>) return;
          final hours = info['hours'] as List? ?? [];
          if (hours.isEmpty) return;
          totalDays++;
          final present = hours
              .where((h) => h['status']?.toString().toLowerCase() == 'present')
              .length;
          final absent = hours.length - present;
          if (absent >= 3)
            totalAbsent += 1.0;
          else if (absent >= 1) totalAbsent += 0.5;
        });
      }
      return totalDays > 0
          ? ((totalDays - totalAbsent) / totalDays) * 100
          : 0.0;
    } catch (e) {
      debugPrint('Attendance calc error: $e');
      return 0.0;
    }
  }

  double _calculateSimpleAttendance(Map<String, dynamic> attendanceData) {
    try {
      // Support both response shapes:
      // Shape A: { attendance: [ {sem_even: [...]} ] }  ← direct API
      // Shape B: { success: true, data: [ { attendance: {...} } ] }
      Map<String, dynamic>? attendance;

      if (attendanceData['attendance'] is List) {
        // Shape A — top-level attendance list
        final list = attendanceData['attendance'] as List;
        if (list.isEmpty) return 0.0;
        // Each item may have sem_even/sem_odd directly
        return _computeAttendanceFromList(list);
      } else if (attendanceData['success'] == true &&
          attendanceData['data'] is List) {
        // Shape B
        final dataList = attendanceData['data'] as List;
        if (dataList.isEmpty) return 0.0;
        final att = dataList[0]['attendance'];
        if (att is Map<String, dynamic>) {
          return _computeAttendanceFromMap(att);
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

// For shape A: list of year objects with sem_even/sem_odd
  double _computeAttendanceFromList(List list) {
    double totalAbsent = 0.0;
    int totalDays = 0;
    for (final yearItem in list) {
      for (final semKey in ['sem_even', 'sem_odd']) {
        final semList = yearItem[semKey] as List? ?? [];
        for (final dayObj in semList) {
          if (dayObj is! Map<String, dynamic>) continue;
          dayObj.forEach((dateKey, dayData) {
            if (dayData is! Map<String, dynamic>) return;
            final hours = dayData['hours'] as List? ?? [];
            if (hours.isEmpty) return;
            totalDays++;
            final present = hours
                .where(
                    (h) => h['status']?.toString().toLowerCase() == 'present')
                .length;
            final absent = hours.length - present;
            if (absent >= 3)
              totalAbsent += 1.0;
            else if (absent >= 1) totalAbsent += 0.5;
          });
        }
      }
    }
    return totalDays > 0 ? ((totalDays - totalAbsent) / totalDays) * 100 : 0.0;
  }

// For shape B: map with sem_even/sem_odd lists
  double _computeAttendanceFromMap(Map<String, dynamic> attendance) {
    double totalAbsent = 0.0;
    int totalDays = 0;
    for (final semKey in ['sem_even', 'sem_odd']) {
      final semList = attendance[semKey] as List? ?? [];
      for (final dayObj in semList) {
        if (dayObj is! Map<String, dynamic>) continue;
        dayObj.forEach((_, dayData) {
          if (dayData is! Map) return;
          final hours = (dayData as Map)['hours'] as List? ?? [];
          if (hours.isEmpty) return;
          totalDays++;
          final present = hours
              .where((h) => h['status']?.toString().toLowerCase() == 'present')
              .length;
          final absent = hours.length - present;
          if (absent >= 3)
            totalAbsent += 1.0;
          else if (absent >= 1) totalAbsent += 0.5;
        });
      }
    }
    return totalDays > 0 ? ((totalDays - totalAbsent) / totalDays) * 100 : 0.0;
  }

  double _calculateCurrentCGPA(List<ExamResult> examResults) {
    if (examResults.isEmpty) return 0.0;
    double totalGradePoints = 0.0;
    int totalCredits = 0;
    for (var result in examResults) {
      if (result.result == 'PASS' && result.gradePoint > 0) {
        totalGradePoints += result.gradePoint * result.credit;
        totalCredits += result.credit;
      }
    }
    return totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;
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
      '8th',
    ];
    return semester < suffixes.length ? suffixes[semester] : '${semester}th';
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  // In _MainPageState - add state variables
  Map<String, dynamic>? _cachedDashboardData;

  @override
  Widget build(BuildContext context) {
    final _C = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildFuturisticAppBar(),
      drawer: _buildDrawer(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          // Use cached data if available (fixes back navigation issue)
          if (snapshot.hasData) {
            _cachedDashboardData = snapshot.data;
          }
          final data = _cachedDashboardData;

          if (snapshot.connectionState == ConnectionState.waiting &&
              data == null) {
            return _buildLoadingState();
          }
          if (data != null) {
            return FuturisticDashboard(
              studentName: widget.studentName,
              rollNo: widget.rollNo,
              attendancePercentage:
                  data['attendancePercentage'] as double? ?? 0.0,
              currentSemester: data['currentSemester'] as int? ?? 1,
              currentSemesterName:
                  data['currentSemesterName'] as String? ?? 'Semester',
              weeksCompleted: data['weeksCompleted'] as int? ?? 0,
              totalWeeks: data['totalWeeks'] as int? ?? 16,
              dayOrder: data['dayOrder'] as int? ?? 0,
              isCurrentSemester: data['isCurrentSemester'] as bool? ?? true,
              currentSemesterCourses:
                  data['currentSemesterCourses'] as int? ?? 6,
              examResults: data['examResults'] as List<ExamResult>? ?? [],
              todayAttendance:
                  data['todayAttendance'] as List<Map<String, dynamic>>? ?? [],
              calendarData: data['calendarData'] as Map<String, dynamic>? ?? {},
            );
          }
          return _buildErrorState('No data available');
        },
      ),
    );
  }

  PreferredSizeWidget _buildFuturisticAppBar() {
    final _C = Provider.of<ThemeProvider>(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: _C.surface,
              border: Border(
                bottom: BorderSide(
                  color: _C.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Menu button
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _C.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _C.border),
                        ),
                        child: Icon(Icons.menu_rounded,
                            color: _C.textHigh, size: 18),
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Logo + Title
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _C.cyan.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/bhclogo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _C.elevated,
                          child: Icon(
                            Icons.school_rounded,
                            color: _C.cyan,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Heber ERP",
                        style: TextStyle(
                          color: _C.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "Student Portal",
                        style: TextStyle(
                          color: _C.cyan.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _C.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.green,
                            boxShadow: [
                              BoxShadow(
                                color: _C.green.withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "LIVE",
                          style: TextStyle(
                            color: _C.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Profile photo → tap shows animated bubble overlay
                  GestureDetector(
                    onTap: () => _showProfileBubble(context, _C),
                    child: StudentPhotoWidget(
                      rollNo: widget.rollNo,
                      size: 34,
                      borderColor: _C.cyan,
                      showRing: false,
                      showGlow: false,
                      show3DEffect: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProfileBubble(BuildContext context, ThemeProvider _C) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _ProfileBubbleOverlay(
              rollNo: widget.rollNo,
              studentName: widget.studentName,
              photoFuture: _photoFuture,
              screenWidth: size.width,
              onClose: () => entry.remove(),
            ));
    overlay.insert(entry);
  }

  Widget _buildLoadingState() {
    final _C = Provider.of<ThemeProvider>(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_C.cyan),
              backgroundColor: _C.cyan.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading dashboard...",
            style: TextStyle(
              color: _C.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Syncing your data",
            style: TextStyle(color: _C.textLow, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final _C = Provider.of<ThemeProvider>(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.pink.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _C.pink.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: _C.pink,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Connection Error",
              style: TextStyle(
                color: _C.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Could not load dashboard data.\nCheck your internet connection.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textMid, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DRAWER ──────────────────────────────────────────────────────────────

// In _MainPageState._buildDrawer()
  Widget _buildDrawer() {
    return CustomDrawer(
      rollNo: widget.rollNo,
      studentName: widget.studentName,
      currentRoute: '/dashboard',
      fetchDrawerData: () => _drawerDataFuture, // return cached future!
      getPhotoFuture: () => _photoFuture,
      onRefreshPhoto: _refreshPhoto,
    );
  }

  Widget _buildDrawerHeader() {
    final _C = Provider.of<ThemeProvider>(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _drawerDataFuture,
      builder: (context, snapshot) {
        final semester =
            snapshot.hasData ? snapshot.data!['currentSemester'] ?? 1 : 1;
        final semesterName = snapshot.hasData
            ? snapshot.data!['currentSemesterName'] ?? 'Semester'
            : 'Semester';
        final weeksCompleted =
            snapshot.hasData ? snapshot.data!['weeksCompleted'] ?? 0 : 0;
        final totalWeeks =
            snapshot.hasData ? snapshot.data!['totalWeeks'] ?? 16 : 16;
        final courses = snapshot.hasData
            ? snapshot.data!['currentSemesterCourses'] ?? 6
            : 6;
        final attendancePercentage = snapshot.hasData
            ? snapshot.data!['attendancePercentage'] ?? 0.0
            : 0.0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_C.elevated, _C.elevated2],
            ),
            border: Border(
              bottom: BorderSide(color: _C.border, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  FutureBuilder<String?>(
                    future: _photoFuture,
                    builder: (context, snap) => Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.cyan.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.cyan.withOpacity(0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildProfileImage(
                          snap.data,
                          snap.connectionState,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.studentName,
                          style: TextStyle(
                            color: _C.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _C.cyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _C.cyan.withOpacity(0.3)),
                          ),
                          child: Text(
                            widget.rollNo,
                            style: TextStyle(
                              color: _C.cyan,
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
                                color: _C.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "Active Student",
                              style: TextStyle(
                                color: _C.textMid,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
              // Stats row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.bg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          semesterName,
                          style: TextStyle(
                            color: _C.textHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Week $weeksCompleted/$totalWeeks",
                          style: TextStyle(
                            color: _C.textMid,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalWeeks > 0 ? weeksCompleted / totalWeeks : 0,
                        backgroundColor: _C.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _C.cyan,
                        ),
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
                                strokeWidth: 2,
                                color: _C.cyan,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _drawerStat(
                                snapshot.data!['usingFallback'] == true
                                    ? (snapshot.data!['currentSemesterName']
                                            as String)
                                        .replaceAll(
                                            ' Semester', '') // "Even" or "Odd"
                                    : "${_getOrdinalSemester(semester)}",
                                "SEM",
                                _C.violet,
                              ),
                              _vDivider(),
                              _drawerStat("$courses", "COURSES", _C.cyan),
                              _vDivider(),
                              _drawerStat(
                                "${attendancePercentage.toStringAsFixed(0)}%",
                                "ATTEND",
                                _C.green,
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

  Widget _drawerStat(String value, String label, Color color) {
    final _C = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _C.textLow,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() {
    final _C = Provider.of<ThemeProvider>(context);
    return Container(width: 1, height: 28, color: _C.border);
  }

  Widget _buildNavSection(ThemeProvider _C) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _navGroup("MAIN", [
            _navItem(
              Icons.dashboard_rounded,
              "Dashboard",
              _C.cyan,
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
          ]),
          _navGroup("ACADEMICS", [
            _navItem(
              Icons.person_rounded,
              "My Profile",
              _C.violet,
              onTap: () => _navigateTo(ProfileScreen(
                rollNo: widget.rollNo,
                studentName: widget.studentName,
              )),
            ),
            _navItem(
              Icons.schedule_rounded,
              "Timetable",
              _C.cyan,
              onTap: () => _navigateTo(TimetableScreen(rollNo: widget.rollNo)),
            ),
            _navItem(
              Icons.subject_rounded,
              "Subjects",
              _C.green,
              onTap: () => _navigateTo(SubjectsPage()),
            ),
            _navItem(
              Icons.school_rounded,
              "Student Mentor",
              _C.amber,
              onTap: () => _navigateTo(
                MentorScreen(
                  rollNo: widget.rollNo,
                  studentName: widget.studentName,
                ),
              ),
            ),
          ]),
          _navGroup("ATTENDANCE", [
            _navItem(
              Icons.calendar_today_rounded,
              "Daily Attendance",
              _C.cyan,
              onTap: () => _navigateTo(
                AttendanceScreen(
                  rollNo: widget.rollNo,
                  studentName: widget.studentName,
                ),
              ),
            ),
            _navItem(
              Icons.leave_bags_at_home_rounded,
              "Leave Management",
              _C.pink,
              onTap: () => _navigateTo(
                LeaveManagementScreen(
                  rollNo: widget.rollNo,
                  studentName: widget.studentName,
                ),
              ),
            ),
          ]),
          _navGroup("EXAMINATIONS", [
            _navItem(
              Icons.grade_rounded,
              "Exam Results",
              _C.green,
              onTap: () => _navigateTo(
                ExamResultsPage(
                  studentName: widget.studentName,
                  rollNo: widget.rollNo,
                ),
              ),
            ),
            _navItem(
              Icons.chair_rounded,
              "Seating Arrangement",
              _C.violet,
              onTap: () => _navigateTo(
                SeatingArrangementPage(
                  studentName: widget.studentName,
                  rollNo: widget.rollNo,
                ),
              ),
            ),
          ]),
          _navGroup("CAMPUS", [
            // In _buildNavSection and _buildDrawer navigation:
            _navItem(
              Icons.event_rounded,
              "Academic Calendar",
              _C.amber,
              onTap: () => _navigateTo(
                AcademicCalendarScreen(
                  rollNo: widget.rollNo, // ADD
                  studentName: widget.studentName, // ADD
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navGroup(String title, List<Widget> items) {
    final _C = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            title,
            style: TextStyle(
              color: _C.textLow,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _navItem(
    IconData icon,
    String title,
    Color color, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final _C = Provider.of<ThemeProvider>(context);
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
            color: isSelected ? color.withOpacity(0.15) : _C.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.4) : _C.border,
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Icon(icon, color: isSelected ? color : _C.textMid, size: 17),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? color : _C.textMid,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.chevron_right_rounded,
                color: color.withOpacity(0.6),
                size: 16,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerFooter() {
    final _C = Provider.of<ThemeProvider>(context);
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _C.border)),
          ),
          child: Column(
            children: [
              // Theme Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: _C.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.cyan.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 12,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: _C.cyan,
                      size: 17,
                    ),
                  ),
                  title: Text(
                    themeProvider.isDarkMode ? "Dark Mode" : "Light Mode",
                    style: TextStyle(
                      color: _C.textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: _C.cyan,
                    activeTrackColor: _C.cyan.withOpacity(0.3),
                    inactiveThumbColor: _C.textMid,
                    inactiveTrackColor: _C.border,
                  ),
                  onTap: () => themeProvider.toggleTheme(),
                ),
              ),
              const SizedBox(height: 8),
              // Logout Button
              Container(
                decoration: BoxDecoration(
                  color: _C.pink.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.pink.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 12,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.pink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: _C.pink,
                      size: 17,
                    ),
                  ),
                  title: Text(
                    "Logout",
                    style: TextStyle(
                      color: _C.pink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: _handleLogout,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Heber ERP v1.0.0",
                style: TextStyle(
                  color: _C.textLow,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateTo(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final _C = Provider.of<ThemeProvider>(context, listen: false);
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(_C.isDarkMode ? 0.7 : 0.4),
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: _C.elevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.pink.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: _C.pink.withOpacity(0.15), blurRadius: 30),
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
                      _C.pink.withOpacity(0.15),
                      _C.pinkDim.withOpacity(0.08),
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
                        color: _C.pink.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.pink.withOpacity(0.4)),
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: _C.pink,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Sign Out?",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _C.textHigh,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You'll need to sign in again to access your account",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _C.textMid,
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
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _C.border),
                          foregroundColor: _C.textMid,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.pink,
                          foregroundColor:
                              _C.isDarkMode ? Colors.white : _C.textHigh,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Logout",
                              style: TextStyle(fontWeight: FontWeight.w700),
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
      ),
    );

    if (shouldLogout == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _C.elevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.pink,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Signing out...",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _cachedProfile = null;
      _cachedProfileRoll = null;
      await PhotoService.clearCachedPhoto();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => UnifiedLoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        );
      }
    }
  }

  Widget _buildProfileImage(String? photoUrl, ConnectionState connectionState) {
    final _C = Provider.of<ThemeProvider>(context);
    if (connectionState == ConnectionState.waiting) {
      return Container(
        color: _C.elevated,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.cyan),
          ),
        ),
      );
    }
    if (photoUrl == null) {
      return Container(
        color: _C.elevated,
        child: Icon(Icons.person_rounded, color: _C.cyan, size: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: _C.elevated,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.cyan),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: _C.elevated,
        child: Icon(Icons.person_rounded, color: _C.cyan, size: 28),
      ),
      httpHeaders: PhotoService.headers,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUTURISTIC DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class FuturisticDashboard extends StatefulWidget {
  final String studentName;
  final String rollNo;
  final double attendancePercentage;
  final int currentSemester;
  final String currentSemesterName;
  final int weeksCompleted;
  final int totalWeeks;
  final int dayOrder;
  final bool isCurrentSemester;
  final int currentSemesterCourses;
  final List<ExamResult> examResults;
  final List<Map<String, dynamic>> todayAttendance;
  final Map<String, dynamic> calendarData;

  const FuturisticDashboard({
    super.key,
    required this.studentName,
    required this.rollNo,
    required this.attendancePercentage,
    required this.currentSemester,
    required this.currentSemesterName,
    required this.weeksCompleted,
    required this.totalWeeks,
    required this.dayOrder,
    required this.isCurrentSemester,
    required this.currentSemesterCourses,
    required this.examResults,
    this.todayAttendance = const [],
    this.calendarData = const {},
  });

  @override
  State<FuturisticDashboard> createState() => _FuturisticDashboardState();
}

class _FuturisticDashboardState extends State<FuturisticDashboard>
    with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _stagger = List.generate(
      8,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    final firstName = widget.studentName.split(' ').first;
    if (hour < 12) return "Good Morning, $firstName";
    if (hour < 17) return "Good Afternoon, $firstName";
    return "Good Evening, $firstName";
  }

  double _calculateCurrentCGPA() {
    if (widget.examResults.isEmpty) return 0.0;
    double totalGradePoints = 0.0;
    int totalCredits = 0;
    for (var result in widget.examResults) {
      if (result.result == 'PASS' && result.gradePoint > 0) {
        totalGradePoints += result.gradePoint * result.credit;
        totalCredits += result.credit;
      }
    }
    return totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;
  }

  Map<String, double> _getLastSemesterPerformance() {
    if (widget.examResults.isEmpty) return {};
    final lastSemester = widget.examResults
        .map((e) => e.semester)
        .reduce((a, b) => a > b ? a : b);
    final Map<String, double> result = {};
    for (var r in widget.examResults.where((r) => r.semester == lastSemester)) {
      if (r.result == 'PASS') result[r.title] = r.total.toDouble();
    }
    return result;
  }

  String _getLastSemesterName() {
    if (widget.examResults.isEmpty) return "No Data";
    final lastSemester = widget.examResults
        .map((e) => e.semester)
        .reduce((a, b) => a > b ? a : b);
    return "Semester $lastSemester Performance";
  }

  double _getSemesterProgress() {
    if (widget.totalWeeks <= 0) return 0.0;
    return (widget.weeksCompleted / widget.totalWeeks).clamp(0.0, 1.0);
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(_stagger[i]),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Get theme provider
    final _C = Provider.of<ThemeProvider>(context);

    // Use _C for all colors
    final cgpa = _calculateCurrentCGPA();
    final lastPerf = _getLastSemesterPerformance();
    final lastSemName = _getLastSemesterName();
    final presentCount = widget.todayAttendance
        .where((h) => (h['status'] as String?)?.toLowerCase() == 'present')
        .length;
    final totalPeriods = widget.todayAttendance.length;
    final todayPct =
        totalPeriods > 0 ? (presentCount / totalPeriods) * 100 : 0.0;
    final semProgress = _getSemesterProgress();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          _animated(0, _buildHeroBanner(semProgress, _C)),
          const SizedBox(height: 16),
          _animated(
            1,
            _buildTodayAttendance(presentCount, totalPeriods, todayPct, _C),
          ),
          const SizedBox(height: 16),
          _animated(2, _buildStatsGrid(cgpa, _C)),
          const SizedBox(height: 16),
          _animated(3, _buildQuickActions(_C)),
          if (widget.examResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            _animated(4, _buildPerformanceChart(lastPerf, lastSemName, _C)),
          ],
          const SizedBox(height: 16),
          _animated(5, _buildScheduleCard(_C)),
          const SizedBox(height: 16),
          _animated(6, _buildActivitiesCard(_C)),
        ],
      ),
    );
  }

  // ─── HERO BANNER ──────────────────────────────────────────────────────────

  Widget _buildHeroBanner(double progress, ThemeProvider _C) {
    final progressPercent = (progress * 100).toStringAsFixed(0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _C.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _C.cyan.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _GridPainter(color: _C.cyan.withOpacity(0.03)),
              size: const Size(double.infinity, 160),
            ),
          ),
          // Animated scan line
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) => Positioned(
              top: (_scanCtrl.value * 160 - 2).clamp(0, 156),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _C.cyan.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (_, __) => Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _C.green,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _C.green.withOpacity(
                                          0.4 + _pulseCtrl.value * 0.3,
                                        ),
                                        blurRadius: 8 + _pulseCtrl.value * 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isCurrentSemester
                                    ? "ACTIVE SESSION"
                                    : "BREAK PERIOD",
                                style: TextStyle(
                                  color: _C.cyan.withOpacity(0.7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getDynamicGreeting(),
                            style: TextStyle(
                              color: _C.textHigh,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isCurrentSemester
                                ? "Welcome to ${widget.currentSemesterName}"
                                : "Next: ${widget.currentSemesterName}",
                            style: TextStyle(
                              color: _C.textMid,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.cyan.withOpacity(0.25)),
                      ),
                      child: Icon(
                        widget.isCurrentSemester
                            ? Icons.school_rounded
                            : Icons.event_rounded,
                        color: _C.cyan,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      Icons.today_rounded,
                      widget.dayOrder > 0
                          ? "Day Order ${widget.dayOrder}"
                          : "Day Order —",
                      _C.cyan,
                    ),
                    _chip(
                      Icons.date_range_rounded,
                      "Week ${widget.weeksCompleted}/${widget.totalWeeks}",
                      _C.violet,
                    ),
                    _chip(
                      Icons.percent_rounded,
                      "$progressPercent% Done",
                      _C.green,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Progress bar with neon glow
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _C.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_C.cyan, _C.violet],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: _C.cyan.withOpacity(
                                  0.5 + _pulseCtrl.value * 0.2,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TODAY'S ATTENDANCE ───────────────────────────────────────────────────

  Widget _buildTodayAttendance(
      int presentCount, int totalPeriods, double percentage, ThemeProvider _C) {
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final hasData = widget.todayAttendance.isNotEmpty;

    if (!hasData) {
      return _darkCard(
        tp: _C,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.textLow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.border),
              ),
              child: Icon(
                Icons.today_rounded,
                color: _C.textMid,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Attendance",
                    style: TextStyle(
                      color: _C.textHigh,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formattedDate,
                    style: TextStyle(color: _C.textMid, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "No attendance marked yet",
                    style: TextStyle(color: _C.textLow, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      _C.elevated.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Text(
                  "PENDING",
                  style: TextStyle(
                    color: _C.textMid,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = percentage == 100
        ? _C.green
        : percentage >= 60
            ? _C.amber
            : _C.pink;
    final statusText = percentage == 100
        ? "FULL PRESENT"
        : percentage >= 60
            ? "PARTIAL"
            : "LOW";

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.06), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Icon(
                    Icons.today_rounded,
                    color: statusColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Attendance",
                        style: TextStyle(
                          color: _C.textHigh,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(color: _C.textMid, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                _attendStat("$presentCount", "Present", _C.green, _C),
                const SizedBox(width: 12),
                _attendStat(
                  "${totalPeriods - presentCount}",
                  "Absent",
                  _C.pink,
                  _C,
                ),
                const SizedBox(width: 12),
                _attendStat("$totalPeriods", "Total", _C.cyan, _C),
                const Spacer(),
                Text(
                  "${percentage.toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: _C.border,
                valueColor: AlwaysStoppedAnimation(statusColor),
                minHeight: 6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(widget.todayAttendance.length, (i) {
                final hour = widget.todayAttendance[i];
                final isPresent =
                    (hour['status'] as String?)?.toLowerCase() == 'present';
                final periodNum = hour['hour'] ?? i + 1;
                final color = isPresent ? _C.green : _C.pink;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPresent ? Icons.check_rounded : Icons.close_rounded,
                        color: color,
                        size: 12,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "P$periodNum",
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendStat(
      String value, String label, Color color, ThemeProvider _C) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "$value $label",
          style: TextStyle(
            color: _C.textMid,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── STATS GRID ───────────────────────────────────────────────────────────

  Widget _buildStatsGrid(double cgpa, ThemeProvider _C) {
    final att = widget.attendancePercentage;
    final attDisplay = att > 0 ? '${att.toStringAsFixed(1)}%' : 'N/A';
    final attColor = att >= 75
        ? _C.cyan
        : att > 0
            ? _C.violet
            : _C.textLow;
    final attStatus = att >= 75
        ? 'Good standing'
        : att > 0
            ? 'Needs attention'
            : 'Loading...';
    final cgpaColor = cgpa >= 8.0
        ? _C.green
        : cgpa >= 6.0
            ? _C.amber
            : cgpa > 0
                ? _C.pink
                : _C.textLow;
    final cgpaStatus = cgpa >= 8.0
        ? 'Distinction'
        : cgpa >= 6.0
            ? 'First class'
            : cgpa > 0
                ? 'Pass'
                : 'No results yet';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _statCardWithRing('CGPA', cgpa > 0 ? cgpa.toStringAsFixed(2) : '—',
            cgpaStatus, Icons.leaderboard_rounded, cgpaColor, _C,
            progress: cgpa > 0 ? (cgpa / 10.0).clamp(0.0, 1.0) : 0.0),
        _statCardWithRing(
            'Attendance',
            attDisplay,
            attStatus,
            Icons.bar_chart_rounded, // ← change icon too for differentiation
            attColor,
            _C,
            progress: att > 0 ? (att / 100.0).clamp(0.0, 1.0) : 0.0),
        _statCard(
          widget.dayOrder > 0 ? 'Day Order' : 'Progress',
          widget.dayOrder > 0
              ? 'Day ${widget.dayOrder}'
              : '${widget.weeksCompleted}w',
          widget.dayOrder > 0
              ? 'Today'
              : 'Wk ${widget.weeksCompleted}/${widget.totalWeeks}',
          widget.dayOrder > 0
              ? Icons.today_rounded
              : Icons.calendar_today_rounded,
          _C.cyan,
          _C,
        ),
        _statCard(
          'Courses',
          widget.currentSemesterCourses.toString(),
          'This semester',
          Icons.menu_book_rounded,
          _C.violet,
          _C,
        ),
      ],
    );
  }

  Widget _statCardWithRing(String title, String value, String subtitle,
      IconData icon, Color color, ThemeProvider _C,
      {required double progress}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini arc progress at top
          SizedBox(
            width: double.infinity,
            height: 36,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Positioned(
                right: 0,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(
                      painter: _ArcPainter(v, color, _C.border),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, v, __) => Opacity(
              opacity: v,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                          color: color,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(color: color.withOpacity(0.4), blurRadius: 8)
                          ],
                        )),
                    const SizedBox(height: 3),
                    Text(title,
                        style: TextStyle(
                            color: _C.textHigh,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(color: _C.textLow, fontSize: 9)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ThemeProvider _C,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 14)],
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
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [
                    Shadow(color: color.withOpacity(0.4), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: _C.textHigh,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: _C.textLow, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ────────────────────────────────────────────────────────

  Widget _buildQuickActions(ThemeProvider _C) {
    final actions = [
      {
        'icon': Icons.show_chart_rounded,
        'label': 'Attendance',
        'color': _C.cyan,
        'screen': AttendanceScreen(
            rollNo: widget.rollNo, studentName: widget.studentName),
      },
      {
        'icon': Icons.menu_book_rounded,
        'label': 'Subjects',
        'color': _C.green,
        'screen': SubjectsPage(),
      },
      {
        'icon': Icons.event_seat_rounded,
        'label': 'Seating',
        'color': _C.amber,
        'screen': SeatingArrangementPage(
            rollNo: widget.rollNo, studentName: widget.studentName),
      },
      {
        'icon': Icons.people_alt_rounded,
        'label': 'Mentor',
        'color': _C.violet,
        'screen': MentorScreen(
            rollNo: widget.rollNo, studentName: widget.studentName),
      },
    ];

    return _darkCard(
      tp: _C,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("QUICK ACCESS", _C.cyan, Icons.grid_view_rounded, _C),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actions.map((action) {
              final color = action['color'] as Color;
              final screen = action['screen'] as Widget;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => screen,
                    transitionDuration: const Duration(milliseconds: 350),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(
                      opacity:
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                  ),
                ),
                child: Column(
                  children: [
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
                              color: color
                                  .withOpacity(0.06 + _pulseCtrl.value * 0.04),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(action['icon'] as IconData,
                            color: color, size: 24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: TextStyle(
                          color: _C.textMid,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
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

  void _showComingSoon(String title, Color color, ThemeProvider _C) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: _C.elevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 30),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "$title Coming Soon",
                style: TextStyle(
                  color: _C.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "This feature is under development and will be available soon.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.textMid, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.15),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: color.withOpacity(0.4)),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Got It",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PERFORMANCE CHART ────────────────────────────────────────────────────

  Widget _buildPerformanceChart(
      Map<String, double> performance, String title, ThemeProvider _C) {
    if (performance.isEmpty) {
      return _darkCard(
        tp: _C,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              title.toUpperCase(),
              _C.violet,
              Icons.bar_chart_rounded,
              _C,
            ),
            const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "No performance data available",
                  style: TextStyle(color: _C.textMid, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final courses = performance.keys.toList();
    final values = performance.values.toList();
    final barColors = [_C.cyan, _C.green, _C.violet, _C.amber, _C.pink];

    return _darkCard(
      tp: _C,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title.toUpperCase(),
            _C.violet,
            Icons.bar_chart_rounded,
            _C,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: _C.elevated2,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${_abbreviate(courses[groupIndex])}\n',
                      TextStyle(
                        color: _C.textHigh,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: '${values[groupIndex].toStringAsFixed(1)}%',
                          style: TextStyle(color: _C.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: TextStyle(color: _C.textLow, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) {
                        if (v.toInt() < courses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _abbreviate(courses[v.toInt()]),
                              style: TextStyle(
                                color: _C.textMid,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: _C.border, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(courses.length, (i) {
                  final color = barColors[i % barColors.length];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.4)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _abbreviate(String fullName) {
    final words = fullName.split(' ');
    const skip = ['AND', 'OF', 'THE', 'IN', 'FOR', 'TO', 'WITH', 'BY'];
    if (words.length > 1) {
      final meaningful =
          words.where((w) => !skip.contains(w.toUpperCase())).toList();
      if (meaningful.length > 1)
        return meaningful.map((w) => w[0].toUpperCase()).join();
      if (meaningful.isNotEmpty) {
        return meaningful[0].length > 4
            ? meaningful[0].substring(0, 4).toUpperCase()
            : meaningful[0].toUpperCase();
      }
    }
    return fullName.length > 8 ? '${fullName.substring(0, 7)}..' : fullName;
  }

  // ─── SCHEDULE + ACTIVITIES (placeholder) ─────────────────────────────────
  Widget _buildScheduleCard(ThemeProvider _C) {
    return _darkCard(
      tp: _C,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              "TODAY'S SCHEDULE", _C.cyan, Icons.schedule_rounded, _C),
          const SizedBox(height: 20),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.schedule_outlined, size: 44, color: _C.textLow),
                  const SizedBox(height: 12),
                  Text(
                    "No schedule data available",
                    style: TextStyle(color: _C.textMid, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check timetable for details",
                    style: TextStyle(color: _C.textLow, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesCard(ThemeProvider _C) {
    return _darkCard(
      tp: _C,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              "RECENT ACTIVITY", _C.amber, Icons.history_rounded, _C),
          const SizedBox(height: 20),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_outlined,
                    size: 44,
                    color: _C.textLow,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No recent activities",
                    style: TextStyle(color: _C.textMid, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Activities will appear here",
                    style: TextStyle(color: _C.textLow, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  Widget _darkCard({required Widget child, required ThemeProvider tp}) {
    final _C = tp;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(
      String title, Color color, IconData icon, ThemeProvider _C) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: _C.textHigh,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Custom Grid Painter ─────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const spacing = 30.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class ExamResultsResponse {
  final bool success;
  final List<ExamResult> data;
  ExamResultsResponse({required this.success, required this.data});
  factory ExamResultsResponse.fromJson(Map<String, dynamic> json) {
    return ExamResultsResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List? ?? [])
          .map((item) => ExamResult.fromJson(item))
          .toList(),
    );
  }
}

class ExamResult {
  final String id;
  final String examNo;
  final String name;
  final int semester;
  final String paperCode;
  final String title;
  final int cia;
  final int ese;
  final int total;
  final int credit;
  final String result;
  final String grade;
  final double gradePoint;
  final int internalId;

  ExamResult({
    required this.id,
    required this.examNo,
    required this.name,
    required this.semester,
    required this.paperCode,
    required this.title,
    required this.cia,
    required this.ese,
    required this.total,
    required this.credit,
    required this.result,
    required this.grade,
    required this.gradePoint,
    required this.internalId,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['_id'] ?? '',
      examNo: json['EXAMNO'] ?? '',
      name: json['NAME'] ?? '',
      semester: (json['SEM'] is int)
          ? json['SEM']
          : int.tryParse(json['SEM']?.toString() ?? '0') ?? 0,
      paperCode: json['PAPERCODE'] ?? '',
      title: json['TITLE'] ?? '',
      cia: (json['CIA'] is int)
          ? json['CIA']
          : int.tryParse(json['CIA']?.toString() ?? '0') ?? 0,
      ese: (json['ESE'] is int)
          ? json['ESE']
          : int.tryParse(json['ESE']?.toString() ?? '0') ?? 0,
      total: (json['TOTAL'] is int)
          ? json['TOTAL']
          : int.tryParse(json['TOTAL']?.toString() ?? '0') ?? 0,
      credit: (json['CREDIT'] is int)
          ? json['CREDIT']
          : int.tryParse(json['CREDIT']?.toString() ?? '0') ?? 0,
      result: json['RESULT'] ?? '',
      grade: json['GRADE'] ?? '',
      gradePoint: (json['GRADEPT'] is double)
          ? json['GRADEPT']
          : (json['GRADEPT'] is int)
              ? (json['GRADEPT'] as int).toDouble()
              : double.tryParse(json['GRADEPT']?.toString() ?? '0') ?? 0.0,
      internalId: json['id'] ?? 0,
    );
  }
}

// ─── Animated profile bubble overlay ─────────────────────────────────────────
class _ProfileBubbleOverlay extends StatefulWidget {
  final String rollNo;
  final String studentName;
  final Future<String?> photoFuture;
  final double screenWidth;
  final VoidCallback onClose;

  const _ProfileBubbleOverlay({
    required this.rollNo,
    required this.studentName,
    required this.photoFuture,
    required this.screenWidth,
    required this.onClose,
  });

  @override
  State<_ProfileBubbleOverlay> createState() => _ProfileBubbleOverlayState();
}

class _ProfileBubbleOverlayState extends State<_ProfileBubbleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));

    // Elastic overshoot — feels physical
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0.05, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final _C = Provider.of<ThemeProvider>(context, listen: false);
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(children: [
        // Dim backdrop
        FadeTransition(
          opacity: _fade,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 8 * _fade.value, // animated blur
              sigmaY: 8 * _fade.value,
            ),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        // Bubble positioned top-right under appbar
        Positioned(
          top: 72,
          right: 12,
          child: GestureDetector(
            onTap: () {}, // prevent backdrop tap from closing when tapping card
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.topRight,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                      position: _slide, child: _buildBubbleCard(_C)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBubbleCard(ThemeProvider _C) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        // Multi-stop gradient border via outer container trick
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.cyan, _C.violet, _C.pink],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: _C.cyan.withOpacity(0.35),
              blurRadius: 32,
              spreadRadius: 2),
          BoxShadow(
              color: _C.violet.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.all(1.5), // gradient border thickness
      child: Container(
        decoration: BoxDecoration(
          color: _C.elevated,
          borderRadius: BorderRadius.circular(23),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Colorful shimmer ring photo
          _AnimatedRingPhoto(
              photoFuture: widget.photoFuture, rollNo: widget.rollNo),
          const SizedBox(height: 14),
          // Gradient name text
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [_C.cyan, _C.violet],
            ).createShader(b),
            child: Text(widget.studentName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          // Rainbow roll badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _C.cyan.withOpacity(0.2),
                _C.violet.withOpacity(0.2)
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.cyan.withOpacity(0.5)),
            ),
            child: Text(widget.rollNo,
                style: TextStyle(
                    color: _C.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 10),
          // Animated status dot row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _C.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _C.green.withOpacity(0.6 + _ctrl.value * 0.3),
                      blurRadius: 8 + _ctrl.value * 6,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('Active Student',
                style: TextStyle(color: _C.textMid, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          // Gradient divider
          Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _C.cyan.withOpacity(0.4),
                  Colors.transparent
                ]),
              )),
          const SizedBox(height: 12),
          // Close button with gradient border
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _C.cyan.withOpacity(0.15),
                  _C.violet.withOpacity(0.15)
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.cyan.withOpacity(0.3)),
              ),
              child: Text('Close',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _C.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AnimatedRingPhoto extends StatefulWidget {
  final Future<String?> photoFuture;
  final String rollNo;
  const _AnimatedRingPhoto({required this.photoFuture, required this.rollNo});
  @override
  State<_AnimatedRingPhoto> createState() => _AnimatedRingPhotoState();
}

class _AnimatedRingPhotoState extends State<_AnimatedRingPhoto>
    with SingleTickerProviderStateMixin {
  late AnimationController _ring;
  @override
  void initState() {
    super.initState();
    _ring =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _C = Provider.of<ThemeProvider>(context, listen: false);
    return FutureBuilder<String?>(
      future: widget.photoFuture,
      builder: (_, snap) => AnimatedBuilder(
        animation: _ring,
        builder: (_, __) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: 6.28,
              transform: GradientRotation(_ring.value * 6.28),
              colors: [
                _C.cyan,
                _C.violet,
                _C.cyan.withOpacity(0.3),
                _C.cyan,
              ],
            ),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: _C.elevated),
            child: ClipOval(
              child: snap.hasData && snap.data != null
                  ? Image.network(snap.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(_C))
                  : _placeholder(_C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeProvider _C) => Container(
        color: _C.surface,
        child: Icon(Icons.person_rounded, color: _C.textLow, size: 36),
      );
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  const _ArrowPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2 - 6, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 6, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Arc progress painter for stat cards ──────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  const _ArcPainter(this.progress, this.color, this.trackColor);

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = -2.4;
    const sweepMax = 4.8;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 3);
    canvas.drawArc(
        rect,
        startAngle,
        sweepMax,
        false,
        Paint()
          ..color = trackColor
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(
          rect,
          startAngle,
          sweepMax * progress,
          false,
          Paint()
            ..color = color
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.progress != progress;
}
