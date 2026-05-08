import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum EventType { exam, holiday, academic, staff, student, department }

extension EventTypeExtension on EventType {
  Color color(ThemeProvider t) {
    switch (this) {
      case EventType.exam:
        return t.pink;
      case EventType.holiday:
        return t.amber;
      case EventType.academic:
        return t.cyan;
      case EventType.staff:
        return t.violet;
      case EventType.student:
        return t.green;
      case EventType.department:
        return t.cyanDim;
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.exam:
        return Icons.assignment_rounded;
      case EventType.holiday:
        return Icons.celebration_rounded;
      case EventType.academic:
        return Icons.school_rounded;
      case EventType.staff:
        return Icons.people_rounded;
      case EventType.student:
        return Icons.person_rounded;
      case EventType.department:
        return Icons.business_rounded;
    }
  }

  String get label {
    switch (this) {
      case EventType.exam:
        return 'Exam';
      case EventType.holiday:
        return 'Holiday';
      case EventType.academic:
        return 'Academic';
      case EventType.staff:
        return 'Staff';
      case EventType.student:
        return 'Student';
      case EventType.department:
        return 'Dept';
    }
  }
}

class CalendarEvent {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final EventType type;
  final String description;
  final String rawEventType;

  const CalendarEvent({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.description = '',
    this.rawEventType = '',
  });

  bool get isMultiDay => endDate.difference(startDate).inDays > 0;
  int get durationDays => endDate.difference(startDate).inDays + 1;
}

