import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeatingArrangementPage extends StatefulWidget {
  final String studentName;
  final String rollNo;

  const SeatingArrangementPage({
    super.key,
    required this.studentName,
    required this.rollNo,
  });

  @override
  State<SeatingArrangementPage> createState() => _SeatingArrangementPageState();
}

class _SeatingArrangementPageState extends State<SeatingArrangementPage>
    with TickerProviderStateMixin {
  late Future<SeatingArrangementResponse> futureSeatingArrangement;
  int? _expandedExamIndex;
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
    futureSeatingArrangement = fetchSeatingArrangement(widget.rollNo);
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

  Future<SeatingArrangementResponse> fetchSeatingArrangement(String rollNo) async {
    try {
      final headers = {
        "Referer": "http://117.232.64.75",
        "Accept": "application/json",
      };

      final response = await http
          .get(
            Uri.parse(
              'https://apierp.bhc.edu.in/api/students/exams/seating/$rollNo',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return SeatingArrangementResponse.fromJson(jsonResponse);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load seating arrangement: $e');
    }
  }

  void _toggleExamExpansion(int index) {
    setState(() {
      if (_expandedExamIndex == index) {
        _expandedExamIndex = null;
      } else {
        _expandedExamIndex = index;
      }
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
                  color: c.cyan.withOpacity(0.15 + _appBarGlow.value * 0.12),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.cyan.withOpacity(0.04 + _appBarGlow.value * 0.03),
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
                        "Seating Arrangement",
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "Exam Hall Allocations",
                        style: TextStyle(
                          color: c.cyan.withOpacity(0.75),
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
                      color: c.violet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.violet.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.violet,
                            boxShadow: [
                              BoxShadow(
                                color: c.violet.withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "SEATS",
                          style: TextStyle(
                            color: c.violet,
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
                        futureSeatingArrangement = fetchSeatingArrangement(widget.rollNo);
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
        currentRoute: '/seating',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: FutureBuilder<SeatingArrangementResponse>(
        future: futureSeatingArrangement,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(c);
          } else if (snapshot.hasError) {
            return _buildErrorState(c, snapshot.error.toString());
          } else if (snapshot.hasData && snapshot.data!.success && snapshot.data!.data.isNotEmpty) {
            final data = snapshot.data!;
            final exams = _parseAllExamSchedules(data.data);
            _staggerCtrl.forward();
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  futureSeatingArrangement = fetchSeatingArrangement(widget.rollNo);
                });
                await futureSeatingArrangement;
              },
              color: c.violet,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _animated(0, _buildHeroBanner(c, exams)),
                    const SizedBox(height: 16),
                    _animated(1, _buildSummaryCards(c, exams)),
                    const SizedBox(height: 16),
                    _animated(2, _buildScheduleList(c, exams)),
                    const SizedBox(height: 16),
                    _animated(3, _buildExamInstructions(c)),
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
  Widget _buildHeroBanner(ThemeProvider c, List<ExamSchedule> exams) {
    final uniqueVenues = exams.map((e) => e.venue).toSet().length;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c.bannerGradient),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.violet.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.violet.withOpacity(0.08), blurRadius: 30)],
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
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.violet, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text("EXAMINATION SEATING", style: TextStyle(color: c.violet.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_studentName?.split(' ').first ?? "Student", style: TextStyle(color: c.textHigh, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 4),
                  Text("Seat Allocation Details", style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(c, "${exams.length}", "Exams", c.cyan),
                      _infoChip(c, "$uniqueVenues", "Venues", c.violet),
                      _infoChip(c, widget.rollNo, "Roll No", c.green),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.violet.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.violet.withOpacity(0.25))),
              child: Icon(Icons.chair_rounded, color: c.violet, size: 26),
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

  // ─── SUMMARY CARDS ───────────────────────────────────────────────────────
  Widget _buildSummaryCards(ThemeProvider c, List<ExamSchedule> exams) {
    final forenoonCount = exams.where((e) => e.session == 'Forenoon').length;
    final afternoonCount = exams.where((e) => e.session == 'Afternoon').length;
    final uniqueVenues = exams.map((e) => e.venue).toSet().length;

    return Row(
      children: [
        Expanded(child: _summaryCard(c, "Total", "${exams.length}", Icons.assignment_rounded, c.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(c, "Forenoon", "$forenoonCount", Icons.wb_sunny_rounded, c.green)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(c, "Afternoon", "$afternoonCount", Icons.nightlight_round, c.amber)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(c, "Venues", "$uniqueVenues", Icons.location_on_rounded, c.violet)),
      ],
    );
  }

  Widget _summaryCard(ThemeProvider c, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(title, style: TextStyle(color: c.textLow, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── SCHEDULE LIST ───────────────────────────────────────────────────────
  Widget _buildScheduleList(ThemeProvider c, List<ExamSchedule> exams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: c.violet, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text("EXAMINATION SCHEDULE", style: TextStyle(color: c.textHigh, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const Spacer(),
              Text("${exams.length} Exams", style: TextStyle(color: c.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...exams.asMap().entries.map((entry) => _buildExamCard(c, entry.value, entry.key)),
      ],
    );
  }

  Widget _buildExamCard(ThemeProvider c, ExamSchedule exam, int index) {
    final isExpanded = _expandedExamIndex == index;
    final sessionColor = exam.session == 'Forenoon' ? c.green : c.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? c.violet.withOpacity(0.3) : c.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExamExpansion(index),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [c.violet.withOpacity(0.2), c.violet.withOpacity(0.05)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text("${index + 1}", style: TextStyle(color: c.violet, fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exam.date, style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(exam.day, style: TextStyle(color: c.textLow, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sessionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sessionColor.withOpacity(0.3)),
                        ),
                        child: Text(exam.session, style: TextStyle(color: sessionColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _detailChip(c, Icons.access_time_rounded, exam.time, c.cyan),
                      const SizedBox(width: 8),
                      _detailChip(c, Icons.chair_rounded, "Seat: ${exam.seatNo}", c.violet),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _detailChip(c, Icons.location_on_rounded, exam.venue, c.pink, isExpanded: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isExpanded ? "Show less" : "Show venue details",
                          style: TextStyle(fontSize: 10, color: c.violet, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: c.violet),
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
                children: [
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 12),
                  _locationDetail(c, Icons.business_rounded, "Building", exam.building, c.cyan),
                  const SizedBox(height: 8),
                  _locationDetail(c, Icons.account_balance_rounded, "Block", exam.block, c.green),
                  const SizedBox(height: 8),
                  _locationDetail(c, Icons.flood_rounded, "Floor", exam.floor, c.amber),
                  const SizedBox(height: 8),
                  _locationDetail(c, Icons.meeting_room_rounded, "Classroom", exam.classroom, c.violet),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailChip(ThemeProvider c, IconData icon, String label, Color color, {bool isExpanded = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _locationDetail(ThemeProvider c, IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text("$title:", style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ],
    );
  }

  // ─── EXAM INSTRUCTIONS ───────────────────────────────────────────────────
  Widget _buildExamInstructions(ThemeProvider c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.amber.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.amber.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.info_rounded, color: c.amber, size: 18)),
                const SizedBox(width: 10),
                Text("Important Instructions", style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _instructionItem(c, Icons.access_time_rounded, "Arrive 30 minutes before scheduled time", c.green),
                const SizedBox(height: 10),
                _instructionItem(c, Icons.assignment_rounded, "Carry college ID card and hall ticket", c.cyan),
                const SizedBox(height: 10),
                _instructionItem(c, Icons.phonelink_off_rounded, "Electronic devices are prohibited", c.pink),
                const SizedBox(height: 10),
                _instructionItem(c, Icons.volume_off_rounded, "Maintain silence in examination hall", c.amber),
                const SizedBox(height: 10),
                _instructionItem(c, Icons.help_rounded, "Contact invigilator for any discrepancies", c.violet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionItem(ThemeProvider c, IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.textMid, fontSize: 12))),
      ],
    );
  }

  // ─── LOADING / ERROR / NO DATA STATES ────────────────────────────────────
  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: c.violet, backgroundColor: c.violet.withOpacity(0.1))),
        const SizedBox(height: 16),
        Text("Loading seating arrangement...", style: TextStyle(color: c.textMid, fontSize: 14)),
      ]),
    );
  }

  Widget _buildErrorState(ThemeProvider c, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.pink.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.error_outline_rounded, color: c.pink, size: 40)),
          const SizedBox(height: 16),
          Text("Failed to Load", style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text("No seating data found for ${widget.rollNo}", textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => futureSeatingArrangement = fetchSeatingArrangement(widget.rollNo)),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), decoration: BoxDecoration(color: c.violet.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.violet.withOpacity(0.3))), child: Text("Try Again", style: TextStyle(color: c.violet, fontWeight: FontWeight.w700))),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoDataState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: c.amber.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.event_busy, size: 50, color: c.amber)),
          const SizedBox(height: 20),
          Text("No Seating Data", style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text("No seating arrangement available for your roll number", textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
        ]),
      ),
    );
  }

  // ─── HELPER METHODS ──────────────────────────────────────────────────────
  List<ExamSchedule> _parseAllExamSchedules(List<SeatingData> seatingDataList) {
    List<ExamSchedule> allExams = [];
    for (var seatingData in seatingDataList) {
      allExams.addAll(_parseExamSchedules(seatingData));
    }
    allExams.sort((a, b) => _parseDateString(a.date).compareTo(_parseDateString(b.date)));
    return allExams;
  }

  List<ExamSchedule> _parseExamSchedules(SeatingData seatingData) {
    List<ExamSchedule> exams = [];
    try {
      final parts = seatingData.date.split(' - ');
      if (parts.length >= 2) {
        final datePart = parts[0].trim();
        final sessionPart = parts[1].trim();
        final session = sessionPart.contains('FN') ? 'Forenoon' : 'Afternoon';
        final time = sessionPart.contains('FN') ? '9:00 AM - 12:00 PM' : '2:00 PM - 5:00 PM';

        if (datePart.contains(',')) {
          final dateComponents = datePart.split(', ');
          final lastComponent = dateComponents.last;
          final monthYearParts = lastComponent.split('-');
          if (monthYearParts.length >= 3) {
            final month = monthYearParts[1];
            final year = monthYearParts[2];
            for (int i = 0; i < dateComponents.length; i++) {
              String dayComponent = dateComponents[i];
              if (i == dateComponents.length - 1 && dayComponent.contains('-')) {
                dayComponent = dayComponent.split('-')[0];
              }
              exams.add(_createExamSchedule(seatingData, '$dayComponent-$month-$year', session, time));
            }
          }
        } else {
          exams.add(_createExamSchedule(seatingData, datePart, session, time));
        }
      }
    } catch (e) {
      exams.add(_createExamSchedule(seatingData, seatingData.date, 'Session', 'Time TBA'));
    }
    return exams;
  }

  ExamSchedule _createExamSchedule(SeatingData data, String dateStr, String session, String time) {
    return ExamSchedule(
      date: _formatDate(dateStr),
      day: _getDayOfWeek(dateStr),
      session: session,
      time: time,
      seatNo: data.seatNo,
      venue: data.block,
      status: 'Allocated',
      department: data.department,
      section: data.section,
      block: _parseBlockDetails(data.block),
      classroom: _parseClassroomDetails(data.block),
      floor: _parseFloorDetails(data.block),
      building: _parseBuildingDetails(data.block),
    );
  }

  String _parseBlockDetails(String block) {
    if (block.contains('Arts Block')) return 'Arts Block';
    if (block.contains('Science Block')) return 'Science Block';
    if (block.contains('Main Block')) return 'Main Block';
    if (block.contains('Golden Jubilee')) return 'Golden Jubilee Building';
    return 'Block';
  }

  String _parseClassroomDetails(String block) {
    final regex = RegExp(r'[A-Z]-?\d+');
    final match = regex.firstMatch(block);
    return match?.group(0) ?? 'Not Specified';
  }

  String _parseFloorDetails(String block) {
    if (block.contains('Ground Floor')) return 'Ground Floor';
    final floorRegex = RegExp(r'(\d+)(?:st|nd|rd|th) Floor');
    final match = floorRegex.firstMatch(block);
    return match != null ? '${match.group(1)} Floor' : 'Floor info not available';
  }

  String _parseBuildingDetails(String block) {
    if (block.contains('Arts')) return 'Arts Building';
    if (block.contains('Science')) return 'Science Building';
    if (block.contains('Main')) return 'Main Building';
    if (block.contains('Golden Jubilee')) return 'Golden Jubilee Building';
    return 'Academic Building';
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        const months = {'01':'Jan','02':'Feb','03':'Mar','04':'Apr','05':'May','06':'Jun','07':'Jul','08':'Aug','09':'Sep','10':'Oct','11':'Nov','12':'Dec'};
        return '${months[parts[1]]} ${int.parse(parts[0])}, ${parts[2]}';
      }
    } catch (_) {}
    return dateStr;
  }

  String _getDayOfWeek(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  DateTime _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 3) {
        const months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
        final month = months[parts[0]] ?? 1;
        final day = int.parse(parts[1].replaceAll(',', ''));
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.now();
  }
}

