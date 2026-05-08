import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExamResultsPage extends StatefulWidget {
  final String studentName;
  final String rollNo;

  const ExamResultsPage({
    super.key,
    required this.studentName,
    required this.rollNo,
  });

  @override
  State<ExamResultsPage> createState() => _ExamResultsPageState();
}

class _ExamResultsPageState extends State<ExamResultsPage>
    with TickerProviderStateMixin {
  late Future<ExamResultsResponse> futureExamResults;
  Map<int, bool> _expandedSemesters = {};
  String? _studentName;
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
      duration: const Duration(milliseconds: 800),
    );
    _stagger = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _loadStudentName();
    futureExamResults = fetchExamResults(widget.rollNo).then((value) {
      _staggerCtrl.forward();
      return value;
    });
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    _studentName = prefs.getString('studentName') ?? widget.studentName;
    setState(() {});
  }

  Future<ExamResultsResponse> fetchExamResults(String rollNo) async {
    try {
      final headers = {
        "Referer": "http://117.232.64.75",
        "Accept": "application/json",
      };

      final response = await http
          .get(
            Uri.parse(
              'https://apierp.bhc.edu.in/api/students/exams/ese/$rollNo',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ExamResultsResponse.fromJson(jsonResponse);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load exam results: $e');
    }
  }

  void _toggleSemesterExpansion(int semester) {
    setState(() {
      _expandedSemesters[semester] = !(_expandedSemesters[semester] ?? false);
    });
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

  // ─── FUTURISTIC APP BAR ─────────────────────────────────────────────────
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
                        "Exam Results",
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "End Semester",
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
                          "RESULTS",
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
                    onPressed: () {
                      setState(() {
                        futureExamResults = fetchExamResults(widget.rollNo);
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: widget.rollNo,
        studentName: _studentName ?? widget.studentName,
        currentRoute: '/exam-results',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: FutureBuilder<ExamResultsResponse>(
        future: futureExamResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(c);
          } else if (snapshot.hasError) {
            return _buildErrorState(c, snapshot.error.toString());
          } else if (snapshot.hasData && snapshot.data!.success && snapshot.data!.data.isNotEmpty) {
            final data = snapshot.data!;
            final resultsBySemester = _groupResultsBySemester(data.data);
            final semesters = resultsBySemester.keys.toList()..sort();
            final overallStats = _calculateOverallStatistics(data.data);
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  futureExamResults = fetchExamResults(widget.rollNo);
                });
                await futureExamResults;
              },
              color: c.cyan,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _animated(0, _buildHeroBanner(c, overallStats)),
                    const SizedBox(height: 16),
                    _animated(1, _buildStatsGrid(c, overallStats)),
                    const SizedBox(height: 16),
                    _animated(2, _buildSemesterList(c, resultsBySemester, semesters)),
                  ],
                ),
              ),
            );
          } else {
            return _buildNoDataState(c);
          }
        },
      ),
    );
  }

  // ─── HERO BANNER ─────────────────────────────────────────────────────────
  Widget _buildHeroBanner(ThemeProvider c, OverallStatistics stats) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.08), blurRadius: 30)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.cyan, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text("ACADEMIC RESULTS", style: TextStyle(color: c.cyan.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _studentName?.split(' ').first ?? "Student",
                    style: TextStyle(color: c.textHigh, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "End Semester Examination",
                    style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(c, "${stats.cgpa.toStringAsFixed(2)}", "CGPA", c.cyan),
                      _infoChip(c, "${stats.totalSubjects}", "Subjects", c.violet),
                      _infoChip(c, "${stats.passedSubjects}", "Passed", c.green),
                      if (stats.failedSubjects > 0)
                        _infoChip(c, "${stats.failedSubjects}", "Failed", c.pink),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.cyan.withOpacity(0.25)),
              ),
              child: Icon(Icons.grade_rounded, color: c.cyan, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(ThemeProvider c, String value, String label, Color color) {
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
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── STATS GRID ──────────────────────────────────────────────────────────
  Widget _buildStatsGrid(ThemeProvider c, OverallStatistics stats) {
    return Row(
      children: [
        Expanded(child: _statCard(c, "CGPA", stats.cgpa.toStringAsFixed(2), "out of 10", Icons.leaderboard_rounded, c.cyan)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(c, "Pass Rate", "${((stats.passedSubjects / stats.totalSubjects) * 100).toStringAsFixed(0)}%", "${stats.passedSubjects}/${stats.totalSubjects}", Icons.percent_rounded, c.green)),
      ],
    );
  }

  Widget _statCard(ThemeProvider c, String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 14)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1,
              shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)]),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: c.textHigh, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(subtitle, style: TextStyle(color: c.textLow, fontSize: 9)),
        ],
      ),
    );
  }

  // ─── SEMESTER LIST ───────────────────────────────────────────────────────
  Widget _buildSemesterList(ThemeProvider c, Map<int, List<ExamResult>> resultsBySemester, List<int> semesters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: c.cyan, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text("SEMESTER BREAKDOWN", style: TextStyle(color: c.textHigh, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const Spacer(),
              Text("${semesters.length} Semesters", style: TextStyle(color: c.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...semesters.map((semester) => _buildSemesterCard(c, semester, resultsBySemester[semester]!)),
      ],
    );
  }

  Widget _buildSemesterCard(ThemeProvider c, int semester, List<ExamResult> results) {
    final stats = _calculateSemesterStatistics(results);
    final isExpanded = _expandedSemesters[semester] ?? false;
    final statusColor = stats.sgpa >= 8 ? c.green : (stats.sgpa >= 6 ? c.cyan : c.amber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? c.cyan.withOpacity(0.3) : c.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSemesterExpansion(semester),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [c.cyan.withOpacity(0.2), c.cyan.withOpacity(0.05)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text("$semester", style: TextStyle(color: c.cyan, fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Semester $semester", style: TextStyle(color: c.textHigh, fontSize: 15, fontWeight: FontWeight.w700)),
                              Text("${stats.totalSubjects} subjects", style: TextStyle(color: c.textLow, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text("SGPA: ${stats.sgpa.toStringAsFixed(2)}",
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _semesterStat(c, "Credits", "${stats.totalCredits}", Icons.star_rounded, c.amber),
                      _semesterStat(c, "Passed", "${stats.passedSubjects}", Icons.check_circle_rounded, c.green),
                      if (stats.failedSubjects > 0)
                        _semesterStat(c, "Failed", "${stats.failedSubjects}", Icons.cancel_rounded, c.pink),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isExpanded ? "Show less" : "Show subjects",
                          style: TextStyle(fontSize: 10, color: c.cyan, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: c.cyan),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: results.map((result) => _buildSubjectCard(c, result)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _semesterStat(ThemeProvider c, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: c.textLow, fontSize: 9, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSubjectCard(ThemeProvider c, ExamResult result) {
    final isPass = result.result == 'PASS';
    final gradeColor = isPass ? 
        (result.grade == 'O' ? c.violet : (result.grade == 'A+' ? c.cyan : c.green)) : c.pink;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.paperCode, style: TextStyle(color: c.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(result.title, style: TextStyle(color: c.textMid, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gradeColor.withOpacity(0.3)),
                ),
                child: Text(result.grade, style: TextStyle(color: gradeColor, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _resultScore(c, "CIA", "${result.cia}", c.cyan),
              _resultScore(c, "ESE", "${result.ese}", c.green),
              _resultScore(c, "Total", "${result.total}", c.amber),
              _resultScore(c, "Credit", "${result.credit}", c.violet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultScore(ThemeProvider c, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: c.textLow, fontSize: 9, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ─── LOADING / ERROR / NO DATA STATES ────────────────────────────────────
  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.cyan, backgroundColor: c.cyan.withOpacity(0.1)),
          ),
          const SizedBox(height: 16),
          Text("Loading exam results...", style: TextStyle(color: c.textMid, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider c, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.pink.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, color: c.pink, size: 40),
            ),
            const SizedBox(height: 16),
            Text("No Results Found", style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text("No exam results available for ${widget.rollNo}", textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  futureExamResults = fetchExamResults(widget.rollNo);
                });
              },
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

  Widget _buildNoDataState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: c.amber.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.assignment_late_rounded, size: 50, color: c.amber),
            ),
            const SizedBox(height: 20),
            Text("No Results Published", style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text("Exam results have not been published yet", textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── HELPER METHODS ──────────────────────────────────────────────────────
  Map<int, List<ExamResult>> _groupResultsBySemester(List<ExamResult> results) {
    final Map<int, List<ExamResult>> grouped = {};
    for (var result in results) {
      grouped.putIfAbsent(result.semester, () => []).add(result);
    }
    return grouped;
  }

  OverallStatistics _calculateOverallStatistics(List<ExamResult> results) {
    int totalCredits = 0;
    double totalGradePoints = 0;
    int totalSubjects = 0;
    int passedSubjects = 0;
    int failedSubjects = 0;

    for (var result in results) {
      totalSubjects++;
      if (result.result == 'PASS') {
        passedSubjects++;
        totalCredits += result.credit;
        totalGradePoints += result.gradePoint * result.credit;
      } else {
        failedSubjects++;
      }
    }

    final cgpa = totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;

    return OverallStatistics(
      totalSubjects: totalSubjects,
      passedSubjects: passedSubjects,
      failedSubjects: failedSubjects,
      totalCredits: totalCredits,
      cgpa: cgpa,
    );
  }

  SemesterStatistics _calculateSemesterStatistics(List<ExamResult> results) {
    int totalCredits = 0;
    double totalGradePoints = 0;
    int totalSubjects = results.length;
    int passedSubjects = 0;
    int failedSubjects = 0;

    for (var result in results) {
      if (result.result == 'PASS') {
        passedSubjects++;
        totalCredits += result.credit;
        totalGradePoints += result.gradePoint * result.credit;
      } else {
        failedSubjects++;
      }
    }

    final sgpa = totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;

    return SemesterStatistics(
      totalSubjects: totalSubjects,
      passedSubjects: passedSubjects,
      failedSubjects: failedSubjects,
      totalCredits: totalCredits,
      sgpa: sgpa,
    );
  }
}

// ─── DATA MODELS ────────────────────────────────────────────────────────────
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
      semester: (json['SEM'] is int) ? json['SEM'] : int.tryParse(json['SEM']?.toString() ?? '0') ?? 0,
      paperCode: json['PAPERCODE'] ?? '',
      title: json['TITLE'] ?? '',
      cia: (json['CIA'] is int) ? json['CIA'] : int.tryParse(json['CIA']?.toString() ?? '0') ?? 0,
      ese: (json['ESE'] is int) ? json['ESE'] : int.tryParse(json['ESE']?.toString() ?? '0') ?? 0,
      total: (json['TOTAL'] is int) ? json['TOTAL'] : int.tryParse(json['TOTAL']?.toString() ?? '0') ?? 0,
      credit: (json['CREDIT'] is int) ? json['CREDIT'] : int.tryParse(json['CREDIT']?.toString() ?? '0') ?? 0,
      result: json['RESULT'] ?? '',
      grade: json['GRADE'] ?? '',
      gradePoint: (json['GRADEPT'] is double) ? json['GRADEPT'] : (json['GRADEPT'] is int) ? (json['GRADEPT'] as int).toDouble() : double.tryParse(json['GRADEPT']?.toString() ?? '0') ?? 0.0,
      internalId: json['id'] ?? 0,
    );
  }
}

class OverallStatistics {
  final int totalSubjects;
  final int passedSubjects;
  final int failedSubjects;
  final int totalCredits;
  final double cgpa;
  OverallStatistics({required this.totalSubjects, required this.passedSubjects, required this.failedSubjects, required this.totalCredits, required this.cgpa});
}

class SemesterStatistics {
  final int totalSubjects;
  final int passedSubjects;
  final int failedSubjects;
  final int totalCredits;
  final double sgpa;
  SemesterStatistics({required this.totalSubjects, required this.passedSubjects, required this.failedSubjects, required this.totalCredits, required this.sgpa});
}