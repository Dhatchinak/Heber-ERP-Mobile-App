import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MentorScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const MentorScreen({
    super.key,
    required this.rollNo,
    required this.studentName,
  });

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<dynamic> _sessionInfo = [];
  List<dynamic> _staffInfo = [];
  int _totalSessions = 0;
  String? _studentName;

  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _appBarGlow;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _stagger = List.generate(
      8,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _loadStudentName();
    _fetchMentorData();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    _studentName = prefs.getString('studentName') ?? widget.studentName;
    setState(() {});
  }

  Future<void> _fetchMentorData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final mentorUrl = Uri.parse(
        'https://apierp.bhc.edu.in/api/staff/mentorship/get_student_session/${widget.rollNo}',
      );

      final mentorResponse = await http
          .get(
            mentorUrl,
            headers: {
              'Referer': 'http://117.232.64.75',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (mentorResponse.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(
          mentorResponse.body,
        );
        if (responseData['success'] == true) {
          setState(() {
            _totalSessions = responseData['data']['total_sessions'] ?? 0;
            _sessionInfo = responseData['data']['session_info'] ?? [];
            _staffInfo = responseData['data']['staff_info'] ?? [];
          });
        } else {
          throw Exception('API returned success: false');
        }
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      if (!_hasError && mounted) _staggerCtrl.forward();
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown Date';
    try {
      final dateString = date.toString();
      if (dateString.contains('T')) {
        final datePart = dateString.split('T')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
      return dateString;
    } catch (e) {
      return date.toString();
    }
  }

  // ─── FUTURISTIC APP BAR (MATCHING DASHBOARD) ─────────────────────────────────
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
                        "Student Mentor",
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "Mentorship Program",
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
                      color: _staffInfo.isNotEmpty
                          ? c.green.withOpacity(0.1)
                          : c.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _staffInfo.isNotEmpty
                            ? c.green.withOpacity(0.3)
                            : c.amber.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _staffInfo.isNotEmpty ? c.green : c.amber,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_staffInfo.isNotEmpty ? c.green : c.amber)
                                        .withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _staffInfo.isNotEmpty ? "ASSIGNED" : "PENDING",
                          style: TextStyle(
                            color: _staffInfo.isNotEmpty ? c.green : c.amber,
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
                    onPressed: _fetchMentorData,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── MAIN BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: widget.rollNo,
        studentName: _studentName ?? widget.studentName,
        currentRoute: '/mentor',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: _isLoading
          ? _buildLoadingState(c)
          : _hasError
          ? _buildErrorState(c)
          : _totalSessions == 0 && _staffInfo.isEmpty
          ? _buildNoMentorState(c)
          : RefreshIndicator(
              onRefresh: _fetchMentorData,
              color: c.cyan,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _animated(0, _buildHeroBanner(c)),
                    const SizedBox(height: 16),
                    if (_staffInfo.isNotEmpty)
                      _animated(1, _buildMentorCard(c)),
                    const SizedBox(height: 16),
                    _animated(2, _buildSessionsSummary(c)),
                    const SizedBox(height: 16),
                    _animated(
                      3,
                      _sessionInfo.isNotEmpty
                          ? _buildSessionsList(c)
                          : _buildNoSessionsCard(c),
                    ),
                  ],
                ),
              ),
            ),
    );
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

  // ─── HERO BANNER (DASHBOARD STYLE WITH CYAN) ────────────────────────────
  Widget _buildHeroBanner(ThemeProvider c) {
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _GridPainter(color: c.cyan.withOpacity(0.03)),
              size: const Size(double.infinity, 160),
            ),
          ),
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
                      c.cyan.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                                    color: c.green,
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.green.withOpacity(
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
                                "MENTORSHIP",
                                style: TextStyle(
                                  color: c.cyan.withOpacity(0.7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _studentName?.split(' ').first ?? "Student",
                            style: TextStyle(
                              color: c.textHigh,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _staffInfo.isNotEmpty
                                ? "Mentor Assigned"
                                : "No Mentor Yet",
                            style: TextStyle(
                              color: c.textMid,
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
                        color: c.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.cyan.withOpacity(0.25)),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: c.cyan,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      c,
                      Icons.assignment_rounded,
                      "$_totalSessions Sessions",
                      c.cyan,
                    ),
                    _chip(
                      c,
                      Icons.check_circle_rounded,
                      "${_sessionInfo.length} Completed",
                      c.green,
                    ),
                    _chip(
                      c,
                      Icons.pending_rounded,
                      "${_sessionInfo.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'pending').length} Pending",
                      c.amber,
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

  Widget _chip(ThemeProvider c, IconData icon, String label, Color color) {
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

  // ─── MENTOR CARD (CYAN THEME) ───────────────────────────────────────────
  Widget _buildMentorCard(ThemeProvider c) {
    if (_staffInfo.isEmpty) return const SizedBox();
    final staff = _staffInfo[0];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.05),
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
                    color: c.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.supervisor_account_rounded,
                    color: c.cyan,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Your Mentor",
                  style: TextStyle(
                    color: c.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.cyan.withOpacity(0.3),
                        c.cyan.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.cyan.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      (staff['staff_name'] ?? 'M')[0].toUpperCase(),
                      style: TextStyle(
                        color: c.cyan,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
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
                        staff['staff_name'] ?? 'Not Available',
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staff['designation'] ?? 'Faculty',
                        style: TextStyle(
                          color: c.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _mentorInfoRow(
                  c,
                  Icons.business_center_rounded,
                  staff['department_name'] ?? 'Not Available',
                  c.violet,
                ),
                const SizedBox(height: 10),
                _mentorInfoRow(
                  c,
                  Icons.fingerprint_rounded,
                  staff['staff_id'] ?? 'N/A',
                  c.amber,
                ),
                if (staff['staff_email'] != null) ...[
                  const SizedBox(height: 10),
                  _mentorInfoRow(
                    c,
                    Icons.email_rounded,
                    staff['staff_email']!,
                    c.pink,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mentorInfoRow(
    ThemeProvider c,
    IconData icon,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: c.textMid,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── SESSIONS SUMMARY ────────────────────────────────────────────────────
  Widget _buildSessionsSummary(ThemeProvider c) {
    final completed = _sessionInfo
        .where(
          (s) => (s['status'] as String? ?? '').toLowerCase() == 'completed',
        )
        .length;
    final pending = _sessionInfo
        .where((s) => (s['status'] as String? ?? '').toLowerCase() == 'pending')
        .length;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.green.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: c.green.withOpacity(0.06), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.green.withOpacity(0.05),
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
                    color: c.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: c.green,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Session Overview",
                  style: TextStyle(
                    color: c.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryTile(
                        c,
                        "$_totalSessions",
                        "Total",
                        c.cyan,
                        Icons.assignment_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryTile(
                        c,
                        "$completed",
                        "Completed",
                        c.green,
                        Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryTile(
                        c,
                        "$pending",
                        "Pending",
                        c.amber,
                        Icons.pending_rounded,
                      ),
                    ),
                  ],
                ),
                if (_totalSessions > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Completion Rate",
                        style: TextStyle(
                          color: c.textMid,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "${((completed / _totalSessions) * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: c.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completed / _totalSessions,
                      backgroundColor: c.border,
                      valueColor: AlwaysStoppedAnimation<Color>(c.green),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    ThemeProvider c,
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: c.textLow,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SESSIONS LIST ───────────────────────────────────────────────────────
  Widget _buildSessionsList(ThemeProvider c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.05),
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
                    color: c.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timeline_rounded, color: c.cyan, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  "Mentoring Sessions (${_sessionInfo.length})",
                  style: TextStyle(
                    color: c.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _sessionInfo.reversed
                  .map((session) => _buildSessionItem(c, session))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(ThemeProvider c, Map<String, dynamic> session) {
    final sessionDate = _formatDate(session['session_date']);
    final status = session['status'] ?? 'unknown';
    final details =
        session['details_matters'] != null &&
            session['details_matters'].isNotEmpty
        ? session['details_matters'][0]
        : {};
    final statusColor = status.toLowerCase() == 'completed' ? c.green : c.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: c.textMid,
          iconColor: statusColor,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              status.toLowerCase() == 'completed'
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          title: Text(
            "Session • $sessionDate",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textHigh,
            ),
          ),
          subtitle: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details['attendance']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Attendance',
                      details['attendance'],
                      c.green,
                    ),
                  if (details['academicPerformance']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Academic Performance',
                      details['academicPerformance'],
                      c.cyan,
                    ),
                  if (details['personalGoals']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Personal Goals',
                      details['personalGoals'],
                      c.violet,
                    ),
                  if (details['professionalGoals']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Professional Goals',
                      details['professionalGoals'],
                      c.amber,
                    ),
                  if (session['mentor_feedback']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Mentor Feedback',
                      session['mentor_feedback'],
                      c.pink,
                    ),
                  if (session['positive_traits']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Positive Traits',
                      session['positive_traits'],
                      c.green,
                    ),
                  if (session['corrective_measures']?.isNotEmpty == true)
                    _sessionDetail(
                      c,
                      'Corrective Measures',
                      session['corrective_measures'],
                      c.amber,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionDetail(
    ThemeProvider c,
    String title,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: c.textMid),
            ),
          ),
        ],
      ),
    );
  }

  // ─── NO SESSIONS CARD ───────────────────────────────────────────────────
  Widget _buildNoSessionsCard(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_outlined, color: c.amber, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            "No Sessions Yet",
            style: TextStyle(
              color: c.textHigh,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Mentoring sessions will appear here once conducted.",
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMid, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── LOADING / ERROR STATES ─────────────────────────────────────────────
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
          Text(
            "Loading mentor sessions...",
            style: TextStyle(color: c.textMid, fontSize: 14),
          ),
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
            Text(
              "Failed to Load",
              style: TextStyle(
                color: c.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _fetchMentorData,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  "Try Again",
                  style: TextStyle(color: c.cyan, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMentorState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_outlined, size: 50, color: c.amber),
            ),
            const SizedBox(height: 20),
            Text(
              "No Mentor Assigned",
              style: TextStyle(
                color: c.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "No mentoring sessions found for your roll number.",
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _fetchMentorData,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.amber.withOpacity(0.3)),
                ),
                child: Text(
                  "Refresh",
                  style: TextStyle(color: c.amber, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GRID PAINTER ─────────────────────────────────────────────────────────
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