import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

const String baseApiUrl = 'https://apierp.bhc.edu.in';
const String refererUrl = 'http://117.232.64.75';

class Subject {
  final String code;
  final String name;
  final String type;
  final String instructor;
  final String instructorId;
  final String category;

  Subject({
    required this.code,
    required this.name,
    required this.type,
    required this.instructor,
    required this.instructorId,
    required this.category,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      code: json['paperCode'] ?? 'N/A',
      name: json['paperTitle'] ?? 'No Title',
      type: json['paperType'] ?? 'Unknown Type',
      instructor: json['staffName'] ?? 'Unknown Instructor',
      instructorId: json['staffid'] ?? 'N/A',
      category: 'Core Subject',
    );
  }
}

class ApiService {
  static const String baseUrl = '$baseApiUrl/api/students/subjects';
  
  static Future<List<Subject>> fetchSubjects({
    required String rollNo,
    String? programName,
    String? year,
    String? section,
  }) async {
    try {
      if (programName != null && year != null && section != null) {
        final Map<String, dynamic> requestBody = {
          'program_name': programName,
          'year': year.replaceAll('Year ', ''),
          'section_name': section,
        };

        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Referer': refererUrl,
              },
              body: json.encode(requestBody),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true && responseData['data']?['subjects'] is List) {
            final subjects = responseData['data']['subjects'] as List;
            return subjects.map((data) => Subject.fromJson(data)).toList();
          }
        }
      }

      final response2 = await http
          .get(
            Uri.parse('$baseUrl?rollNo=$rollNo'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Referer': refererUrl,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response2.statusCode == 200) {
        final responseData = json.decode(response2.body);
        return _parseSubjects(responseData);
      }

      throw Exception('No valid response received');
    } catch (e) {
      throw Exception('Failed to load subjects: $e');
    }
  }

  static List<Subject> _parseSubjects(dynamic responseData) {
    if (responseData == null) return [];
    if (responseData is List) {
      return responseData.map((data) => Subject.fromJson(data)).toList();
    } else if (responseData['data']?['subjects'] is List) {
      final subjects = responseData['data']['subjects'] as List;
      return subjects.map((data) => Subject.fromJson(data)).toList();
    }
    return [];
  }
}

class SubjectsPage extends StatefulWidget {
  final String? rollNo;
  final String? studentName;
    const SubjectsPage({super.key, this.rollNo, this.studentName});

