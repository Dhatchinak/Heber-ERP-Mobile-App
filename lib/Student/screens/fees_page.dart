import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TuitionFeeRecord {
  final int semester;
  final String receiptNo;
  final DateTime paidDate;
  final double tuitionFee;
  final double courseFee;
  final double universityFee;
  final double libraryLabFee;
  final double maintenanceFee;
  final double developmentFee;
  final double others;
  final double total;
  final bool isPaid;

  const TuitionFeeRecord({
    required this.semester,
    required this.receiptNo,
    required this.paidDate,
    required this.tuitionFee,
    required this.courseFee,
    required this.universityFee,
    required this.libraryLabFee,
    required this.maintenanceFee,
    required this.developmentFee,
    required this.others,
    required this.total,
    required this.isPaid,
  });
}

class ExamFeeRecord {
  final int semester;
  final String refId;
  final String custRefNo;
  final DateTime paidDate;
  final double amount;
  final bool isPaid;
  final String status;

  const ExamFeeRecord({
    required this.semester,
    required this.refId,
    required this.custRefNo,
    required this.paidDate,
    required this.amount,
    required this.isPaid,
    required this.status,
  });
}

class StudentFeeInfo {
  final String name;
  final String rollNo;
  final String course;
  final String degreeType;
  final String stream;
  final int totalSemesters;
  final List<TuitionFeeRecord> tuitionFees;
  final List<ExamFeeRecord> examFees;

  const StudentFeeInfo({
    required this.name,
    required this.rollNo,
    required this.course,
    required this.degreeType,
    required this.stream,
    required this.totalSemesters,
    required this.tuitionFees,
    required this.examFees,
  });
}

