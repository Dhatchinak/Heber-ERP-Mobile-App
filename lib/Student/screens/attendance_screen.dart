import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class DailyAttendance {
  final String date, day, status, hours, periods, originalDate;
  final List<dynamic> hourDetails;
  DailyAttendance({
    required this.date, required this.day, required this.status,
    required this.hours, required this.periods,
    required this.hourDetails, required this.originalDate,
  });
}

class MonthlyStats {
  final int year, month, presentDays, totalDays, partialDays;
  final double percentage, absentDays;
  MonthlyStats({
    required this.year, required this.month, required this.percentage,
    required this.totalDays, required this.presentDays,
    required this.absentDays, required this.partialDays,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATTENDANCE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceScreen extends StatefulWidget {
  final String rollNo, studentName;
  const AttendanceScreen({super.key, required this.rollNo, required this.studentName});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {

  int _selectedTab = 0;
  bool _isLoading  = true;

  List<DailyAttendance> dailyAttendanceList = [];
  List<MonthlyStats>    monthlyStats        = [];

  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Present', 'Half Absent', 'Full Absent'];

  int    totalWorkingDays = 0, currentWorkingDays = 0, semesterPresentDays = 0;
  double semesterAbsentDays = 0.0, semesterAttendancePercentage = 0.0;
  double requiredPercentage = 75.0;

  Map<String, dynamic> _analyticsData = {
    'presentDays': 0, 'leaveDays': 0.0, 'halfDays': 0,
    'fullDays': 0, 'totalWorkingDays': 0, 'overallAttendance': 0.0,
  };

  String _searchQuery = '';
  String? _studentName;
  
  late AnimationController _progressAnimCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _appBarGlow;
  late Animation<double> _progressAnim;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _progressAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = CurvedAnimation(parent: _progressAnimCtrl, curve: Curves.easeOutCubic);
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _stagger = List.generate(6, (i) => CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
    ));
    _loadStudentName();
    _fetchAttendance();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _progressAnimCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    _studentName = prefs.getString('studentName') ?? widget.studentName;
    setState(() {});
  }

  // ─── FETCH ───────────────────────────────────────────────────────────────

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/students/attendance/${widget.rollNo}'),
        headers: {'Referer': 'http://117.232.64.75', 'Accept': 'application/json', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) _parseAttendance(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) { debugPrint('Fetch error: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); _staggerCtrl.forward(); _progressAnimCtrl.forward(from: 0); }
  }

  void _parseAttendance(Map<String, dynamic> data) {
    final List<DailyAttendance> tempList = [];
    final Map<String, List<DailyAttendance>> monthlyMap = {};

    for (final yearItem in (data['attendance'] as List<dynamic>? ?? [])) {
      if (yearItem is! Map<String, dynamic>) continue;
      for (final dayObj in (yearItem['sem_even'] as List<dynamic>? ?? [])) {
        if (dayObj is! Map<String, dynamic>) continue;
        dayObj.forEach((dateKey, info) {
          if (info is! Map<String, dynamic>) return;
          final hours = info['hours'] as List<dynamic>? ?? [];
          if (hours.isEmpty) return;
          final total = hours.length;
          final present = hours.where((h) => (h['status'] as String?)?.toLowerCase() == 'present').length;
          final absent  = total - present;
          String status;
          if (absent >= 3) { status = 'Absent'; }
          else if (absent >= 1) { status = 'Partial'; }
          else { status = 'Present'; }
          DateTime? date;
          try { date = DateTime.parse(dateKey); } catch (_) { return; }
          final rec = DailyAttendance(
            date: _formatDisplay(dateKey), day: _dayName(date), status: status,
            hours: '$present/$total', periods: _periodsText(hours),
            hourDetails: hours, originalDate: dateKey,
          );
          tempList.add(rec);
          final mk = '${date.year}-${date.month.toString().padLeft(2,'0')}';
          monthlyMap.putIfAbsent(mk, () => []).add(rec);
        });
      }
    }

    tempList.sort((a, b) => b.originalDate.compareTo(a.originalDate));

    final List<MonthlyStats> mStats = [];
    monthlyMap.forEach((key, recs) {
      double absDays = 0;
      for (final r in recs) {
        if (r.status == 'Absent') absDays += 1.0;
        else if (r.status == 'Partial') absDays += 0.5;
      }
      final pct = recs.isEmpty ? 0.0 : ((recs.length - absDays) / recs.length) * 100;
      final parts = key.split('-');
      mStats.add(MonthlyStats(
        year: int.parse(parts[0]), month: int.parse(parts[1]),
        percentage: pct, totalDays: recs.length,
        presentDays: (recs.length - absDays).toInt(), absentDays: absDays, partialDays: 0,
      ));
    });
    mStats.sort((a, b) => a.year != b.year ? a.year.compareTo(b.year) : a.month.compareTo(b.month));

    double totalAbsDays = 0; int presentCount = 0, halfCount = 0, fullCount = 0;
    for (final r in tempList) {
      if (r.status == 'Present') presentCount++;
      else if (r.status == 'Absent') { fullCount++; totalAbsDays += 1.0; }
      else { halfCount++; totalAbsDays += 0.5; }
    }
    final effectivePresent = presentCount + halfCount * 0.5;
    final pct = tempList.isEmpty ? 0.0 : (effectivePresent / tempList.length) * 100;

    if (mounted) {
      setState(() {
        dailyAttendanceList          = tempList;
        monthlyStats                 = mStats;
        totalWorkingDays             = tempList.length;
        currentWorkingDays           = tempList.length;
        semesterPresentDays          = effectivePresent.round();
        semesterAbsentDays           = totalAbsDays;
        semesterAttendancePercentage = pct;
        _analyticsData = {
          'presentDays': presentCount, 'leaveDays': totalAbsDays,
          'halfDays': halfCount, 'fullDays': fullCount,
          'totalWorkingDays': tempList.length, 'overallAttendance': pct,
        };
      });
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _formatDisplay(String s) {
    try {
      final p = s.split('-');
      return p.length == 3 ? '${int.parse(p[2])} ${_monthName(int.parse(p[1]))} ${p[0]}' : s;
    } catch (_) { return s; }
  }
  String _monthName(int m) => ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m.clamp(1,12)];
  String _dayName(DateTime d) => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d.weekday % 7];
  String _periodsText(List<dynamic> h) {
    if (h.isEmpty) return 'No Data';
    final p = h.where((x) => (x['status'] as String?)?.toLowerCase() == 'present').length;
    if (p == h.length) return 'All Present';
    if (p == 0) return 'All Absent';
    return '$p/${h.length} Periods';
  }

  List<DailyAttendance> get _filteredList {
    List<DailyAttendance> list;
    switch (_selectedFilter) {
      case 'Present':     list = dailyAttendanceList.where((r) => r.status == 'Present').toList();        break;
      case 'Half Absent': list = dailyAttendanceList.where((r) => r.status == 'Partial').toList(); break;
      case 'Full Absent': list = dailyAttendanceList.where((r) => r.status == 'Absent').toList();         break;
      default:            list = List.from(dailyAttendanceList);
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) =>
        r.date.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.day.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return list;
  }

  Color _filterAccent(ThemeProvider c) {
    switch (_selectedFilter) {
      case 'Present':     return c.green;
      case 'Half Absent': return c.amber;
      case 'Full Absent': return c.pink;
      default:            return c.cyan;
    }
  }

  Widget _animated(int i, Widget child) => FadeTransition(
    opacity: _stagger[i],
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_stagger[i]),
      child: child,
    ),
  );

  // ─── APP BAR ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildFuturisticAppBar(ThemeProvider c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15), width: 1)),
              boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04), blurRadius: 20)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                        child: Icon(Icons.menu_rounded, color: c.textHigh, size: 18),
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  // const SizedBox(width: 4),
                  // Container(
                  //   padding: const EdgeInsets.all(8),
                  //   decoration: BoxDecoration(color: c.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  //   child: Icon(Icons.show_chart_rounded, color: c.cyan, size: 18),
                  // ),
                  const SizedBox(width: 2),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Attendance", style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text("Student Record", style: TextStyle(color: c.cyan.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.cyan,
                          boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.6), blurRadius: 4)])),
                        const SizedBox(width: 5),
                        Text("TRACKING", style: TextStyle(color: c.cyan, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20),
                    onPressed: _fetchAttendance,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: widget.rollNo,
        studentName: _studentName ?? widget.studentName,
        currentRoute: '/attendance',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: _isLoading ? _buildLoadingState(c)
          : dailyAttendanceList.isEmpty ? _buildEmptyState(c)
          : RefreshIndicator(
              onRefresh: _fetchAttendance,
              color: c.cyan,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _animated(0, _buildHeroBanner(c)),
                    const SizedBox(height: 16),
                    _animated(1, _buildProgressCard(c)),
                    const SizedBox(height: 16),
                    _animated(2, _buildStatsGrid(c)),
                    const SizedBox(height: 16),
                    _animated(3, _buildTabSelector(c)),
                    const SizedBox(height: 12),
                    _selectedTab == 0 ? _buildSummaryTab(c) : _buildAnalyticsTab(c),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── HERO BANNER ─────────────────────────────────────────────────────────
  Widget _buildHeroBanner(ThemeProvider c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c.bannerGradient),
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
                      Text("ATTENDANCE OVERVIEW", style: TextStyle(color: c.cyan.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_studentName?.split(' ').first ?? "Student", style: TextStyle(color: c.textHigh, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 4),
                  Text("Even Semester 2025-26", style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(c, "${semesterAttendancePercentage.toStringAsFixed(1)}%", "Attendance", c.cyan),
                      _infoChip(c, "$semesterPresentDays", "Present Days", c.green),
                      _infoChip(c, semesterAbsentDays.toStringAsFixed(1), "Absent Days", c.amber),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.cyan.withOpacity(0.25))),
              child: Icon(Icons.show_chart_rounded, color: c.cyan, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(ThemeProvider c, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
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

  // ─── PROGRESS CARD ───────────────────────────────────────────────────────

  Widget _buildProgressCard(ThemeProvider c) {
    final pct = semesterAttendancePercentage;
    final meetsReq = pct >= requiredPercentage;
    final statusColor = meetsReq ? c.green : c.amber;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.06), blurRadius: 16)],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Attendance Progress", style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.3))),
              child: Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.w800,
                shadows: [Shadow(color: statusColor.withOpacity(0.5), blurRadius: 8)])),
            ),
          ]),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) {
              final animPct = pct * _progressAnim.value / 100;
              return Stack(
                children: [
                  Container(height: 10, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(5))),
                  FractionallySizedBox(
                    widthFactor: animPct.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: meetsReq ? [c.green, c.greenDim] : [c.amber, c.amber]),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 8)]),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [Icon(Icons.people_outline, size: 13, color: c.textMid), const SizedBox(width: 6),
              Text('Present: $semesterPresentDays / $currentWorkingDays days', style: TextStyle(fontSize: 11, color: c.textMid))]),
            Row(children: [Icon(meetsReq ? Icons.check_circle_rounded : Icons.info_rounded, size: 13, color: statusColor),
              const SizedBox(width: 4), Text(meetsReq ? 'On Track' : 'Needs Work', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700))]),
          ]),
        ],
      ),
    );
  }

  // ─── STATS GRID ──────────────────────────────────────────────────────────

  Widget _buildStatsGrid(ThemeProvider c) {
    final items = [
      _StatItem('Present Days', '${_analyticsData['presentDays']}', c.green, Icons.check_circle_rounded),
      _StatItem('Full Absent', '${_analyticsData['fullDays']}', c.pink, Icons.cancel_rounded),
      _StatItem('Half Days', '${_analyticsData['halfDays']}', c.amber, Icons.timelapse_rounded),
      _StatItem('Leave Days', (_analyticsData['leaveDays'] as double).toStringAsFixed(1), c.cyan, Icons.event_busy_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        crossAxisSpacing: 12, 
        mainAxisSpacing: 12, 
        childAspectRatio: 1.8
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _statTile(items[i], c),
    );
  }

  Widget _statTile(_StatItem item, ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface, 
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: item.color.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, 
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(10), 
              border: Border.all(color: item.color.withOpacity(0.25))
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Text(
                item.value, 
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: item.color, 
                  height: 1,
                  shadows: [Shadow(color: item.color.withOpacity(0.4), blurRadius: 6)]
                ),
              ),
              Text(item.label, style: TextStyle(fontSize: 10, color: c.textMid)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB SELECTOR ────────────────────────────────────────────────────────

  Widget _buildTabSelector(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(
        children: [
          _tabBtn(0, 'Daily Records', Icons.list_alt_rounded, c.cyan, c),
          _tabBtn(1, 'Analytics', Icons.analytics_rounded, c.violet, c),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, String label, IconData icon, Color color, ThemeProvider c) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: color.withOpacity(0.35)) : null,
            boxShadow: active ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: active ? color : c.textLow),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? color : c.textLow)),
          ]),
        ),
      ),
    );
  }

  // ─── SUMMARY TAB ─────────────────────────────────────────────────────────

  Widget _buildSummaryTab(ThemeProvider c) {
    final filtered = _filteredList;
    return Column( 
      children: [
        _buildSearchBar(c),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: filtered.isEmpty ? _buildEmptyFilter(c)
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _DayCard(attendance: filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: c.textLow),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(fontSize: 13, color: c.textHigh),
            decoration: InputDecoration(
              hintText: 'Search records…',
              hintStyle: TextStyle(color: c.textLow, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
          Container(
            height: 32,
            padding: const EdgeInsets.only(left: 6, right: 2),
            decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                dropdownColor: c.elevated2,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: c.textMid),
                style: TextStyle(fontSize: 11, color: c.textHigh, fontWeight: FontWeight.w600),
                items: _filterOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => setState(() => _selectedFilter = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilter(ThemeProvider c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: c.textLow),
          const SizedBox(height: 10),
          Text('No $_selectedFilter records', style: TextStyle(fontSize: 13, color: c.textMid, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── ANALYTICS TAB ───────────────────────────────────────────────────────

  Widget _buildAnalyticsTab(ThemeProvider c) {
    final pct = _analyticsData['overallAttendance'] as double;
    final presentDays = _analyticsData['presentDays'] as int;
    final halfDays = _analyticsData['halfDays'] as int;
    final fullDays = _analyticsData['fullDays'] as int;
    final totalDays = _analyticsData['totalWorkingDays'] as int;
    final leaveDays = _analyticsData['leaveDays'] as double;
    final effectivePres = presentDays + halfDays * 0.5;
    final meetsReq = pct >= requiredPercentage;

    return Column(
      children: [
        // Performance overview card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anaHeader('PERFORMANCE OVERVIEW', 'Current semester attendance', c.cyan, c),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text('${pct.toStringAsFixed(2)}%', style: TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w900, color: meetsReq ? c.green : c.amber, height: 1,
                      shadows: [Shadow(color: (meetsReq ? c.green : c.amber).withOpacity(0.5), blurRadius: 20)])),
                    const SizedBox(height: 6),
                    Text('${effectivePres.toStringAsFixed(1)} out of $totalDays working days', style: TextStyle(fontSize: 11, color: c.textMid)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: (meetsReq ? c.green : c.amber).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: (meetsReq ? c.green : c.amber).withOpacity(0.25))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(meetsReq ? Icons.verified_rounded : Icons.info_rounded, size: 16, color: meetsReq ? c.green : c.amber),
                  const SizedBox(width: 8),
                  Text(meetsReq ? '✓ Target Achieved' : '⚠ Needs Improvement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: meetsReq ? c.green : c.amber)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Distribution card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anaHeader('ATTENDANCE DISTRIBUTION', 'Breakdown of your patterns', c.violet, c),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _circleStat('Present Days', '$presentDays', totalDays > 0 ? '${(presentDays / totalDays * 100).toStringAsFixed(1)}%' : '0%', c.green, c),
                _circleStat('Leave Days', leaveDays.toStringAsFixed(1), totalDays > 0 ? '${(leaveDays / totalDays * 100).toStringAsFixed(1)}%' : '0%', c.amber, c),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                child: Column(
                  children: [
                    _detailRow('Half Days', '$halfDays', c.amber, c),
                    const SizedBox(height: 8),
                    _detailRow('Full Absent Days', '$fullDays', c.pink, c),
                    const SizedBox(height: 8),
                    _detailRow('Total Working Days', '$totalDays', c.cyan, c),
                    const SizedBox(height: 8),
                    _detailRow('Overall Attendance', '${pct.toStringAsFixed(2)}%', c.green, c),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Monthly breakdown
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anaHeader('MONTHLY BREAKDOWN', 'Month-by-month attendance pattern', c.amber, c),
              const SizedBox(height: 16),
              ...monthlyStats.map((m) => _monthRow(m, c)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _anaHeader(String title, String sub, Color color, ThemeProvider c) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
          child: Icon(Icons.analytics_rounded, size: 12, color: color)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          Text(sub, style: TextStyle(fontSize: 10, color: c.textMid)),
        ]),
      ],
    );
  }

  Widget _circleStat(String title, String val, String pct, Color color, ThemeProvider c) {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08), shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1,
              shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 6)])),
            Text(pct, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 11, color: c.textMid, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _detailRow(String label, String value, Color color, ThemeProvider c) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: c.textMid)),
      Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _monthRow(MonthlyStats m, ThemeProvider c) {
    final color = m.percentage >= 75 ? c.green : m.percentage >= 60 ? c.amber : c.pink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text('${_monthName(m.month)} ${m.year}', style: TextStyle(fontSize: 11, color: c.textHigh, fontWeight: FontWeight.w600))),
          Expanded(
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => Stack(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: (m.percentage / 100 * _progressAnim.value).clamp(0.0, 1.0),
                    child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)])),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 40, child: Text('${m.percentage.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ─── LOADING / EMPTY ─────────────────────────────────────────────────────

  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 40, height: 40,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.cyan, backgroundColor: c.cyan.withOpacity(0.1))),
        const SizedBox(height: 16),
        Text('Loading Attendance Data…', style: TextStyle(fontSize: 13, color: c.textMid, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Syncing your records', style: TextStyle(fontSize: 11, color: c.textLow)),
      ]),
    );
  }

  Widget _buildEmptyState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: c.textLow.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: c.border)),
            child: Icon(Icons.event_busy_rounded, size: 48, color: c.textLow)),
          const SizedBox(height: 16),
          Text('No Attendance Data Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textHigh)),
          const SizedBox(height: 8),
          Text('Pull to refresh or try again.', style: TextStyle(fontSize: 12, color: c.textMid)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchAttendance,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.cyan.withOpacity(0.15), foregroundColor: c.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.cyan)),
              elevation: 0),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DAY CARD (expandable)