// ─── DATA MODELS ────────────────────────────────────────────────────────────
class SeatingArrangementResponse {
  final bool success;
  final String message;
  final List<SeatingData> data;
  SeatingArrangementResponse({required this.success, required this.message, required this.data});
  factory SeatingArrangementResponse.fromJson(Map<String, dynamic> json) {
    return SeatingArrangementResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List? ?? []).map((item) => SeatingData.fromJson(item)).toList(),
    );
  }
}

class SeatingData {
  final String id;
  final String session;
  final String seatNo;
  final String rollNo;
  final String block;
  final String department;
  final String section;
  final String date;
  SeatingData({required this.id, required this.session, required this.seatNo, required this.rollNo, required this.block, required this.department, required this.section, required this.date});
  factory SeatingData.fromJson(Map<String, dynamic> json) {
    return SeatingData(
      id: json['_id'] ?? '',
      session: json['Session'] ?? '',
      seatNo: json['Seat_No'] ?? '',
      rollNo: json['Roll_No'] ?? '',
      block: json['Block'] ?? '',
      department: json['Department'] ?? '',
      section: json['Section'] ?? '',
      date: json['Date'] ?? '',
    );
  }
}

class ExamSchedule {
  final String date;
  final String day;
  final String session;
  final String time;
  final String seatNo;
  final String venue;
  final String status;
  final String department;
  final String section;
  final String block;
  final String classroom;
  final String floor;
  final String building;
  const ExamSchedule({required this.date, required this.day, required this.session, required this.time, required this.seatNo, required this.venue, required this.status, required this.department, required this.section, required this.block, required this.classroom, required this.floor, required this.building});
}