// ─── Custom Painters ─────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const spacing = 28.0;
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
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AcademicCalendarScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;
  const AcademicCalendarScreen({
    super.key,
    this.rollNo = '',
    this.studentName = '',
  });
  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen>
    with TickerProviderStateMixin {
  // ── View modes
  static const int _viewCalendar = 0;
  static const int _viewTimeline = 1;
  static const int _viewStats = 2;
  int _currentView = _viewCalendar;

  // ── State
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _isLoading = true;
  String? _errorMessage;
  String _loadingStep = 'Connecting…';
  Map<String, dynamic>? _calendarData;
  List<CalendarEvent> _events = [];
  EventType? _activeFilter;
  String? _studentName;
  String _rollNo = '';

  // ── Anim controllers
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _appBarGlow;
  late List<Animation<double>> _stagger;
  late Animation<double> _fadeAnim;

  // ── API
  static const String _baseUrl = 'https://apierp.bhc.edu.in';
  static const String _referer = 'http://117.232.64.75';

  String get _academicYear {
    final now = DateTime.now();
    final s = now.month >= 6 ? now.year : now.year - 1;
    return '$s-${s + 1}';
  }

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _stagger = List.generate(
      12,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.07, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStudentName();
    _fetchCalendarData();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _glowCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }


Future<void> _loadStudentName() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _studentName = prefs.getString('studentName') ?? widget.studentName;
    _rollNo = prefs.getString('rollNo') ?? widget.rollNo;
  });
}

  // ─── FETCH ────────────────────────────────────────────────────────────────

  Future<void> _fetchCalendarData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _events = [];
    });

    final headers = {
      'Referer': _referer,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final candidates = [
      '$_baseUrl/api/academic_calendar/$_academicYear',
      '$_baseUrl/api/academic_calendar',
      '$_baseUrl/academic_calendar/$_academicYear',
    ];

    Map<String, dynamic>? parsed;
    String? lastError;

    for (final url in candidates) {
      if (!mounted) return;
      setState(() => _loadingStep = 'Fetching ${url.split('/').last}…');
      try {
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200) {
          parsed = _extract(jsonDecode(resp.body));
          if (parsed != null) break;
        }
        lastError = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (!mounted) return;
    if (parsed != null) {
      _calendarData = parsed;
      _processData();
      setState(() => _isLoading = false);
      _fadeCtrl.forward(from: 0);
      _staggerCtrl.forward();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load academic calendar.\n\nLast error: $lastError';
      });
    }
  }

  Map<String, dynamic>? _extract(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>)
        return body['data'];
      if (body.containsKey('sem_odd') || body.containsKey('sem_even'))
        return body;
    }
    if (body is List && body.isNotEmpty) {
      final f = body[0];
      if (f is Map<String, dynamic> &&
          (f.containsKey('sem_odd') || f.containsKey('sem_even')))
        return f;
    }
    return null;
  }

  void _processData() {
    if (_calendarData == null) return;
    final List<CalendarEvent> all = [];
    final odd = _calendarData!['sem_odd'] as Map<String, dynamic>?;
    final even = _calendarData!['sem_even'] as Map<String, dynamic>?;
    if (odd != null) _parseSem(odd, all);
    if (even != null) _parseSem(even, all);
    all.sort((a, b) => a.startDate.compareTo(b.startDate));
    setState(() => _events = all);
  }

  void _parseSem(Map<String, dynamic> sem, List<CalendarEvent> out) {
    for (final h in (sem['holidays'] as List? ?? [])) {
      _addEvent(
        h,
        EventType.holiday,
        out,
        rawType: h['holidayType']?.toString() ?? '',
      );
    }
    for (final e in (sem['events'] as List? ?? [])) {
      final raw = (e['eventType'] as String? ?? '').toLowerCase();
      EventType type;
      if (raw.contains('staff'))
        type = EventType.staff;
      else if (raw.contains('student'))
        type = EventType.student;
      else if (raw.contains('dept'))
        type = EventType.department;
      else
        type = EventType.academic;
      _addEvent(e, type, out, rawType: e['eventType']?.toString() ?? '');
    }
    final exams = sem['exams'] as Map<String, dynamic>? ?? {};
    exams.forEach((key, val) {
      if (val != null && val is Map<String, dynamic>) {
        _addEvent(
          val,
          EventType.exam,
          out,
          rawType: 'exam',
          fallback: _examTitle(key),
        );
      }
    });
  }

  void _addEvent(
    dynamic src,
    EventType type,
    List<CalendarEvent> out, {
    String rawType = '',
    String fallback = '',
  }) {
    try {
      final startRaw = src['startDate'] as String?;
      if (startRaw == null) return;
      final endRaw = src['endDate'] as String?;
      final start = _parseDate(startRaw);
      final end = endRaw != null ? _parseDate(endRaw) : start;
      String title = (src['title'] as String?)?.trim() ?? fallback;
      if (title.isEmpty) title = '${type.label} Event';
      out.add(
        CalendarEvent(
          title: title,
          startDate: start,
          endDate: end,
          type: type,
          description: (src['description'] as String? ?? '').trim(),
          rawEventType: rawType,
        ),
      );
    } catch (_) {}
  }

  DateTime _parseDate(String s) {
    try {
      final utc = DateTime.parse(s).toUtc();
      final ist = utc.add(const Duration(hours: 5, minutes: 30));
      return DateTime(ist.year, ist.month, ist.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _examTitle(String key) {
    switch (key) {
      case 'internal1':
        return 'Internal Test – I';
      case 'internal2':
        return 'Internal Test – II';
      case 'practical':
        return 'Practical Examinations';
      case 'ese':
        return 'End Semester Examinations';
      default:
        return 'Examination';
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsForDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return _events
        .where((e) => !day.isBefore(e.startDate) && !day.isAfter(e.endDate))
        .toList();
  }

  List<CalendarEvent> get _filtered => _activeFilter == null
      ? _events
      : _events.where((e) => e.type == _activeFilter).toList();

  List<CalendarEvent> get _upcoming {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _events
        .where((e) => e.type == EventType.exam && !e.endDate.isBefore(today))
        .toList();
  }

  String _dateRange(CalendarEvent e) => _sameDay(e.startDate, e.endDate)
      ? DateFormat('dd MMM yyyy').format(e.startDate)
      : '${DateFormat('dd MMM').format(e.startDate)} – ${DateFormat('dd MMM yyyy').format(e.endDate)}';

  Widget _staggered(int i, Widget w) => FadeTransition(
    opacity: _stagger[i],
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(_stagger[i]),
      child: w,
    ),
  );

  // ─── FUTURISTIC APP BAR (CYAN PRIMARY) ─────────────────────────────────
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
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Academic Calendar",
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _academicYear,
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
                          "CALENDAR",
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
                  // IconButton(
                  //   icon: Icon(
                  //     Icons.refresh_rounded,
                  //     color: c.textMid,
                  //     size: 20,
                  //   ),
                  //   onPressed: _fetchCalendarData,
                  // ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
     drawer: CustomDrawer(
  rollNo: _rollNo,
  studentName: _studentName ?? '',
  currentRoute: '/calendar',
),
      appBar: _buildFuturisticAppBar(c),
      body: _isLoading
          ? _buildLoading(c)
          : _errorMessage != null
          ? _buildError(c)
          : FadeTransition(opacity: _fadeAnim, child: _buildBody(c)),
    );
  }

  // ─── BODY ────────────────────────────────────────────────────────────────

  Widget _buildBody(ThemeProvider c) {
    return Column(
      children: [
        _buildViewToggle(c),
        Expanded(
          child: IndexedStack(
            index: _currentView,
            children: [
              _buildCalendarView(c),
              _buildTimelineView(c),
              _buildStatsView(c),
            ],
          ),
        ),
      ],
    );
  }

  // ─── VIEW TOGGLE ─────────────────────────────────────────────────────────

  Widget _buildViewToggle(ThemeProvider c) {
    final tabs = [
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Calendar',
        'color': c.cyan,
      },
      {'icon': Icons.timeline_rounded, 'label': 'Timeline', 'color': c.violet},
      {'icon': Icons.analytics_rounded, 'label': 'Stats', 'color': c.green},
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _currentView == i;
          final color = tabs[i]['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(color: color.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i]['icon'] as IconData,
                      size: 14,
                      color: isActive ? color : c.textLow,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i]['label'] as String,
                      style: TextStyle(
                        color: isActive ? color : c.textLow,
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 1: CALENDAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCalendarView(ThemeProvider c) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _staggered(0, _buildAcademicYearBanner(c)),
          const SizedBox(height: 12),
          _staggered(1, _buildCalendarCard(c)),
          const SizedBox(height: 12),
          _staggered(2, _buildSelectedDayPanel(c)),
          const SizedBox(height: 12),
          _staggered(3, _buildFilterRow(c)),
          const SizedBox(height: 12),
          if (_upcoming.isNotEmpty) _staggered(4, _buildUpcomingExams(c)),
          const SizedBox(height: 12),
          _staggered(5, _buildMonthEvents(c)),
        ],
      ),
    );
  }

  // ─── Academic Year Banner ─────────────────────────────────────────────────

  Widget _buildAcademicYearBanner(ThemeProvider c) {
    final odd = _calendarData?['sem_odd'] as Map<String, dynamic>?;
    final even = _calendarData?['sem_even'] as Map<String, dynamic>?;
    final ay = _calendarData?['academicYear'] ?? _academicYear;

    String oddRange = 'Not scheduled', evenRange = 'Not scheduled';
    if (odd?['startDate'] != null && odd?['endDate'] != null) {
      try {
        final s = _parseDate(odd!['startDate']);
        final e = _parseDate(odd['endDate']);
        oddRange =
            '${DateFormat('MMM yyyy').format(s)} – ${DateFormat('MMM yyyy').format(e)}';
      } catch (_) {}
    }
    if (even?['startDate'] != null && even?['endDate'] != null) {
      try {
        final s = _parseDate(even!['startDate']);
        final e = _parseDate(even['endDate']);
        evenRange =
            '${DateFormat('MMM yyyy').format(s)} – ${DateFormat('MMM yyyy').format(e)}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.07), blurRadius: 24)],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _GridPainter(color: c.cyan.withOpacity(0.03)),
              size: const Size(double.infinity, 120),
            ),
          ),
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Positioned(
              top: -30 + _glowCtrl.value * 10,
              right: 10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.cyan.withOpacity(0.06 + _glowCtrl.value * 0.03),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        c.cyan.withOpacity(0.3),
                        c.violet.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(
                      color: c.cyan.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, color: c.cyan, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        'AY',
                        style: TextStyle(
                          color: c.cyan,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Academic Year $ay',
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _semLine(c, 'Odd', oddRange, c.amber),
                      const SizedBox(height: 4),
                      _semLine(c, 'Even', evenRange, c.green),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.cyan.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_events.length}',
                        style: TextStyle(
                          color: c.cyan,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: c.cyan.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'EVENTS',
                        style: TextStyle(
                          color: c.textLow,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// academic_calendar.dart ~line 460
Widget _semLine(ThemeProvider c, String label, String range, Color color) {
  return Row(
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 7),
      Text('$label: ', style: TextStyle(color: c.textMid, fontSize: 10, fontWeight: FontWeight.w600)),
      Flexible( // WAS: Expanded — caused overflow
        child: Text(
          range,
          style: TextStyle(color: c.textHigh, fontSize: 10, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    ],
  );
}

  // ─── Calendar Card ────────────────────────────────────────────────────────

  Widget _buildCalendarCard(ThemeProvider c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          _buildMonthHeader(c),
          _buildWeekdayLabels(c),
          _buildDayGrid(c),
          _buildLegend(c),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: c.cyan.withOpacity(0.04),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          _monthNavBtn(c, Icons.chevron_left_rounded, () {
            setState(
              () => _currentMonth = DateTime(
                _currentMonth.year,
                _currentMonth.month - 1,
              ),
            );
          }),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: TextStyle(
                    color: c.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_eventsForDate(_selectedDate).length} events on selected day',
                  style: TextStyle(color: c.textMid, fontSize: 10),
                ),
              ],
            ),
          ),
          _monthNavBtn(c, Icons.chevron_right_rounded, () {
            setState(
              () => _currentMonth = DateTime(
                _currentMonth.year,
                _currentMonth.month + 1,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _monthNavBtn(ThemeProvider c, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, color: c.textMid, size: 20),
      ),
    );
  }

  Widget _buildWeekdayLabels(ThemeProvider c) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Text(
              days[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: i == 0 ? c.pink.withOpacity(0.7) : c.textLow,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayGrid(ThemeProvider c) {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final last = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWd = first.weekday % 7;
    final rows = ((startWd + last.day) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startWd + 1;
              if (day < 1 || day > last.day)
                return const Expanded(child: SizedBox(height: 48));

              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );
              final isToday = _sameDay(date, DateTime.now());
              final isSelected = _sameDay(date, _selectedDate);
              final dayEvts = _eventsForDate(date);
              final isSun = col == 0;

              Color? dominantColor;
              if (dayEvts.isNotEmpty)
                dominantColor = dayEvts.first.type.color(c);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: [c.cyan, c.violet])
                          : null,
                      color: (isToday && !isSelected)
                          ? c.cyan.withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? null
                          : isToday
                          ? Border.all(color: c.cyan, width: 1.5)
                          : dayEvts.isNotEmpty
                          ? Border.all(color: dominantColor!.withOpacity(0.25))
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: c.cyan.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : isSun
                                  ? c.pink.withOpacity(0.8)
                                  : c.textHigh,
                            ),
                          ),
                        ),
                        if (dayEvts.isNotEmpty)
                          Positioned(
                            bottom: 5,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dayEvts
                                  .take(3)
                                  .map(
                                    (e) => Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.8)
                                            : e.type.color(c),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildLegend(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: EventType.values.map((t) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: t.color(c),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 9,
                  color: c.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Selected Day Panel ───────────────────────────────────────────────────

  Widget _buildSelectedDayPanel(ThemeProvider c) {
    final dayEvents = _eventsForDate(_selectedDate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dayEvents.isNotEmpty
              ? dayEvents.first.type.color(c).withOpacity(0.25)
              : c.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.elevated.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.cyan.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.event_rounded, color: c.cyan, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                    style: TextStyle(
                      color: c.textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.cyan.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${dayEvents.length}',
                      style: TextStyle(
                        color: c.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          dayEvents.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 28,
                        color: c.textLow,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'No events on this day',
                        style: TextStyle(color: c.textMid, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: dayEvents.map((e) => _eventTile(c, e)).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  // ─── Filter Row ───────────────────────────────────────────────────────────

  Widget _buildFilterRow(ThemeProvider c) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip(c, null, 'All', c.cyan),
          ...EventType.values.map(
            (t) => _filterChip(c, t, t.label, t.color(c)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    ThemeProvider c,
    EventType? type,
    String label,
    Color color,
  ) {
    final isActive = _activeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : c.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? color : c.textMid,
          ),
        ),
      ),
    );
  }

  // ─── Upcoming Exams ───────────────────────────────────────────────────────

  Widget _buildUpcomingExams(ThemeProvider c) {
    return _sectionCard(
      c,
      title: 'Upcoming Exams',
      icon: Icons.assignment_rounded,
      color: c.pink,
      child: Column(children: _upcoming.map((e) => _eventTile(c, e)).toList()),
    );
  }

  // ─── Month Events ─────────────────────────────────────────────────────────

  Widget _buildMonthEvents(ThemeProvider c) {
    final month = _filtered
        .where(
          (e) =>
              e.startDate.year == _currentMonth.year &&
              e.startDate.month == _currentMonth.month,
        )
        .toList();

    if (month.isEmpty) {
      return _sectionCard(
        c,
        title: '${DateFormat('MMMM yyyy').format(_currentMonth)} Events',
        icon: Icons.calendar_month_rounded,
        color: c.cyan,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No events this month',
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final grouped = <String, List<CalendarEvent>>{};
    for (final e in month) {
      final k = DateFormat('yyyy-MM-dd').format(e.startDate);
      grouped.putIfAbsent(k, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return _sectionCard(
      c,
      title:
          '${DateFormat('MMMM yyyy').format(_currentMonth)} Events (${month.length})',
      icon: Icons.calendar_month_rounded,
      color: c.cyan,
      child: Column(
        children: sortedKeys.map((key) {
          final date = DateTime.parse(key);
          final events = grouped[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.cyan.withOpacity(0.2)),
                      ),
                      child: Text(
                        DateFormat('EEE, d MMM').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: c.cyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(height: 1, color: c.border)),
                  ],
                ),
              ),
              ...events.map((e) => _eventTile(c, e)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 2: TIMELINE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTimelineView(ThemeProvider c) {
    final now = DateTime.now();
    final all = _filtered.toList();

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_rounded, size: 48, color: c.textLow),
            const SizedBox(height: 12),
            Text(
              'No events to display',
              style: TextStyle(color: c.textMid, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<CalendarEvent>>{};
    for (final e in all) {
      final k = DateFormat('yyyy-MM').format(e.startDate);
      grouped.putIfAbsent(k, () => []).add(e);
    }
    final sortedMonths = grouped.keys.toList()..sort();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        children: [
          _buildFilterRow(c),
          const SizedBox(height: 16),
          ...sortedMonths.map((monthKey) {
            final monthDate = DateTime.parse('$monthKey-01');
            final monthEvents = grouped[monthKey]!;
            final isCurrent =
                monthDate.year == now.year && monthDate.month == now.month;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isCurrent
                              ? LinearGradient(colors: [c.cyan, c.violet])
                              : null,
                          color: isCurrent ? null : c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? Colors.transparent : c.border,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: c.cyan.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy').format(monthDate),
                          style: TextStyle(
                            color: isCurrent ? Colors.white : c.textHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.elevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${monthEvents.length}',
                          style: TextStyle(
                            color: c.textMid,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Divider(color: c.border)),
                    ],
                  ),
                ),
                ...monthEvents.asMap().entries.map((entry) {
                  final i = entry.key;
                  final event = entry.value;
                  final isLast = i == monthEvents.length - 1;
                  return _buildTimelineTile(c, event, isLast, isCurrent);
                }),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineTile(
    ThemeProvider c,
    CalendarEvent event,
    bool isLast,
    bool isCurrentMonth,
  ) {
    final color = event.type.color(c);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isOngoing =
        !event.startDate.isAfter(today) && !event.endDate.isBefore(today);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedBuilder(
              animation: isOngoing
                  ? _pulseCtrl
                  : const AlwaysStoppedAnimation(0),
              builder: (_, __) => Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOngoing
                      ? color.withOpacity(0.15 + _pulseCtrl.value * 0.1)
                      : color.withOpacity(0.12),
                  border: Border.all(
                    color: color.withOpacity(0.5),
                    width: isOngoing ? 2 : 1,
                  ),
                  boxShadow: isOngoing
                      ? [
                          BoxShadow(
                            color: color.withOpacity(
                              0.3 + _pulseCtrl.value * 0.2,
                            ),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(event.type.icon, color: color, size: 14),
              ),
            ),
            if (!isLast) Container(width: 1.5, height: 20, color: c.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(isOngoing ? 0.4 : 0.2),
                width: isOngoing ? 1.5 : 1,
              ),
              boxShadow: isOngoing
                  ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          'NOW',
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.type.label.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 10,
                      color: c.textLow,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dateRange(event),
                      style: TextStyle(
                        color: c.textMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (event.isMultiDay) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.elevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${event.durationDays}d',
                          style: TextStyle(
                            color: c.textLow,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 3: STATS (simplified)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsView(ThemeProvider c) {
    final counts = <EventType, int>{};
    for (final t in EventType.values) {
      counts[t] = _events.where((e) => e.type == t).length;
    }
    final total = _events.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [_staggered(0, _buildEventTypeBreakdown(c, counts, total))],
      ),
    );
  }

  Widget _buildEventTypeBreakdown(
    ThemeProvider c,
    Map<EventType, int> counts,
    int total,
  ) {
    return _sectionCard(
      c,
      title: 'EVENT BREAKDOWN',
      icon: Icons.donut_large_rounded,
      color: c.violet,
      child: Column(
        children: EventType.values.map((type) {
          final count = counts[type] ?? 0;
          if (count == 0) return const SizedBox();
          final pct = total > 0 ? count / total : 0.0;
          final color = type.color(c);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Icon(type.icon, color: color, size: 13),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        type.label,
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$count events',
                      style: TextStyle(color: c.textMid, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SHARED COMPONENTS ────────────────────────────────────────────────────

  Widget _eventTile(ThemeProvider c, CalendarEvent event) {
    final color = event.type.color(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 9,
                      color: c.textLow,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dateRange(event),
                      style: TextStyle(fontSize: 10, color: c.textMid),
                    ),
                    if (event.isMultiDay) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${event.durationDays}d',
                        style: TextStyle(
                          fontSize: 10,
                          color: c.textLow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(
              event.type.label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    ThemeProvider c, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.textHigh,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ─── LOADING / ERROR ─────────────────────────────────────────────────────

  Widget _buildLoading(ThemeProvider c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.cyan.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: c.cyan.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: c.cyan.withOpacity(0.15 + _pulseCtrl.value * 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.cyan,
                    backgroundColor: c.cyan.withOpacity(0.1),
                  ),
                  Icon(
                    Icons.event_rounded,
                    color: c.cyan.withOpacity(0.6),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Calendar…',
            style: TextStyle(
              color: c.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(_loadingStep, style: TextStyle(color: c.textLow, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildError(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.pink.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: c.pink.withOpacity(0.3)),
              ),
              child: Icon(Icons.wifi_off_rounded, color: c.pink, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Calendar',
              style: TextStyle(
                color: c.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCalendarData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.cyan.withOpacity(0.15),
                foregroundColor: c.cyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: c.cyan),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DATA MODEL ───────────────────────────────────────────────────────────────

class _StatItem {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatItem(this.label, this.value, this.color, this.icon);
}