// ─────────────────────────────────────────────────────────────────────────────

class _DayCard extends StatefulWidget {
  final DailyAttendance attendance;
  const _DayCard({required this.attendance});
  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final att = widget.attendance;
    final attColor = att.status == 'Present' ? c.green : att.status == 'Absent' ? c.pink : c.amber;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _expanded ? attColor.withOpacity(0.4) : attColor.withOpacity(0.18), width: _expanded ? 1.5 : 1),
        boxShadow: _expanded ? [BoxShadow(color: attColor.withOpacity(0.1), blurRadius: 10)] : [],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: attColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: attColor.withOpacity(0.25))),
                    child: Icon(att.status == 'Present' ? Icons.check_circle_rounded : att.status == 'Absent' ? Icons.cancel_rounded : Icons.timelapse_rounded, color: attColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(att.date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHigh)),
                      const SizedBox(height: 2),
                      Text('${att.day}  ·  ${att.hours} periods', style: TextStyle(fontSize: 10, color: c.textMid)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: attColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: attColor.withOpacity(0.3))),
                    child: Text(att.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: attColor, letterSpacing: 0.3)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: c.textMid)),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: attColor.withOpacity(0.15), thickness: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.access_time_rounded, size: 12, color: c.textMid), const SizedBox(width: 6),
                        Text('Period Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHigh))]),
                      const SizedBox(height: 8),
                      ...att.hourDetails.map((h) => _hourRow(h, c)),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _hourRow(dynamic hour, ThemeProvider c) {
    final isPresent = (hour['status'] as String?)?.toLowerCase() == 'present';
    final color = isPresent ? c.green : c.pink;
    final hourNum = hour['hour'] ?? '—';
    final staffId = hour['staffId'] ?? hour['staff_id'] ?? 'N/A';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: c.bg.withOpacity(0.6), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Period $hourNum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textHigh)),
            Text('Staff: $staffId', style: TextStyle(fontSize: 9, color: c.textMid)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withOpacity(0.3))),
            child: Text(hour['status'] ?? '—', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── Helper classes ──────────────────────────────────────────────────────────

class _StatItem {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatItem(this.label, this.value, this.color, this.icon);
}