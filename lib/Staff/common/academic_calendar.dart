// academic_calendar_screen.dart — Futuristic Staff ERP Design

import 'dart:convert';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import '../theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum EventType { exam, holiday, academic, staff, student, department }

extension EventTypeExtension on EventType {
  Color color(StaffThemeProvider theme) {
    switch (this) {
      case EventType.exam:       return theme.pink;
      case EventType.holiday:    return theme.amber;
      case EventType.academic:   return theme.cyan;
      case EventType.staff:      return theme.violet;
      case EventType.student:    return theme.green;
      case EventType.department: return theme.cyanDim;
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.exam:       return Icons.assignment_rounded;
      case EventType.holiday:    return Icons.celebration_rounded;
      case EventType.academic:   return Icons.school_rounded;
      case EventType.staff:      return Icons.people_rounded;
      case EventType.student:    return Icons.person_rounded;
      case EventType.department: return Icons.business_rounded;
    }
  }

  String get label {
    switch (this) {
      case EventType.exam:       return 'Exam';
      case EventType.holiday:    return 'Holiday';
      case EventType.academic:   return 'Academic';
      case EventType.staff:      return 'Staff';
      case EventType.student:    return 'Student';
      case EventType.department: return 'Dept';
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

// ─── Custom Painter ─────────────────────────────────────────────────────────

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
  const AcademicCalendarScreen({super.key, required String rollNo, required String studentName});

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
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;
  String? _errorMessage;
  String _loadingStep = 'Connecting…';
  Map<String, dynamic>? _calendarData;
  List<CalendarEvent> _events = [];
  EventType? _activeFilter;

  // ── Animations
  late AnimationController _appBarGlow;
  late AnimationController _pageEnterCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  // ── API
  static const String _baseUrl = 'https://apierp.bhc.edu.in';
  static const String _referer = 'http://117.232.64.75';

  String get _academicYear {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchCalendarData();
    _pageEnterCtrl.forward();
    _staggerCtrl.forward();
  }

  void _initAnimations() {
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _stagger = List.generate(
      8,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pageFade = CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageEnterCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(_stagger[i]),
          child: child,
        ),
      );

  DateTime _parseDate(String dateStr) {
    try {
      DateTime utcDate = DateTime.parse(dateStr).toUtc();
      DateTime istDate = utcDate.add(const Duration(hours: 5, minutes: 30));
      return DateTime(istDate.year, istDate.month, istDate.day);
    } catch (e) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  String _formatDateShort(DateTime date) => DateFormat('dd MMM').format(date);

  // ── FETCH ────────────────────────────────────────────────────────────────

  Future<void> _fetchCalendarData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _events = [];
      _loadingStep = 'Connecting…';
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
          parsed = _extractCalendarMap(jsonDecode(resp.body));
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
      _processCalendarData();
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load academic calendar.\n\nLast error: $lastError';
      });
    }
  }

  Map<String, dynamic>? _extractCalendarMap(dynamic body) {
    try {
      if (body is Map<String, dynamic>) {
        if (body['success'] == true && body['data'] is Map<String, dynamic>) {
          return body['data'];
        }
        if (body.containsKey('academicYear') && 
            (body.containsKey('sem_odd') || body.containsKey('sem_even'))) {
          return body;
        }
      }
      if (body is List && body.isNotEmpty) {
        final first = body[0];
        if (first is Map<String, dynamic> &&
            (first.containsKey('academicYear') ||
             first.containsKey('sem_odd') ||
             first.containsKey('sem_even'))) {
          return first;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _processCalendarData() {
    if (_calendarData == null) return;
    final List<CalendarEvent> all = [];

    final odd = _calendarData!['sem_odd'] as Map<String, dynamic>?;
    final even = _calendarData!['sem_even'] as Map<String, dynamic>?;

    if (odd != null) _parseSemester(odd, all);
    if (even != null) _parseSemester(even, all);

    all.sort((a, b) => a.startDate.compareTo(b.startDate));
    setState(() => _events = all);
  }

  void _parseSemester(Map<String, dynamic> sem, List<CalendarEvent> out) {
    for (final h in (sem['holidays'] as List? ?? [])) {
      _addEvent(h, EventType.holiday, out,
          rawType: h['holidayType']?.toString() ?? '');
    }
    for (final e in (sem['events'] as List? ?? [])) {
      final raw = (e['eventType'] as String? ?? '').toLowerCase();
      EventType type;
      if (raw.contains('staff')) type = EventType.staff;
      else if (raw.contains('student')) type = EventType.student;
      else if (raw.contains('dept')) type = EventType.department;
      else type = EventType.academic;
      _addEvent(e, type, out, rawType: e['eventType']?.toString() ?? '');
    }
    final exams = sem['exams'] as Map<String, dynamic>? ?? {};
    exams.forEach((key, val) {
      if (val != null && val is Map<String, dynamic>) {
        _addEvent(val, EventType.exam, out,
            rawType: 'exam', fallbackTitle: _examTitle(key));
      }
    });
  }

  void _addEvent(
    dynamic src,
    EventType type,
    List<CalendarEvent> out, {
    String rawType = '',
    String fallbackTitle = '',
  }) {
    try {
      final startRaw = src['startDate'] as String?;
      if (startRaw == null) return;
      final endRaw = src['endDate'] as String?;
      final start = _parseDate(startRaw);
      final end = endRaw != null ? _parseDate(endRaw) : start;
      String title = (src['title'] as String?)?.trim() ?? fallbackTitle;
      if (title.isEmpty) title = '${type.label} Event';
      out.add(CalendarEvent(
        title: title,
        startDate: start,
        endDate: end,
        type: type,
        description: (src['description'] as String? ?? '').trim(),
        rawEventType: rawType,
      ));
    } catch (_) {}
  }

  String _examTitle(String key) {
    switch (key) {
      case 'internal1': return 'Internal Test – I';
      case 'internal2': return 'Internal Test – II';
      case 'practical': return 'Practical Examinations';
      case 'ese': return 'End Semester Examinations';
      default: return 'Examination';
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
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _events
        .where((e) => e.type == EventType.exam && !e.endDate.isBefore(today))
        .toList();
  }

  String _dateRange(CalendarEvent e) => _sameDay(e.startDate, e.endDate)
      ? _formatDate(e.startDate)
      : '${_formatDateShort(e.startDate)} – ${_formatDate(e.endDate)}';

  // ─── FUTURISTIC APP BAR ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
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
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: theme.cyan.withOpacity(0.3), blurRadius: 10)
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.elevated,
                          child: Icon(Icons.calendar_month_rounded,
                              color: theme.cyan, size: 16),
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
                          "Academic Calendar",
                          style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _academicYear,
                          style: TextStyle(
                            color: theme.cyan.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cyan,
                            boxShadow: [
                              BoxShadow(
                                  color: theme.cyan.withOpacity(0.6),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${_events.length}",
                          style: TextStyle(
                            color: theme.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: theme.textMid, size: 20),
                    onPressed: _fetchCalendarData,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── VIEW TOGGLE ─────────────────────────────────────────────────────────
  Widget _buildViewToggle(StaffThemeProvider theme) {
    final tabs = [
      {'icon': Icons.calendar_month_rounded, 'label': 'Calendar', 'color': theme.cyan},
      {'icon': Icons.timeline_rounded, 'label': 'Timeline', 'color': theme.violet},
      {'icon': Icons.analytics_rounded, 'label': 'Stats', 'color': theme.green},
    ];
    return _animated(
      0,
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
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
                    color: isActive ? color.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isActive ? Border.all(color: color.withOpacity(0.3)) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tabs[i]['icon'] as IconData, size: 14,
                          color: isActive ? color : theme.textLow),
                      const SizedBox(width: 6),
                      Text(tabs[i]['label'] as String,
                          style: TextStyle(
                            color: isActive ? color : theme.textLow,
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 1: CALENDAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCalendarView(StaffThemeProvider theme) {
    final odd = _calendarData?['sem_odd'] as Map<String, dynamic>?;
    final even = _calendarData?['sem_even'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          _animated(1, _buildAcademicYearBanner(theme, odd, even)),
          const SizedBox(height: 12),
          _animated(2, _buildCalendarCard(theme)),
          const SizedBox(height: 12),
          _animated(3, _buildSelectedDayPanel(theme)),
          const SizedBox(height: 12),
          _animated(4, _buildFilterRow(theme)),
          const SizedBox(height: 12),
          if (_upcoming.isNotEmpty) _animated(5, _buildUpcomingExamsCard(theme)),
          const SizedBox(height: 12),
          _animated(6, _buildMonthEventsCard(theme)),
        ],
      ),
    );
  }

  Widget _buildAcademicYearBanner(StaffThemeProvider theme, Map<String, dynamic>? odd, Map<String, dynamic>? even) {
    final ay = _calendarData?['academicYear'] ?? _academicYear;
    
    String oddRange = 'Not scheduled', evenRange = 'Not scheduled';
    if (odd?['startDate'] != null && odd?['endDate'] != null) {
      try {
        final s = _parseDate(odd!['startDate']);
        final e = _parseDate(odd['endDate']);
        oddRange = '${DateFormat('MMM yyyy').format(s)} – ${DateFormat('MMM yyyy').format(e)}';
      } catch (_) {}
    }
    if (even?['startDate'] != null && even?['endDate'] != null) {
      try {
        final s = _parseDate(even!['startDate']);
        final e = _parseDate(even['endDate']);
        evenRange = '${DateFormat('MMM yyyy').format(s)} – ${DateFormat('MMM yyyy').format(e)}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.07), blurRadius: 24)],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _GridPainter(color: theme.cyan.withOpacity(0.03)),
              size: const Size(double.infinity, 120),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                    boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Academic Year $ay',
                          style: TextStyle(color: theme.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      _semLine(theme, 'Odd Semester', oddRange, theme.amber),
                      const SizedBox(height: 3),
                      _semLine(theme, 'Even Semester', evenRange, theme.green),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cyan.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('${_events.length}',
                          style: TextStyle(
                            color: theme.cyan,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: theme.cyan.withOpacity(0.4), blurRadius: 8)],
                          )),
                      Text('EVENTS', style: TextStyle(color: theme.textLow, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1)),
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

  Widget _semLine(StaffThemeProvider theme, String label, String range, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text('$label: ', style: TextStyle(color: theme.textMid, fontSize: 10, fontWeight: FontWeight.w600)),
        Flexible(
          child: Text(range,
              style: TextStyle(color: theme.textHigh, fontSize: 10, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(StaffThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        children: [
          _buildMonthHeader(theme),
          _buildWeekdayLabels(theme),
          _buildDayGrid(theme),
          _buildLegend(theme),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: theme.cyan.withOpacity(0.04),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          _monthNavBtn(theme, Icons.chevron_left_rounded, () {
            setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
          }),
          Expanded(
            child: Column(
              children: [
                Text(DateFormat('MMMM yyyy').format(_currentMonth),
                    style: TextStyle(color: theme.textHigh, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('${_eventsForDate(_selectedDate).length} events on selected day',
                    style: TextStyle(color: theme.textMid, fontSize: 10)),
              ],
            ),
          ),
          _monthNavBtn(theme, Icons.chevron_right_rounded, () {
            setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
          }),
        ],
      ),
    );
  }

  Widget _monthNavBtn(StaffThemeProvider theme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Icon(icon, color: theme.textMid, size: 20),
      ),
    );
  }

  Widget _buildWeekdayLabels(StaffThemeProvider theme) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: List.generate(7, (i) => Expanded(
          child: Text(days[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: i == 0 ? theme.pink.withOpacity(0.7) : theme.textLow,
                letterSpacing: 0.5,
              )),
        )),
      ),
    );
  }

  Widget _buildDayGrid(StaffThemeProvider theme) {
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
              if (day < 1 || day > last.day) return const Expanded(child: SizedBox(height: 48));
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = _sameDay(date, DateTime.now());
              final isSelected = _sameDay(date, _selectedDate);
              final dayEvts = _eventsForDate(date);
              final isSun = col == 0;

              Color? dominantColor;
              if (dayEvts.isNotEmpty) dominantColor = dayEvts.first.type.color(theme);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: isSelected ? LinearGradient(colors: [theme.cyan, theme.violet]) : null,
                      color: (isToday && !isSelected) ? theme.cyan.withOpacity(0.08) : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected ? null : isToday
                          ? Border.all(color: theme.cyan, width: 1.5)
                          : dayEvts.isNotEmpty
                              ? Border.all(color: dominantColor!.withOpacity(0.25))
                              : null,
                      boxShadow: isSelected ? [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 8)] : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text('$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : isSun ? theme.pink.withOpacity(0.8) : theme.textHigh,
                              )),
                        ),
                        if (dayEvts.isNotEmpty)
                          Positioned(
                            bottom: 5,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dayEvts.take(3).map((e) => Container(
                                width: 4, height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.8) : e.type.color(theme),
                                  shape: BoxShape.circle,
                                ),
                              )).toList(),
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

  Widget _buildLegend(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.border))),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: EventType.values.map((t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: t.color(theme), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text(t.label, style: TextStyle(fontSize: 9, color: theme.textMid, fontWeight: FontWeight.w600)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildSelectedDayPanel(StaffThemeProvider theme) {
    final dayEvents = _eventsForDate(_selectedDate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dayEvents.isNotEmpty ? dayEvents.first.type.color(theme).withOpacity(0.25) : theme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.elevated.withOpacity(0.5),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: theme.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.cyan.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.event_rounded, color: theme.cyan, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                      style: TextStyle(color: theme.textHigh, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                if (dayEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cyan.withOpacity(0.3)),
                    ),
                    child: Text('${dayEvents.length}',
                        style: TextStyle(color: theme.cyan, fontSize: 12, fontWeight: FontWeight.w800)),
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
                      Icon(Icons.event_available_rounded, size: 28, color: theme.textLow),
                      const SizedBox(width: 10),
                      Text('No events on this day', style: TextStyle(color: theme.textMid, fontSize: 13)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: dayEvents.map((e) => _eventTile(theme, e)).toList()),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(StaffThemeProvider theme) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip(theme, null, 'All', theme.cyan),
          ...EventType.values.map((t) => _filterChip(theme, t, t.label, t.color(theme))),
        ],
      ),
    );
  }

  Widget _filterChip(StaffThemeProvider theme, EventType? type, String label, Color color) {
    final isActive = _activeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color.withOpacity(0.5) : theme.border, width: isActive ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? color : theme.textMid)),
      ),
    );
  }

  Widget _buildUpcomingExamsCard(StaffThemeProvider theme) {
    return _sectionCard(
      theme,
      title: 'Upcoming Exams',
      icon: Icons.assignment_rounded,
      color: theme.pink,
      child: Column(children: _upcoming.map((e) => _eventTile(theme, e)).toList()),
    );
  }

  Widget _buildMonthEventsCard(StaffThemeProvider theme) {
    final month = _filtered.where((e) =>
        e.startDate.year == _currentMonth.year && e.startDate.month == _currentMonth.month).toList();

    if (month.isEmpty) {
      return _sectionCard(
        theme,
        title: '${DateFormat('MMMM yyyy').format(_currentMonth)} Events',
        icon: Icons.calendar_month_rounded,
        color: theme.cyan,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('No events this month', style: TextStyle(color: theme.textMid, fontSize: 13))),
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
      theme,
      title: '${DateFormat('MMMM yyyy').format(_currentMonth)} Events (${month.length})',
      icon: Icons.calendar_month_rounded,
      color: theme.cyan,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.cyan.withOpacity(0.2)),
                      ),
                      child: Text(DateFormat('EEE, d MMM').format(date),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.cyan)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(height: 1, color: theme.border)),
                  ],
                ),
              ),
              ...events.map((e) => _eventTile(theme, e)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 2: TIMELINE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTimelineView(StaffThemeProvider theme) {
    final all = _filtered.toList();
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_rounded, size: 48, color: theme.textLow),
            const SizedBox(height: 12),
            Text('No events to display', style: TextStyle(color: theme.textMid, fontSize: 14)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        children: all.map((e) => _buildTimelineTile(theme, e)).toList(),
      ),
    );
  }

  Widget _buildTimelineTile(StaffThemeProvider theme, CalendarEvent event) {
    final color = event.type.color(theme);
    final today = DateTime.now();
    final isOngoing = !event.startDate.isAfter(today) && !event.endDate.isBefore(today);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(isOngoing ? 0.4 : 0.2), width: isOngoing ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textHigh)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 10, color: theme.textLow),
                    const SizedBox(width: 4),
                    Text(_dateRange(event), style: TextStyle(fontSize: 11, color: theme.textMid)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(event.type.label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VIEW 3: STATS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsView(StaffThemeProvider theme) {
    final counts = <EventType, int>{};
    for (final t in EventType.values) {
      counts[t] = _events.where((e) => e.type == t).length;
    }
    final total = _events.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          _animated(0, _buildEventBreakdownCard(theme, counts, total)),
        ],
      ),
    );
  }

  Widget _buildEventBreakdownCard(StaffThemeProvider theme, Map<EventType, int> counts, int total) {
    return _sectionCard(
      theme,
      title: 'EVENT BREAKDOWN',
      icon: Icons.donut_large_rounded,
      color: theme.violet,
      child: Column(
        children: EventType.values.map((type) {
          final count = counts[type] ?? 0;
          if (count == 0) return const SizedBox();
          final pct = total > 0 ? count / total : 0.0;
          final color = type.color(theme);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Icon(type.icon, color: color, size: 13),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(type.label,
                          style: TextStyle(color: theme.textHigh, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Text('$count events', style: TextStyle(color: theme.textMid, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: theme.border,
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

  Widget _eventTile(StaffThemeProvider theme, CalendarEvent event) {
    final color = event.type.color(theme);
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
          Container(width: 3.5, height: 42,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textHigh)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 9, color: theme.textLow),
                    const SizedBox(width: 4),
                    Text(_dateRange(event), style: TextStyle(fontSize: 10, color: theme.textMid)),
                    if (event.isMultiDay) ...[
                      const SizedBox(width: 6),
                      Text('· ${event.durationDays}d',
                          style: TextStyle(fontSize: 10, color: theme.textLow, fontWeight: FontWeight.w700)),
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
            child: Text(event.type.label,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    StaffThemeProvider theme, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
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
                Text(title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: theme.textHigh, letterSpacing: 0.5)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.border),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ─── LOADING / ERROR ─────────────────────────────────────────────────────

  Widget _buildLoading(StaffThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.cyan),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loading Calendar…',
              style: TextStyle(color: theme.textMid, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_loadingStep, style: TextStyle(color: theme.textLow, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildError(StaffThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.pink.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: theme.pink.withOpacity(0.3)),
              ),
              child: Icon(Icons.wifi_off_rounded, color: theme.pink, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Unable to Load Calendar',
                style: TextStyle(color: theme.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textMid, fontSize: 12, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCalendarData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.cyan.withOpacity(0.15),
                foregroundColor: theme.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.cyan),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAIN BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<StaffThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bg,
      drawer: AppDrawer(
        isHod: _isHod,
        currentRoute: '/academic-calendar',
      ),
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? _buildLoading(theme)
          : _errorMessage != null
              ? _buildError(theme)
              : FadeTransition(
                  opacity: _pageFade,
                  child: SlideTransition(
                    position: _pageSlide,
                    child: Column(
                      children: [
                        _buildViewToggle(theme),
                        Expanded(
                          child: IndexedStack(
                            index: _currentView,
                            children: [
                              _buildCalendarView(theme),
                              _buildTimelineView(theme),
                              _buildStatsView(theme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}