  @override
  _SubjectsPageState createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage>
    with TickerProviderStateMixin {
  List<Subject> subjects = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  String? rollNo;
  String? studentName;
  String? programName;
  String? year;
  String? section;

  late AnimationController _staggerCtrl;
  late AnimationController _appBarGlow;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _stagger = List.generate(
      12,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.08, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _loadStudentDataAndFetchSubjects();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  String getAcademicYear(String batchRange) {
    if (batchRange.isEmpty) return "Year 1";
    final years = batchRange.split('-');
    if (years.length != 2) return "Year 1";
    int startYear = int.tryParse(years[0]) ?? DateTime.now().year;
    final now = DateTime.now();
    int academicYear = 1;
    if (now.year == startYear) {
      academicYear = now.month >= 6 ? 1 : 0;
    } else if (now.year == startYear + 1) {
      academicYear = now.month >= 6 ? 2 : 1;
    } else if (now.year == startYear + 2) {
      academicYear = now.month >= 6 ? 3 : 2;
    }
    academicYear = academicYear.clamp(1, 2);
    return "Year $academicYear";
  }
Future<void> _loadStudentDataAndFetchSubjects() async {
  setState(() {
    isLoading = true;
    hasError = false;
  });
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Use passed parameters first, then fallback to SharedPreferences
    rollNo = widget.rollNo ?? prefs.getString('rollNo');
    studentName = widget.studentName ?? prefs.getString('studentName');
    
    if (rollNo == null) throw Exception('Please login again');
    
    await _fetchStudentProfile(rollNo!);
    await _fetchSubjects();
    _staggerCtrl.forward();
  } catch (e) {
    setState(() {
      hasError = true;
      errorMessage = e.toString();
      isLoading = false;
    });
  }
}

  Future<void> _fetchStudentProfile(String rollNo) async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseApiUrl/api/students/$rollNo"),
            headers: {"Referer": refererUrl},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data["data"] != null) {
          var currentAcademic = data["data"]["current_academic"];
          programName = currentAcademic?["degree_name"] ?? "M.Sc. Computer Science";
          section = currentAcademic?["section"] ?? "A";
          String? batch = data["data"]["batch"] ?? "2025-2027";
          year = getAcademicYear(batch!);
          // Also get student name from API if needed
          studentName = data["data"]["name"] ?? studentName;
        }
      }
    } catch (e) {
      programName = "M.Sc. Computer Science";
      section = "A";
      year = "Year 1";
    }
  }

  Future<void> _fetchSubjects() async {
    try {
      final fetchedSubjects = await ApiService.fetchSubjects(
        rollNo: rollNo!,
        programName: programName,
        year: year,
        section: section,
      );
      setState(() {
        subjects = fetchedSubjects;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    _staggerCtrl.reset();
    await _loadStudentDataAndFetchSubjects();
  }

  Color _getSubjectColor(String type, ThemeProvider c) {
    final t = type.toLowerCase();
    if (t.contains('prac') || t.contains('lab')) return c.violet;
    if (t.contains('core')) return c.cyan;
    if (t.contains('elective')) return c.amber;
    return c.green;
  }

  IconData _getSubjectIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('prac') || t.contains('lab')) return Icons.computer_rounded;
    if (t.contains('core')) return Icons.menu_book_rounded;
    if (t.contains('elective')) return Icons.auto_stories_rounded;
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: rollNo ?? '',
        studentName: studentName ?? 'Student',
        currentRoute: '/subjects',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: isLoading
          ? _buildLoadingState(c)
          : hasError
              ? _buildErrorState(c)
              : _buildContent(c),
    );
  }

  // ─── FUTURISTIC APP BAR (WITH CYAN PRIMARY COLOR) ─────────────────────────────────
  PreferredSizeWidget _buildFuturisticAppBar(ThemeProvider c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                bottom: BorderSide(
                  color: c.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
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
                          color: c.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: c.textHigh,
                          size: 18,
                        ),
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Subjects",
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${subjects.length} Courses",
                        style: TextStyle(
                          color: c.cyan.withOpacity(0.8),
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
                      color: c.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.cyan,
                            boxShadow: [
                              BoxShadow(
                                color: c.cyan.withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${subjects.length}",
                          style: TextStyle(
                            color: c.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh button
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: c.textMid,
                      size: 20,
                    ),
                    onPressed: _refreshData,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.cyan,
              backgroundColor: c.cyan.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),
          Text("Loading subjects...", style: TextStyle(color: c.textMid, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.pink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: c.pink, size: 40),
            ),
            const SizedBox(height: 16),
            Text("Failed to Load", style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _refreshData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.cyan.withOpacity(0.3)),
                ),
                child: Text("Try Again", style: TextStyle(color: c.cyan, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeProvider c) {
    final coreCount = subjects.where((s) => s.type.contains('Core')).length;
    final electiveCount = subjects.where((s) => s.type.contains('Elective')).length;
    final practicalCount = subjects.where((s) => s.type.contains('Prac')).length;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: c.cyan,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _stagger[0],
              child: _buildCompactStudentInfo(c),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _stagger[1],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildStatCard(c, "Total", subjects.length.toString(), Icons.library_books_rounded, c.cyan)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(c, "Core", coreCount.toString(), Icons.bookmark_rounded, c.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(c, "Elective", electiveCount.toString(), Icons.auto_stories_rounded, c.amber)),
                    if (practicalCount > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard(c, "Practical", practicalCount.toString(), Icons.science_rounded, c.violet)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: c.cyan, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text("COURSE LIST", style: TextStyle(color: c.textHigh, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: c.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text("${subjects.length}", style: TextStyle(color: c.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return FadeTransition(
                  opacity: _stagger[(index % 8) + 2],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildSubjectCard(c, subjects[index], index),
                  ),
                );
              },
              childCount: subjects.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildCompactStudentInfo(ThemeProvider c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.cyan.withOpacity(0.15), c.violet.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_rounded, color: c.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName?.toUpperCase() ?? 'STUDENT',
                  style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    _infoChip(c, rollNo ?? 'N/A', Icons.badge_rounded, c.cyan),
                    _infoChip(c, year ?? 'Year 1', Icons.calendar_today_rounded, c.green),
                    _infoChip(c, section ?? 'A', Icons.group_rounded, c.violet),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(ThemeProvider c, String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatCard(ThemeProvider c, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: c.textLow, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(ThemeProvider c, Subject subject, int index) {
    final color = _getSubjectColor(subject.type, c);
    final icon = _getSubjectIcon(subject.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.code,
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.name,
                        style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subject.type,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: c.elevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_outline_rounded, size: 12, color: c.textMid),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject.instructor,
                    style: TextStyle(color: c.textMid, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
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
}