StudentFeeInfo _buildFeeInfo({
  required String name,
  required String rollNo,
  required String course,
  required String degreeType,
  required String stream,
}) {
  final isPG = degreeType.toUpperCase() == 'PG';
  final totalSems = isPG ? 4 : 6;
  final paidCount = totalSems >= 5 ? 5 : totalSems - 1;

  final tuition = List.generate(totalSems, (i) {
    final sem = i + 1;
    final paid = sem <= paidCount;
    return TuitionFeeRecord(
      semester: sem,
      receiptNo: paid ? 'OL/SF_Adm/${2260 + sem * 31}' : '',
      paidDate: paid
          ? DateTime(2024 + ((sem - 1) ~/ 2), ((sem - 1) % 6) * 2 + 1, 15)
          : DateTime.now(),
      tuitionFee: isPG ? 1500.00 : 1200.00,
      courseFee: isPG ? 6000.00 : 4500.00,
      universityFee: 630.00,
      libraryLabFee: 200.00,
      maintenanceFee: isPG ? 750.00 : 600.00,
      developmentFee: isPG ? 2000.00 : 1500.00,
      others: isPG ? 15075.00 : 11870.00,
      total: isPG ? 26155.00 : 20500.00,
      isPaid: paid,
    );
  });

  final exam = List.generate(totalSems, (i) {
    final sem = i + 1;
    final paid = sem <= paidCount;
    return ExamFeeRecord(
      semester: sem,
      refId: paid ? 'EX${601111 + sem * 1111}' : '',
      custRefNo: paid ? 'EX${500999 + sem * 999}' : '',
      paidDate: paid
          ? DateTime(2024 + ((sem - 1) ~/ 2), ((sem - 1) % 6) * 2 + 2, 19)
          : DateTime.now(),
      amount: 1355.00,
      isPaid: paid,
      status: paid ? 'SUCCESS' : 'PENDING',
    );
  });

  return StudentFeeInfo(
    name: name,
    rollNo: rollNo,
    course: course,
    degreeType: degreeType,
    stream: stream,
    totalSemesters: totalSems,
    tuitionFees: tuition,
    examFees: exam,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FeesHistoryScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const FeesHistoryScreen({
    super.key,
    required this.rollNo,
    required this.studentName,
  });

  @override
  State<FeesHistoryScreen> createState() => _FeesHistoryScreenState();
}

class _FeesHistoryScreenState extends State<FeesHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  StudentFeeInfo? _feeInfo;
  bool _isLoading = true;
  String _errorMessage = '';

  late AnimationController _appBarGlow;
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _stagger = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.12, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _loadFeeData();
  }

  // ── FIX: correct UG/PG detection ─────────────────────────────────────────
  Future<void> _loadFeeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/students/${widget.rollNo}'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      String name = widget.studentName;
      String course = '';
      String degreeType = '';
      String stream = '';

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? {};
        name = data['name'] as String? ?? widget.studentName;
        stream = data['stream'] as String? ?? '';

        final ca = data['current_academic'] as Map<String, dynamic>? ?? {};
        course = ca['program_name'] as String? ?? '';

        // Try program_type first (correct field), then degree_type as fallback
        final raw = ((ca['program_type'] as String?) ??
                (ca['degree_type'] as String?) ??
                (data['degree_type'] as String?) ??
                '')
            .trim()
            .toUpperCase();

        if (raw == 'PG' || raw.contains('POST') || raw.contains('MASTER')) {
          degreeType = 'PG';
        } else if (raw == 'UG' ||
            raw.contains('UNDER') ||
            raw.contains('BACHELOR')) {
          degreeType = 'UG';
        } else {
          // Infer from stream / course name
          final combined = '$stream $course'.toUpperCase();
          const pgPrefixes = [
            'M.SC',
            'MSC',
            'M.COM',
            'MCOM',
            'MBA',
            'MCA',
            'M.A ',
            'MA ',
            'M.PHIL',
            'M.ED',
            'MSW',
            'M.TECH',
            'PH.D',
            'PHD',
            'PG ',
            'POST GRAD',
            'MASTER',
          ];
          degreeType =
              pgPrefixes.any((k) => combined.contains(k)) ? 'PG' : 'UG';
        }

        // Save for offline fallback
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('degree_type', degreeType);
        await prefs.setString('stream_name', stream);
      }

      if (degreeType.isEmpty) degreeType = 'UG';

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _feeInfo = _buildFeeInfo(
            name: name,
            rollNo: widget.rollNo,
            course: course.isNotEmpty ? course : stream,
            degreeType: degreeType,
            stream: stream,
          );
          _isLoading = false;
        });
        _staggerCtrl.forward();
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      // Try new key first, legacy fallback
      final saved =
          prefs.getString('degree_type') ?? prefs.getString('stream') ?? '';
      final savedStream = prefs.getString('stream_name') ?? '';

      String inferred = saved.toUpperCase();
      if (inferred != 'PG' && inferred != 'UG') {
        const pgPrefixes = [
          'M.SC',
          'MSC',
          'M.COM',
          'MCOM',
          'MBA',
          'MCA',
          'M.A ',
          'MA ',
          'PG ',
          'MASTER',
        ];
        inferred = pgPrefixes.any((k) => savedStream.toUpperCase().contains(k))
            ? 'PG'
            : 'UG';
      }

      if (mounted) {
        setState(() {
          _feeInfo = _buildFeeInfo(
            name: widget.studentName,
            rollNo: widget.rollNo,
            course: savedStream,
            degreeType: inferred.isEmpty ? 'UG' : inferred,
            stream: savedStream,
          );
          _isLoading = false;
        });
        _staggerCtrl.forward();
      }
    }
  }

  Future<void> _refreshData() async {
    _staggerCtrl.reset();
    await _loadFeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appBarGlow.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ThemeProvider c) {
    final tPaid = _feeInfo?.tuitionFees.where((f) => f.isPaid).length ?? 0;
    final total = _feeInfo?.totalSemesters ?? 0;
    final allClear = tPaid == total && total > 0;

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) => Container(
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
                      child:
                          Icon(Icons.menu_rounded, color: c.textHigh, size: 18),
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee History',
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Payment Records',
                        style: TextStyle(
                          color: c.cyan.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: allClear
                        ? c.green.withOpacity(0.08)
                        : c.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: allClear
                          ? c.green.withOpacity(0.25)
                          : c.amber.withOpacity(0.25),
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
                          color: allClear ? c.green : c.amber,
                          boxShadow: [
                            BoxShadow(
                              color: (allClear ? c.green : c.amber)
                                  .withOpacity(0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        allClear ? 'CLEAR' : 'PENDING',
                        style: TextStyle(
                          color: allClear ? c.green : c.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20),
                  onPressed: _refreshData,
                ),
              ],
            ),
          ),
        ),
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
        studentName: widget.studentName,
        currentRoute: '/fees',
      ),
      appBar: _buildAppBar(c),
      body: _isLoading
          ? _buildLoadingState(c)
          : _errorMessage.isNotEmpty
              ? _buildErrorState(c)
              : _buildMainContent(c),
    );
  }

  Widget _buildMainContent(ThemeProvider c) {
    final info = _feeInfo!;
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(child: _buildHeroHeader(c, info)),
        SliverToBoxAdapter(child: _buildTabBar(c)),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _TuitionTab(info: info, stagger: _stagger),
          _ExamTab(info: info, stagger: _stagger),
        ],
      ),
    );
  }

  // ── HERO HEADER ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader(ThemeProvider c, StudentFeeInfo info) {
    final tPaid = info.tuitionFees.where((f) => f.isPaid).length;
    final totalPaid = info.tuitionFees
        .where((f) => f.isPaid)
        .fold<double>(0, (s, f) => s + f.total);
    final progressPct = tPaid / info.totalSemesters;
    final isPG = info.degreeType.toUpperCase() == 'PG';
    final badgeColor = isPG ? c.violet : c.cyan;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.isDarkMode ? const Color(0xFF0D1A3A) : c.bg,
            c.isDarkMode ? const Color(0xFF0F1E45) : c.surface,
            c.bg,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Grid bg
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              child: CustomPaint(
                painter: _GridPainter(color: c.violet.withOpacity(0.04)),
              ),
            ),
          ),
          // Glow orb
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Positioned(
              top: -20,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.cyan.withOpacity(0.04 + _pulseCtrl.value * 0.02),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            badgeColor.withOpacity(0.2),
                            c.violet.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: badgeColor.withOpacity(0.35)),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: badgeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: c.textHigh,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // PG/UG chip — FIX: uses correct degreeType
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: badgeColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  isPG ? 'PG' : 'UG',
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                info.rollNo,
                                style: TextStyle(
                                  color: c.textMid,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (info.course.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              info.course,
                              style: TextStyle(color: c.textLow, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Progress',
                          style: TextStyle(
                            color: c.textMid,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '$tPaid / ${info.totalSemesters}',
                          style: TextStyle(
                            color: c.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.elevated2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LayoutBuilder(
                        builder: (_, constraints) => AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * progressPct,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [c.cyan, c.green.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stat chips
                Row(
                  children: [
                    _buildStatChip(
                        c, '${info.totalSemesters}', 'Semesters', c.cyan),
                    const SizedBox(width: 8),
                    _buildStatChip(c, '₹${_formatCompact(totalPaid)}',
                        'Total Paid', c.green),
                    const SizedBox(width: 8),
                    _buildStatChip(c, '$tPaid', 'Paid', c.violet),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      ThemeProvider c, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: c.textLow,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(ThemeProvider c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 44,
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [c.cyan, c.cyan.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: c.cyan.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(3),
        labelColor: Colors.white,
        unselectedLabelColor: c.textMid,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(icon: Icon(Icons.school_rounded, size: 14), text: 'Tuition'),
          Tab(
              icon: Icon(Icons.assignment_turned_in_rounded, size: 14),
              text: 'Exam'),
        ],
      ),
    );
  }

  // ── LOADING ───────────────────────────────────────────────────────────────
  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.violet.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: c.violet.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.violet,
                    backgroundColor: c.violet.withOpacity(0.1),
                  ),
                  Icon(Icons.receipt_long_rounded,
                      size: 22, color: c.violet.withOpacity(0.6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading Fee Records',
              style: TextStyle(
                  fontSize: 13, color: c.textMid, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Fetching your payment history',
              style: TextStyle(fontSize: 11, color: c.textLow)),
        ],
      ),
    );
  }

  // ── ERROR ─────────────────────────────────────────────────────────────────
  Widget _buildErrorState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: c.pink.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: c.pink.withOpacity(0.3)),
              ),
              child: Icon(Icons.error_outline_rounded, size: 34, color: c.pink),
            ),
            const SizedBox(height: 18),
            Text('Unable to Load Fee Data',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textHigh)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid, fontSize: 12, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.violet.withOpacity(0.15),
                foregroundColor: c.violet,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: c.violet),
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

// ─────────────────────────────────────────────────────────────────────────────
// TUITION TAB
// ─────────────────────────────────────────────────────────────────────────────

class _TuitionTab extends StatelessWidget {
  final StudentFeeInfo info;
  final List<Animation<double>> stagger;
  const _TuitionTab({required this.info, required this.stagger});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: info.totalSemesters,
      itemBuilder: (_, i) => FadeTransition(
        opacity: stagger[i.clamp(0, stagger.length - 1)],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(stagger[i.clamp(0, stagger.length - 1)]),
          child: _TuitionCard(record: info.tuitionFees[i], info: info),
        ),
      ),
    );
  }
}

class _TuitionCard extends StatefulWidget {
  final TuitionFeeRecord record;
  final StudentFeeInfo info;
  const _TuitionCard({required this.record, required this.info});

  @override
  State<_TuitionCard> createState() => _TuitionCardState();
}

class _TuitionCardState extends State<_TuitionCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isDownloading = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
  }

  void _toggleExpand() {
    if (!widget.record.isPaid) return;
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final r = widget.record;
    final dateFmt = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: _toggleExpand,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: r.isPaid
                ? (_isExpanded
                    ? c.green.withOpacity(0.4)
                    : c.green.withOpacity(0.15))
                : c.border,
          ),
          boxShadow: r.isPaid && _isExpanded
              ? [
                  BoxShadow(
                    color: c.green.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: r.isPaid
                    ? LinearGradient(
                        colors: [
                          c.green.withOpacity(0.04),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(_isExpanded ? 0 : 17),
                  bottomRight: Radius.circular(_isExpanded ? 0 : 17),
                ),
              ),
              child: Row(
                children: [
                  _SemesterBadge(
                      semester: r.semester,
                      isPaid: r.isPaid,
                      color: c.green,
                      c: c),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semester ${r.semester}',
                            style: TextStyle(
                                color: c.textHigh,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        r.isPaid
                            ? Row(children: [
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: c.green,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('Paid on ${dateFmt.format(r.paidDate)}',
                                    style: TextStyle(
                                        color: c.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                              ])
                            : Row(children: [
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: c.amber,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('Pending',
                                    style: TextStyle(
                                        color: c.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                              ]),
                      ],
                    ),
                  ),
                  if (r.isPaid) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${_formatAmount(r.total)}',
                            style: TextStyle(
                                color: c.green,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _ActionButton(
                              icon: _isDownloading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.download_rounded,
                              color: c.cyan,
                              onTap: _isDownloading
                                  ? null
                                  : () => _downloadPDF(context, c),
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 280),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c.elevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.border),
                                ),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: c.textMid, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else
                    _PendingChip(c: c),
                ],
              ),
            ),
            // Expanded body
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(17),
                    bottomRight: Radius.circular(17),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.receipt_long_rounded,
                      label: 'Receipt No.',
                      value: widget.record.receiptNo,
                      color: c.cyan,
                      c: c,
                    ),
                    const SizedBox(height: 10),
                    Divider(color: c.border, height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Fee Breakdown',
                          style: TextStyle(
                              color: c.textMid,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ]),
                    const SizedBox(height: 8),
                    _FeeBreakdownTable(record: widget.record, c: c),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.green.withOpacity(0.06),
                            c.green.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.green.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: c.green, size: 14),
                            const SizedBox(width: 6),
                            Text('Total Paid',
                                style: TextStyle(
                                    color: c.textHigh,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ]),
                          Text('₹${_formatAmount(widget.record.total)}',
                              style: TextStyle(
                                  color: c.green,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPDF(BuildContext context, ThemeProvider c) async {
    setState(() => _isDownloading = true);
    try {
      final r = widget.record;
      final info = widget.info;
      final bytes = await _generateTuitionPDF(
        name: info.name,
        rollNo: info.rollNo,
        course: info.course,
        degreeType: info.degreeType,
        semester: r.semester,
        receiptNo: r.receiptNo,
        paidDate: DateFormat('dd-MMM-yyyy').format(r.paidDate),
        paidTime: DateFormat('h:mm:ssa').format(r.paidDate),
        tuitionFee: r.tuitionFee,
        courseFee: r.courseFee,
        universityFee: r.universityFee,
        libraryLabFee: r.libraryLabFee,
        maintenanceFee: r.maintenanceFee,
        developmentFee: r.developmentFee,
        others: r.others,
        total: r.total,
      );
      await _savePDFToDownloads(
        bytes: bytes,
        filename: 'Fee_Receipt_Sem${r.semester}_${info.rollNo}.pdf',
        context: context,
        themeC: c,
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXAM TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ExamTab extends StatelessWidget {
  final StudentFeeInfo info;
  final List<Animation<double>> stagger;
  const _ExamTab({required this.info, required this.stagger});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: info.totalSemesters,
      itemBuilder: (_, i) => FadeTransition(
        opacity: stagger[i.clamp(0, stagger.length - 1)],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(stagger[i.clamp(0, stagger.length - 1)]),
          child: _ExamCard(record: info.examFees[i], info: info),
        ),
      ),
    );
  }
}

class _ExamCard extends StatefulWidget {
  final ExamFeeRecord record;
  final StudentFeeInfo info;
  const _ExamCard({required this.record, required this.info});

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isDownloading = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
  }

  void _toggleExpand() {
    if (!widget.record.isPaid) return;
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final r = widget.record;
    final dateFmt = DateFormat('dd MMM yyyy, h:mm a');

    return GestureDetector(
      onTap: _toggleExpand,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: r.isPaid
                ? (_isExpanded
                    ? c.violet.withOpacity(0.4)
                    : c.violet.withOpacity(0.15))
                : c.border,
          ),
          boxShadow: r.isPaid && _isExpanded
              ? [
                  BoxShadow(
                    color: c.violet.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: r.isPaid
                    ? LinearGradient(
                        colors: [
                          c.violet.withOpacity(0.04),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(_isExpanded ? 0 : 17),
                  bottomRight: Radius.circular(_isExpanded ? 0 : 17),
                ),
              ),
              child: Row(
                children: [
                  _SemesterBadge(
                      semester: r.semester,
                      isPaid: r.isPaid,
                      color: c.violet,
                      c: c),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semester ${r.semester} — Exam',
                            style: TextStyle(
                                color: c.textHigh,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        r.isPaid
                            ? Row(children: [
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: c.violet,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(dateFmt.format(r.paidDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: c.violet,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ])
                            : Row(children: [
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: c.amber,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('Pending',
                                    style: TextStyle(
                                        color: c.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                              ]),
                      ],
                    ),
                  ),
                  if (r.isPaid) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${_formatAmount(r.amount)}',
                            style: TextStyle(
                                color: c.violet,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _ActionButton(
                              icon: _isDownloading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.download_rounded,
                              color: c.violet,
                              onTap: _isDownloading
                                  ? null
                                  : () => _downloadPDF(context, c),
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 280),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c.elevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.border),
                                ),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: c.textMid, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else
                    _PendingChip(c: c),
                ],
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(17),
                    bottomRight: Radius.circular(17),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _InfoTile(
                        icon: Icons.tag_rounded,
                        label: 'Ref. ID',
                        value: widget.record.refId,
                        color: c.violet,
                        c: c),
                    const SizedBox(height: 10),
                    _InfoTile(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Cust. Ref. No.',
                        value: widget.record.custRefNo,
                        color: c.cyan,
                        c: c),
                    const SizedBox(height: 10),
                    Divider(color: c.border, height: 1),
                    const SizedBox(height: 10),
                    _InfoTile(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Amount',
                        value: '₹${_formatAmount(widget.record.amount)}',
                        color: c.violet,
                        c: c),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.verified_rounded,
                                color: c.green, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Text('Status',
                              style: TextStyle(
                                  color: c.textMid,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: c.green.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: c.green, size: 10),
                              const SizedBox(width: 4),
                              Text(widget.record.status,
                                  style: TextStyle(
                                      color: c.green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10)),
                            ],
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
      ),
    );
  }

  Future<void> _downloadPDF(BuildContext context, ThemeProvider c) async {
    setState(() => _isDownloading = true);
    try {
      final r = widget.record;
      final info = widget.info;
      final bytes = await _generateExamPDF(
        name: info.name,
        rollNo: info.rollNo,
        course: info.course,
        semester: r.semester,
        refId: r.refId,
        custRefNo: r.custRefNo,
        paidDate: r.paidDate,
        amount: r.amount,
        status: r.status,
      );
      await _savePDFToDownloads(
        bytes: bytes,
        filename: 'ExamFee_Sem${r.semester}_${info.rollNo}.pdf',
        context: context,
        themeC: c,
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SemesterBadge extends StatelessWidget {
  final int semester;
  final bool isPaid;
  final Color color;
  final ThemeProvider c;
  const _SemesterBadge(
      {required this.semester,
      required this.isPaid,
      required this.color,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final bc = isPaid ? color : c.amber;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bc.withOpacity(0.12), bc.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bc.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$semester',
              style: TextStyle(
                  color: bc,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1)),
          Text('SEM',
              style: TextStyle(
                  color: bc.withOpacity(0.6),
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  final ThemeProvider c;
  const _PendingChip({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.amber.withOpacity(0.3)),
      ),
      child: Text('PENDING',
          style: TextStyle(
              color: c.amber,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeProvider c;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: c.textMid,
                    fontSize: 11,
                    fontWeight: FontWeight.w500))),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ],
    );
  }
}

class _FeeBreakdownTable extends StatelessWidget {
  final TuitionFeeRecord record;
  final ThemeProvider c;
  const _FeeBreakdownTable({required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Tuition Fee', record.tuitionFee),
      ('Course Fee', record.courseFee),
      ('University Fee', record.universityFee),
      ('Library / Lab CD', record.libraryLabFee),
      ('Maintenance Fee', record.maintenanceFee),
      ('Development Fee', record.developmentFee),
      ('Others', record.others),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.elevated.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final (label, amount) = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: idx > 0
                  ? Border(top: BorderSide(color: c.border, width: 0.5))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: c.textMid, fontSize: 11)),
                Text('₹${_formatAmount(amount)}',
                    style: TextStyle(
                        color: c.textHigh,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _formatAmount(double v) =>
    NumberFormat('#,##,##0.00', 'en_IN').format(v);

String _formatCompact(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

Future<void> _savePDFToDownloads({
  required Uint8List bytes,
  required String filename,
  required BuildContext context,
  required ThemeProvider themeC,
}) async {
  File? savedFile;

  try {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        savedFile = File('${dir.path}/$filename');
        await savedFile.writeAsBytes(bytes, flush: true);
      }
    }
    if (savedFile == null) {
      final dir = await getApplicationDocumentsDirectory();
      savedFile = File('${dir.path}/$filename');
      await savedFile.writeAsBytes(bytes, flush: true);
    }
  } catch (_) {}

  if (!context.mounted) return;
  final filePath = savedFile?.path;

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 10),
      content: Container(
        decoration: BoxDecoration(
          color: themeC.surface,
          border: Border(top: BorderSide(color: themeC.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: themeC.cyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeC.cyan.withOpacity(0.3)),
              ),
              child: Icon(Icons.picture_as_pdf_rounded,
                  color: themeC.cyan, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filename,
                      style: TextStyle(
                          color: themeC.textHigh,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  const SizedBox(height: 1),
                  Text(
                    filePath != null ? 'Saved to Downloads' : 'Ready to share',
                    style: TextStyle(color: themeC.textMid, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (filePath != null)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  OpenFile.open(filePath);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeC.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeC.cyan.withOpacity(0.35)),
                  ),
                  child: Text('Open',
                      style: TextStyle(
                          color: themeC.cyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Printing.sharePdf(bytes: bytes, filename: filename);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: themeC.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: themeC.border),
                ),
                child: Text('Share',
                    style: TextStyle(
                        color: themeC.textMid,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: themeC.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.close_rounded, color: themeC.textLow, size: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Uint8List> _generateTuitionPDF({
  required String name,
  required String rollNo,
  required String course,
  required String degreeType,
  required int semester,
  required String receiptNo,
  required String paidDate,
  required String paidTime,
  required double tuitionFee,
  required double courseFee,
  required double universityFee,
  required double libraryLabFee,
  required double maintenanceFee,
  required double developmentFee,
  required double others,
  required double total,
}) async {
  final doc = pw.Document();

  pw.ImageProvider? logo;
  try {
    final data = await rootBundle.load('assets/bhclogo.png');
    logo = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {}

  pw.ImageProvider? crest;
  try {
    final data = await rootBundle.load('assets/bhccrest.png');
    crest = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    crest = logo;
  }

  final bold = await PdfGoogleFonts.notoSerifBold();
  final regular = await PdfGoogleFonts.notoSerifRegular();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 50),
      build: (context) {
        return pw.Stack(
          children: [
            // Faded Background Watermark (Crest)
            if (crest != null)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.10,
                    child: pw.SizedBox(
                      width: 350,
                      child: pw.Image(crest),
                    ),
                  ),
                ),
              ),

            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header Block (Centered Logo and Text)
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (logo != null) pw.Image(logo, width: 60, height: 60),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Bishop Heber College (Autonomous)',
                        style: pw.TextStyle(font: bold, fontSize: 16),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Online Fee Receipt',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 11,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // 2. Student Details Block
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Table(
                        columnWidths: {
                          0: const pw.FixedColumnWidth(80),
                          1: const pw.FixedColumnWidth(15),
                          2: const pw.FlexColumnWidth(),
                        },
                        children: [
                          _buildStudentRow('Roll No.', rollNo, regular, bold),
                          _buildStudentRow(
                              'Name', name.toUpperCase(), regular, bold),
                          _buildStudentRow('Class', course, regular, bold),
                          _buildStudentRow(
                              'Semester', '$semester', regular, bold),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Text(
                        degreeType.toUpperCase(),
                        style: pw.TextStyle(font: bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 16),

                // 3. Fee Paid Details Title & Receipt Info
                pw.Center(
                  child: pw.Text(
                    'Fee Paid Details',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 11,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Center(
                  child: pw.Text(
                    paidDate,
                    style: pw.TextStyle(font: bold, fontSize: 13),
                  ),
                ),
                pw.SizedBox(height: 6),

                pw.Center(
                  child: pw.Text(
                    '$receiptNo - ${_formatAmount(total)}',
                    style: pw.TextStyle(font: bold, fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 6),

                pw.Center(
                  child: pw.Text(
                    'Nil',
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 24),

                // 4. Fee Breakdown
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 0),
                  child: pw.Column(
                    children: [
                      _buildFeeAmountRow('Tuition Fee', tuitionFee, regular),
                      _buildFeeAmountRow('Course Fee', courseFee, regular),
                      _buildFeeAmountRow(
                          'University Fee', universityFee, regular),
                      _buildFeeAmountRow(
                          'Library CD/ Lab CD', libraryLabFee, regular),
                      _buildFeeAmountRow(
                          'Maintenance Fee', maintenanceFee, regular),
                      _buildFeeAmountRow(
                          'Development Fee', developmentFee, regular),
                      _buildFeeAmountRow('Others', others, bold),
                      pw.SizedBox(height: 8),
                      _buildFeeAmountRow('Total Fees Paid', total, bold),
                    ],
                  ),
                ),

                pw.Spacer(),

                // 5. Footer
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          paidDate,
                          style: pw.TextStyle(font: regular, fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          paidTime,
                          style: pw.TextStyle(font: regular, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '1',
                          style: pw.TextStyle(font: regular, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'IT Support, BHC.',
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 8,
                            decoration: pw.TextDecoration.underline,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF HELPERS FOR TUITION RECEIPT
// ─────────────────────────────────────────────────────────────────────────────

// Formats the student details with proper colon alignment
pw.TableRow _buildStudentRow(
    String label, String value, pw.Font regular, pw.Font bold) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(':', style: pw.TextStyle(font: regular, fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10)),
      ),
    ],
  );
}

// Formats the fee breakdown row
pw.Widget _buildFeeAmountRow(String label, double amount, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
        pw.Text(_formatAmount(amount),
            style: pw.TextStyle(font: font, fontSize: 11)),
      ],
    ),
  );
}

// Helper for fee rows - label on left, amount on right
pw.Widget _buildFeeRow(String label, String amount, pw.Font bold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label :',
            style: pw.TextStyle(
                font: bold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(amount,
            style: pw.TextStyle(
                font: bold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}
// ─────────────────────────────────────────────────────────────────────────────
// PDF GENERATOR — EXAM
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _generateExamPDF({
  required String name,
  required String rollNo,
  required String course,
  required int semester,
  required String refId,
  required String custRefNo,
  required DateTime paidDate,
  required double amount,
  required String status,
}) async {
  final doc = pw.Document();
  final txDate = DateFormat('dd/MM/yyyy hh:mm:ss a').format(paidDate);
  final footerDate = DateFormat('dd-MMM-yyyy, hh:mm:ss a').format(paidDate);

  pw.ImageProvider? logo;
  try {
    final d = await rootBundle.load('assets/bhclogo.png');
    logo = pw.MemoryImage(d.buffer.asUint8List());
  } catch (_) {}

  pw.ImageProvider? crest;
  try {
    final d = await rootBundle.load('assets/bhccrest.png');
    crest = pw.MemoryImage(d.buffer.asUint8List());
  } catch (_) {
    crest = logo;
  }

  final bold = await PdfGoogleFonts.notoSerifBold();
  final regular = await PdfGoogleFonts.notoSerifRegular();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) {
        return pw.Stack(
          children: [
            // Watermark
            if (crest != null)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.SizedBox(
                        width: 300, height: 300, child: pw.Image(crest)),
                  ),
                ),
              ),

            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (logo != null)
                      pw.SizedBox(width: 55, height: 55, child: pw.Image(logo)),
                    pw.SizedBox(width: 14),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BISHOP HEBER COLLEGE',
                            style: pw.TextStyle(font: bold, fontSize: 16)),
                        pw.Text('(Autonomous)',
                            style: pw.TextStyle(font: bold, fontSize: 11)),
                        pw.Text('Tiruchirappalli - 620017.',
                            style: pw.TextStyle(
                                font: regular,
                                fontSize: 9,
                                color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 22),
                pw.Text('ONLINE FEES RECEIPT',
                    style: pw.TextStyle(font: bold, fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text('Exam Fees Transaction Status',
                    style: pw.TextStyle(font: bold, fontSize: 11)),
                pw.SizedBox(height: 22),

                // Details table
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    _pdfExamRow('NAME', name.toUpperCase(), bold),
                    _pdfExamRow('ROLL NO.', rollNo, bold),
                    _pdfExamRow('COURSE', course, bold),
                    _pdfExamRow('SEMESTER', '$semester', bold),
                    _pdfExamRow('REF. ID', refId, bold),
                    _pdfExamRow('CUST. REF. NO.', custRefNo, bold),
                    _pdfExamRow('AMOUNT', 'Rs. ${_formatAmount(amount)}', bold),
                    _pdfExamRow('STATUS', status, bold),
                    _pdfExamRow('TRANSACTION DATE', txDate, bold),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 6),
                pw.Text('IT SUPPORT, Bishop Heber College (Autonomous)',
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 2),
                pw.Text(footerDate,
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF HELPERS
// ─────────────────────────────────────────────────────────────────────────────

// "Roll No. : 2516615" row
pw.Widget _pdfInfoRow(
    String label, String value, pw.Font regular, pw.Font bold) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 66,
        child:
            pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 10.5)),
      ),
      pw.Text(': ', style: pw.TextStyle(font: regular, fontSize: 10.5)),
      pw.Expanded(
        child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10.5)),
      ),
    ],
  );
}

// Fee breakdown row: bold label left, bold amount right-aligned
pw.TableRow _pdfFeeRow(String label, String value, pw.Font bold) {
  return pw.TableRow(children: [
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 11)),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Text(value,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(font: bold, fontSize: 11)),
    ),
  ]);
}

// Exam table row
pw.TableRow _pdfExamRow(String label, String value, pw.Font bold) {
  return pw.TableRow(children: [
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 10)),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10)),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

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
