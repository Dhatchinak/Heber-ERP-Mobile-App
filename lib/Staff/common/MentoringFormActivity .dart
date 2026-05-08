import 'dart:async';
import 'dart:convert';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import '../theme_provider.dart';

class UnifiedMentoringDashboard extends StatefulWidget {
  const UnifiedMentoringDashboard({super.key});

  @override
  State<UnifiedMentoringDashboard> createState() =>
      _UnifiedMentoringDashboardState();
}

class _UnifiedMentoringDashboardState extends State<UnifiedMentoringDashboard>
    with TickerProviderStateMixin {
  List<dynamic> _allSessions = [];
  List<dynamic> _assignedMentees = [];
  List<dynamic> _filteredSessions = [];
  List<dynamic> _filteredMentees = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _mentorStats;
  String? _currentStaffId;
  String? _departmentCode;

  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedFilter;
  String? _selectedBatch;
  DateTime? _selectedDate;
  List<String> _availableBatches = [];
  int _currentTab = 0;

  late AnimationController _appBarGlow;
  late AnimationController _pageCtrl;
  late AnimationController _tabCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;
  late Animation<double> _tabFade;
  late Animation<Offset> _tabSlide;

  final List<AnimationController> _cardCtrls = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchAllData();
  }

  void _initAnimations() {
    _appBarGlow =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _tabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _stagger = List.generate(
        6,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.12, 1.0, curve: Curves.easeOutCubic),
            ));

    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _tabFade = CurvedAnimation(parent: _tabCtrl, curve: Curves.easeOut);
    _tabSlide = Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _tabCtrl, curve: Curves.easeOutCubic));

    _pageCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _tabCtrl.forward();
    });
  }

  void _buildCardAnimations(int count) {
    for (final c in _cardCtrls) {
      c.stop();
      c.dispose();
    }
    _cardCtrls.clear();
    _cardFades.clear();
    _cardSlides.clear();
    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 380));
      _cardCtrls.add(ctrl);
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
              begin: const Offset(0, 0.07), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
    }
    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && i < _cardCtrls.length) _cardCtrls[i].forward();
      });
    }
  }

  void _animateTabSwitch() {
    _tabCtrl.reset();
    _staggerCtrl.reset();
    _tabCtrl.forward();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _staggerCtrl.forward();
      final list = _currentTab == 0 ? _filteredSessions : _filteredMentees;
      _buildCardAnimations(list.length);
    });
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageCtrl.dispose();
    _tabCtrl.dispose();
    _staggerCtrl.dispose();
    for (final c in _cardCtrls) c.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(_stagger[i]),
          child: child,
        ),
      );

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      _currentStaffId = auth.userData?['staff_id'];
      _departmentCode = auth.userData?['department_code'];
      await Future.wait([_fetchSessions(), _fetchMentees()]);
      if (!mounted) return;
      _buildCardAnimations(_currentTab == 0
          ? _filteredSessions.length
          : _filteredMentees.length);
      _staggerCtrl.forward();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
    }
  }

  Future<void> _fetchSessions() async {
    if (_departmentCode == null) return;
    final res = await http.get(
      Uri.parse(
          'https://apierp.bhc.edu.in/api/staff/mentorship/get_department_session/$_departmentCode'),
      headers: {
        'Referer': 'http://117.232.64.75',
        'Accept': 'application/json'
      },
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final all = (data['data'] as List)
            .where((s) => s['mentor_id'] == _currentStaffId)
            .toList();
        final students = <String>{};
        int done = 0, sched = 0, cancelled = 0;
        for (var s in all) {
          if (s['student_name'] != null)
            students.add('${s['student_name']} (${s['student_id']})');
          final st = s['status'] ?? '';
          if (st == 'completed')
            done++;
          else if (st == 'scheduled')
            sched++;
          else if (st == 'cancelled') cancelled++;
        }
        if (mounted)
          setState(() {
            _allSessions = all;
            _filteredSessions = all;
            _mentorStats = {
              'total': all.length,
              'completed': done,
              'scheduled': sched,
              'cancelled': cancelled,
              'unique_students': students.length,
            };
          });
      }
    }
  }

  Future<void> _fetchMentees() async {
    if (_departmentCode == null || _currentStaffId == null) return;
    final res = await http.get(
      Uri.parse(
          'https://apierp.bhc.edu.in/api/staff/mentorship/$_departmentCode'),
      headers: {
        'Referer': 'http://117.232.64.75',
        'Accept': 'application/json'
      },
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final List<dynamic> all = [];
        final Set<String> batches = {};
        for (var stream in (data['data']?['streams'] ?? []) as List) {
          for (var shift in (stream['shifts'] ?? []) as List) {
            for (var mentor in (shift['staff_mentors'] ?? []) as List) {
              if (mentor['staff_id'] == _currentStaffId) {
                for (var batch in (mentor['assigned_students']?['batches'] ??
                    []) as List) {
                  final bn = batch['batch'] ?? '';
                  batches.add(bn);
                  for (var student in (batch['students'] ?? []) as List) {
                    if (student['active_status'] == true) {
                      all.add({
                        ...student,
                        'batch': bn,
                        'program_code': batch['program_code'],
                        'program_type': batch['program_type'] ?? 'UG',
                        'stream': stream['name'],
                      });
                    }
                  }
                }
              }
            }
          }
        }
        if (mounted)
          setState(() {
            _assignedMentees = all;
            _filteredMentees = all;
            _availableBatches = ['All', ...batches.toList()..sort()];
          });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchAllData();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _applySessionFilters() {
    var list = _allSessions.toList();
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((s) =>
              (s['student_name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (s['student_id'] ?? '').toString().contains(_searchQuery))
          .toList();
    }
    if (_selectedStatus != null && _selectedStatus != 'All') {
      list = list.where((s) => s['status'] == _selectedStatus).toList();
    }
    if (_selectedDate != null) {
      final d = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      list = list
          .where((s) =>
              DateFormat('yyyy-MM-dd')
                  .format(DateTime.parse(s['session_date']).toLocal()) ==
              d)
          .toList();
    }
    setState(() => _filteredSessions = list);
    _buildCardAnimations(list.length);
  }

  void _applyMenteeFilters() {
    var list = _assignedMentees.toList();
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((m) =>
              (m['student_name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (m['student_id'] ?? '').toString().contains(_searchQuery))
          .toList();
    }
    if (_selectedFilter != null && _selectedFilter != 'All') {
      if (_selectedFilter == 'UG' || _selectedFilter == 'PG') {
        list = list.where((m) => m['program_type'] == _selectedFilter).toList();
      }
    }
    if (_selectedBatch != null && _selectedBatch != 'All') {
      list = list.where((m) => m['batch'] == _selectedBatch).toList();
    }
    setState(() => _filteredMentees = list);
    _buildCardAnimations(list.length);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = null;
      _selectedFilter = null;
      _selectedBatch = null;
      _selectedDate = null;
      _filteredSessions = _allSessions;
      _filteredMentees = _assignedMentees;
    });
    _buildCardAnimations(
        _currentTab == 0 ? _filteredSessions.length : _filteredMentees.length);
  }

  Color _statusColor(StaffThemeProvider theme, String status) {
    switch (status) {
      case 'completed':
        return theme.green;
      case 'scheduled':
        return theme.amber;
      case 'cancelled':
        return theme.pink;
      default:
        return theme.violet;
    }
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(
              bottom: BorderSide(
                color:
                    theme.violet.withOpacity(0.15 + _appBarGlow.value * 0.12),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    theme.violet.withOpacity(0.05 + _appBarGlow.value * 0.04),
                blurRadius: 20,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                // Container(
                //   width: 32,
                //   height: 32,
                //   decoration: BoxDecoration(
                //     gradient: LinearGradient(
                //         colors: [theme.violet, theme.cyan]),
                //     borderRadius: BorderRadius.circular(10),
                //     boxShadow: [
                //       BoxShadow(
                //           color: theme.violet.withOpacity(0.35),
                //           blurRadius: 8)
                //     ],
                //   ),
                //   child: const Icon(Icons.groups_rounded,
                //       color: Colors.white, size: 17),
                // ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mentoring',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                      Text(
                        _currentTab == 0
                            ? 'Sessions'
                            : _currentTab == 1
                                ? 'Mentees'
                                : 'Reports',
                        style: TextStyle(
                            color: theme.violet.withOpacity(0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.violet.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.green,
                        boxShadow: [
                          BoxShadow(
                              color: theme.green.withOpacity(0.6),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('${_assignedMentees.length}',
                        style: TextStyle(
                            color: theme.violet,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 4),
                _isRefreshing
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: theme.violet)))
                    : IconButton(
                        icon: Icon(Icons.refresh_rounded,
                            color: theme.textMid, size: 20),
                        onPressed: _refreshData,
                      ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(StaffThemeProvider theme) {
    final tabs = [
      (Icons.meeting_room_rounded, 'Sessions', _allSessions.length, theme.cyan),
      (Icons.groups_rounded, 'Mentees', _assignedMentees.length, theme.violet),
      (Icons.bar_chart_rounded, 'Reports', 0, theme.amber),
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          final sel = i == _currentTab;
          final color = t.$4;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (i == _currentTab) return;
                setState(() {
                  _currentTab = i;
                  _searchQuery = '';
                });
                _animateTabSwitch();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? color : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.$1, size: 20, color: sel ? color : theme.textMid),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.$2,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? color : theme.textMid)),
                      if (t.$3 > 0) ...[
                        const SizedBox(width: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                sel ? color.withOpacity(0.15) : theme.elevated,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${t.$3}',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: sel ? color : theme.textMid)),
                        ),
                      ],
                    ],
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(StaffThemeProvider theme) {
    final stats = _currentTab == 0
        ? [
            ('${_mentorStats?['total'] ?? 0}', 'Total', theme.cyan),
            ('${_mentorStats?['completed'] ?? 0}', 'Done', theme.green),
            ('${_mentorStats?['scheduled'] ?? 0}', 'Scheduled', theme.amber),
            (
              '${_mentorStats?['unique_students'] ?? 0}',
              'Students',
              theme.violet
            ),
          ]
        : _currentTab == 1
            ? [
                ('${_assignedMentees.length}', 'Total', theme.violet),
                (
                  '${_assignedMentees.where((m) => m['program_type'] == 'UG').length}',
                  'UG',
                  theme.cyan
                ),
                (
                  '${_assignedMentees.where((m) => m['program_type'] == 'PG').length}',
                  'PG',
                  theme.amber
                ),
                (
                  '${_availableBatches.length > 1 ? _availableBatches.length - 1 : 0}',
                  'Batches',
                  theme.green
                ),
              ]
            : [
                ('${_mentorStats?['total'] ?? 0}', 'Sessions', theme.cyan),
                ('${_assignedMentees.length}', 'Mentees', theme.violet),
                ('${_mentorStats?['completed'] ?? 0}', 'Done', theme.green),
                ('${_mentorStats?['scheduled'] ?? 0}', 'Upcoming', theme.amber),
              ];

    return _animated(
      0,
      Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(left: e.key == 0 ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: s.$3.withOpacity(theme.isDarkMode ? 0.08 : 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: s.$3.withOpacity(0.2)),
              ),
              child: Column(children: [
                Text(s.$1,
                    style: TextStyle(
                        color: s.$3,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: s.$3.withOpacity(0.35), blurRadius: 6)
                        ])),
                const SizedBox(height: 2),
                Text(s.$2,
                    style: TextStyle(
                        color: theme.textMid,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SEARCH BAR ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(StaffThemeProvider theme) {
    return _animated(
      1,
      Container(
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: TextField(
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _currentTab == 0 ? _applySessionFilters() : _applyMenteeFilters();
          },
          style: TextStyle(color: theme.textHigh, fontSize: 14),
          decoration: InputDecoration(
            hintText: _currentTab == 0 ? 'Search sessions…' : 'Search mentees…',
            hintStyle: TextStyle(color: theme.textLow, fontSize: 13),
            prefixIcon:
                Icon(Icons.search_rounded, color: theme.textMid, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: theme.textMid, size: 18),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                      _clearFilters();
                    })
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── FILTER CHIPS ──────────────────────────────────────────────────────────

  Widget _buildFilterChips(StaffThemeProvider theme) {
    if (_currentTab == 2) return const SizedBox.shrink();
    final chips = _currentTab == 0
        ? ['All', 'completed', 'scheduled', 'cancelled']
        : ['All', 'UG', 'PG'];

    return _animated(
      2,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ...chips.map((c) {
            final isAll = c == 'All';
            final sel = _currentTab == 0
                ? (isAll ? _selectedStatus == null : _selectedStatus == c)
                : (isAll ? _selectedFilter == null : _selectedFilter == c);
            final color = _currentTab == 0
                ? _statusColor(theme, c)
                : (c == 'UG'
                    ? theme.cyan
                    : c == 'PG'
                        ? theme.amber
                        : theme.cyan);

            return GestureDetector(
              onTap: () {
                if (_currentTab == 0) {
                  setState(() => _selectedStatus = isAll ? null : c);
                  _applySessionFilters();
                } else {
                  setState(() => _selectedFilter = isAll ? null : c);
                  _applyMenteeFilters();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel
                      ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                      : null,
                  color: sel ? null : theme.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.transparent : theme.border),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: color.withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Text(
                  c == 'All' ? 'All' : c[0].toUpperCase() + c.substring(1),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : theme.textMid),
                ),
              ),
            );
          }),
          if (_currentTab == 1 && _availableBatches.length > 2)
            GestureDetector(
              onTap: () => _showBatchPicker(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedBatch != null
                      ? theme.violet.withOpacity(0.12)
                      : theme.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _selectedBatch != null
                          ? theme.violet.withOpacity(0.4)
                          : theme.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_list_rounded,
                      size: 13,
                      color: _selectedBatch != null
                          ? theme.violet
                          : theme.textMid),
                  const SizedBox(width: 5),
                  Text(_selectedBatch ?? 'Batch',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedBatch != null
                              ? theme.violet
                              : theme.textMid)),
                ]),
              ),
            ),
          if (_currentTab == 0)
            GestureDetector(
              onTap: () => _showDatePicker(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedDate != null
                      ? theme.cyan.withOpacity(0.12)
                      : theme.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _selectedDate != null
                          ? theme.cyan.withOpacity(0.4)
                          : theme.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13,
                      color:
                          _selectedDate != null ? theme.cyan : theme.textMid),
                  const SizedBox(width: 5),
                  Text(
                      _selectedDate != null
                          ? DateFormat('d MMM').format(_selectedDate!)
                          : 'Date',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedDate != null
                              ? theme.cyan
                              : theme.textMid)),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = null);
                        _applySessionFilters();
                      },
                      child: Icon(Icons.close_rounded,
                          size: 12, color: theme.cyan),
                    ),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  void _showBatchPicker(StaffThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Select Batch',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableBatches.map((b) {
                final sel = b == (_selectedBatch ?? 'All');
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBatch = b == 'All' ? null : b);
                    _applyMenteeFilters();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          sel ? theme.violet.withOpacity(0.12) : theme.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? theme.violet.withOpacity(0.4)
                              : theme.border),
                    ),
                    child: Text(b,
                        style: TextStyle(
                            color: sel ? theme.violet : theme.textMid,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList()),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _showDatePicker(StaffThemeProvider theme) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
          primary: theme.cyan,
          onPrimary: Colors.white,
          surface: theme.surface,
          onSurface: theme.textHigh,
        )),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _applySessionFilters();
    }
  }

  // ── SESSIONS LIST ─────────────────────────────────────────────────────────

  Widget _buildSessionsList(StaffThemeProvider theme) {
    if (_filteredSessions.isEmpty)
      return _buildEmpty(theme, 'No Sessions', 'No mentoring sessions found',
          Icons.meeting_room_outlined);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final card = _buildSessionCard(theme, _filteredSessions[i]);
        if (i >= _cardCtrls.length) return card;
        return FadeTransition(
            opacity: _cardFades[i],
            child: SlideTransition(position: _cardSlides[i], child: card));
      },
    );
  }

  Widget _buildSessionCard(
      StaffThemeProvider theme, Map<String, dynamic> session) {
    final name = session['student_name'] ?? 'Unknown';
    final id = session['student_id']?.toString() ?? '';
    final status = session['status'] ?? 'scheduled';
    final date = DateTime.parse(session['session_date']).toLocal();
    final nextRaw = session['next_session_date'];
    final next = nextRaw != null ? DateTime.tryParse(nextRaw)?.toLocal() : null;
    final color = _statusColor(theme, status);
    final details = session['details_matters'] is List &&
            (session['details_matters'] as List).isNotEmpty
        ? (session['details_matters'] as List).first
        : null;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _openStudentProfile(session['student_id'].toString(), session),
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withOpacity(0.18),
                      color.withOpacity(0.08)
                    ]),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('ID: $id',
                          style: TextStyle(color: theme.textMid, fontSize: 11)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              // Date row
              Row(children: [
                Expanded(
                    child: _dateChip(
                        theme,
                        Icons.calendar_today_rounded,
                        'Session',
                        DateFormat('d MMM yyyy').format(date),
                        theme.cyan)),
                const SizedBox(width: 10),
                Expanded(
                    child: _dateChip(
                        theme,
                        Icons.next_plan_rounded,
                        'Next',
                        next != null
                            ? DateFormat('d MMM yyyy').format(next)
                            : 'Not set',
                        next != null ? theme.amber : theme.textLow)),
              ]),
              if (details != null &&
                  (details['attendance'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.assignment_rounded,
                        size: 13, color: theme.textMid),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Attendance: ${details['attendance']}',
                            style:
                                TextStyle(color: theme.textHigh, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              // Actions
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _actionBtn(theme, Icons.visibility_outlined, theme.violet,
                    () => _openStudentProfile(id, session)),
                if (status != 'completed')
                  GestureDetector(
                    onTap: () => _showCreateSession(id, name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [theme.violet, theme.cyan]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: theme.violet.withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(children: [
                        const Icon(Icons.add_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        const Text('New Session',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  )
                else
                  Row(children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: theme.green),
                    const SizedBox(width: 5),
                    Text('Session Done',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.green,
                            fontWeight: FontWeight.w700)),
                  ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dateChip(StaffThemeProvider theme, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: theme.textMid,
                  fontSize: 9,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ── MENTEES LIST ──────────────────────────────────────────────────────────

  Widget _buildMenteesList(StaffThemeProvider theme) {
    if (_filteredMentees.isEmpty)
      return _buildEmpty(
          theme, 'No Mentees', 'No mentees assigned', Icons.group_off_rounded);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredMentees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final card = _buildMenteeCard(
            theme, Map<String, dynamic>.from(_filteredMentees[i]));
        if (i >= _cardCtrls.length) return card;
        return FadeTransition(
            opacity: _cardFades[i],
            child: SlideTransition(position: _cardSlides[i], child: card));
      },
    );
  }

  Widget _buildMenteeCard(StaffThemeProvider theme, Map<String, dynamic> m) {
    final name = m['student_name'] ?? 'Unknown';
    final id = m['student_id']?.toString() ?? '';
    final prog = m['program_type'] ?? 'UG';
    final batch = m['batch'] ?? '';
    final stream = m['stream'] ?? '';
    final color = prog == 'PG' ? theme.amber : theme.violet;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openStudentProfile(id, m),
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withOpacity(0.07),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withOpacity(0.18),
                      color.withOpacity(0.08)
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.22)),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('Roll: $id',
                          style: TextStyle(color: theme.textMid, fontSize: 11)),
                      if (stream.isNotEmpty)
                        Text(stream,
                            style:
                                TextStyle(color: theme.textLow, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(prog,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Active',
                        style: TextStyle(
                            color: theme.green,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _infoTag(theme, Icons.category_rounded, batch, theme.cyan),
                const SizedBox(width: 8),
                _infoTag(theme, Icons.school_rounded, prog, color),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _actionBtn(theme, Icons.visibility_outlined, theme.violet,
                    () => _openStudentProfile(id, m)),
                GestureDetector(
                  onTap: () => _showCreateSession(id, name),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      const Text('Session',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoTag(
      StaffThemeProvider theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _actionBtn(StaffThemeProvider theme, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ── REPORTS ───────────────────────────────────────────────────────────────

  Widget _buildReports(StaffThemeProvider theme) {
    final total = _mentorStats?['total'] ?? 0;
    final done = _mentorStats?['completed'] ?? 0;
    final sched = _mentorStats?['scheduled'] ?? 0;
    final mentees = _assignedMentees.length;
    final ug = _assignedMentees.where((m) => m['program_type'] == 'UG').length;
    final pg = _assignedMentees.where((m) => m['program_type'] == 'PG').length;
    final rate = total > 0 ? done / total : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _animated(
          0,
          _sectionCard(theme, 'Session Overview', theme.cyan, [
            _progressRow(theme, 'Completed', done, total, theme.green),
            const SizedBox(height: 10),
            _progressRow(theme, 'Scheduled', sched, total, theme.amber),
            const SizedBox(height: 10),
            _progressRow(theme, 'Cancelled', (_mentorStats?['cancelled'] ?? 0),
                total, theme.pink),
          ])),
      const SizedBox(height: 12),
      _animated(
          1,
          _sectionCard(theme, 'Mentee Distribution', theme.violet, [
            Row(children: [
              Expanded(child: _distCard(theme, 'UG', ug, mentees, theme.cyan)),
              const SizedBox(width: 10),
              Expanded(child: _distCard(theme, 'PG', pg, mentees, theme.amber)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _distCard(
                      theme, 'Total Mentees', mentees, mentees, theme.violet)),
              const SizedBox(width: 10),
              Expanded(
                  child: _distCard(theme, 'Completion Rate',
                      (rate * 100).toInt(), 100, theme.green,
                      suffix: '%')),
            ]),
          ])),
      const SizedBox(height: 12),
      if (_allSessions.isNotEmpty)
        _animated(
            2,
            _sectionCard(
                theme,
                'Recent Sessions',
                theme.amber,
                _allSessions
                    .sorted((a, b) => DateTime.parse(b['session_date'])
                        .compareTo(DateTime.parse(a['session_date'])))
                    .take(5)
                    .map((s) => _recentRow(theme, s))
                    .toList())),
    ]);
  }

  Widget _sectionCard(StaffThemeProvider theme, String title, Color color,
      List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 14)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.25))),
              child: Icon(Icons.analytics_rounded, color: color, size: 16)),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _progressRow(StaffThemeProvider theme, String label, int count,
      int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                color: theme.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        Text('$count (${(pct * 100).toInt()}%)',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: theme.elevated2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }

  Widget _distCard(
      StaffThemeProvider theme, String label, int value, int total, Color color,
      {String suffix = ''}) {
    final pct = total > 0 ? value / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: theme.textMid,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$value$suffix',
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: color.withOpacity(0.3), blurRadius: 6)
                ])),
        const SizedBox(height: 6),
        ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: theme.elevated2,
                valueColor: AlwaysStoppedAnimation(color))),
      ]),
    );
  }

  Widget _recentRow(StaffThemeProvider theme, Map<String, dynamic> s) {
    final status = s['status'] ?? 'scheduled';
    final color = _statusColor(theme, status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(
                status == 'completed'
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded,
                size: 16,
                color: color)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['student_name'] ?? 'Unknown',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(
              DateFormat('d MMM yyyy')
                  .format(DateTime.parse(s['session_date']).toLocal()),
              style: TextStyle(color: theme.textMid, fontSize: 10)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  // ── SHIMMER ───────────────────────────────────────────────────────────────

  Widget _buildShimmer(StaffThemeProvider theme) {
    return Column(
      children: List.generate(
          4,
          (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Shimmer.fromColors(
                  baseColor: theme.elevated,
                  highlightColor: theme.elevated2,
                  period: const Duration(milliseconds: 900),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: theme.elevated2,
                                    borderRadius: BorderRadius.circular(13))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Container(
                                      height: 13,
                                      width: 140,
                                      decoration: BoxDecoration(
                                          color: theme.elevated2,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                  const SizedBox(height: 6),
                                  Container(
                                      height: 10,
                                      width: 90,
                                      decoration: BoxDecoration(
                                          color: theme.elevated2,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ])),
                            Container(
                                width: 70,
                                height: 26,
                                decoration: BoxDecoration(
                                    color: theme.elevated2,
                                    borderRadius: BorderRadius.circular(10))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                        color: theme.elevated2,
                                        borderRadius:
                                            BorderRadius.circular(10)))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                        color: theme.elevated2,
                                        borderRadius:
                                            BorderRadius.circular(10)))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: theme.elevated2,
                                    borderRadius: BorderRadius.circular(11))),
                            const Spacer(),
                            Container(
                                width: 120,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: theme.elevated2,
                                    borderRadius: BorderRadius.circular(12))),
                          ]),
                        ]),
                  ),
                ),
              )),
    );
  }

  // ── EMPTY / ERROR ─────────────────────────────────────────────────────────

  Widget _buildEmpty(
      StaffThemeProvider theme, String title, String sub, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                theme.violet.withOpacity(0.1),
                theme.cyan.withOpacity(0.05)
              ]),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 46, color: theme.violet),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: theme.textMid, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildError(StaffThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 50, color: theme.pink),
          const SizedBox(height: 16),
          Text('Connection Error',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_errorMessage ?? 'Unknown error',
              style: TextStyle(color: theme.textMid, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchAllData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.violet, theme.cyan]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── NAVIGATION ────────────────────────────────────────────────────────────

  void _openStudentProfile(String studentId, Map<String, dynamic> data) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StudentProfileScreen(
                  studentId: studentId,
                  initialData: {
                    'student_id': studentId,
                    'student_name': data['student_name'] ?? data['name'],
                    'program_type': data['program_type'] ?? 'UG',
                    'batch': data['batch'] ?? '',
                    'stream': data['stream'] ?? '',
                    'active_status': true,
                  },
                )));
  }

  void _showCreateSession(String studentId, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.staffTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.staffTheme.border),
        ),
        child:
            CreateSessionSheet(studentId: studentId, studentName: studentName),
      ),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.staffThemeWatch;
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(currentRoute: '/mentoring'),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Column(children: [
            _buildTabBar(theme),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: theme.violet,
                backgroundColor: theme.surface,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  child: Column(children: [
                    _buildStatsRow(theme),
                    const SizedBox(height: 12),
                    _buildSearchBar(theme),
                    const SizedBox(height: 10),
                    _buildFilterChips(theme),
                    const SizedBox(height: 14),
                    SlideTransition(
                      position: _tabSlide,
                      child: FadeTransition(
                        opacity: _tabFade,
                        child: _isLoading
                            ? _buildShimmer(theme)
                            : _errorMessage != null
                                ? _buildError(theme)
                                : _currentTab == 0
                                    ? _buildSessionsList(theme)
                                    : _currentTab == 1
                                        ? _buildMenteesList(theme)
                                        : _buildReports(theme),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

extension _ListSort<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

// ══════════════════════════════════════════════════════════════════════════════
// CREATE SESSION SHEET
// ══════════════════════════════════════════════════════════════════════════════

class CreateSessionSheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  const CreateSessionSheet(
      {super.key, required this.studentId, required this.studentName});

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  DateTime _sessionDate = DateTime.now();
  DateTime? _nextDate;

  final _attendance = TextEditingController();
  final _academic = TextEditingController();
  final _arrears = TextEditingController();
  final _personalGoals = TextEditingController();
  final _profGoals = TextEditingController();
  final _talents = TextEditingController();
  final _feedback = TextEditingController();
  final _positive = TextEditingController();
  final _corrective = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _attendance,
      _academic,
      _arrears,
      _personalGoals,
      _profGoals,
      _talents,
      _feedback,
      _positive,
      _corrective
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final staffId = auth.userData?['staff_id'];
      final dept = auth.userData?['department_code'];
      if (staffId == null || dept == null)
        throw Exception('Missing credentials');

      final body = {
        "session_date": DateFormat('yyyy-MM-dd').format(_sessionDate),
        "details_matters": {
          "attendance": _attendance.text.trim(),
          "academicPerformance": _academic.text.trim(),
          "arrears": _arrears.text.trim(),
          "personalGoals": _personalGoals.text.trim(),
          "professionalGoals": _profGoals.text.trim(),
          "talents": _talents.text.trim(),
          "others": "",
          "othersSpecify": "",
        },
        "mentor_feedback": _feedback.text.trim(),
        "positive_traits": _positive.text.trim(),
        "corrective_measures": _corrective.text.trim(),
        "status": "completed",
        if (_nextDate != null)
          "next_session_date": DateFormat('yyyy-MM-dd').format(_nextDate!),
      };

      final res = await http
          .post(
            Uri.parse(
                'https://apierp.bhc.edu.in/api/staff/mentorship/$dept/$staffId/${widget.studentId}/session'),
            headers: {
              'Referer': 'http://117.232.64.75',
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));

      if ((res.statusCode == 200 || res.statusCode == 201) &&
          json.decode(res.body)['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          _snack('Session created successfully!', true);
        }
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      _snack('Failed: $e', false);
      setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, bool ok) {
    final theme = context.read<StaffThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? theme.success : theme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.staffThemeWatch;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.violet, theme.cyan]),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Create Session',
                      style: TextStyle(
                          color: theme.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text(widget.studentName,
                      style: TextStyle(color: theme.textMid, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            IconButton(
              icon: Icon(Icons.close_rounded, color: theme.textMid),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          Divider(color: theme.border, height: 20),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dateRow(theme, 'Session Date *', _sessionDate, false),
                      _field(theme, 'Attendance *', _attendance,
                          required: true),
                      _field(theme, 'Academic Performance *', _academic,
                          required: true, lines: 2),
                      _field(theme, 'Arrears', _arrears),
                      _field(theme, 'Personal Goals *', _personalGoals,
                          required: true, lines: 2),
                      _field(theme, 'Professional Goals *', _profGoals,
                          required: true, lines: 2),
                      _field(theme, 'Talents', _talents),
                      _field(theme, 'Mentor Feedback *', _feedback,
                          required: true, lines: 3),
                      _field(theme, 'Positive Traits *', _positive,
                          required: true, lines: 2),
                      _field(theme, 'Corrective Measures *', _corrective,
                          required: true, lines: 2),
                      _dateRow(theme, 'Next Meeting Date', _nextDate, true),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [theme.violet, theme.cyan]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: theme.violet.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: TextButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Create Session',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(
      StaffThemeProvider theme, String label, TextEditingController ctrl,
      {bool required = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: theme.textHigh,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: theme.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border)),
          child: TextFormField(
            controller: ctrl,
            maxLines: lines,
            style: TextStyle(color: theme.textHigh, fontSize: 13),
            decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
          ),
        ),
      ]),
    );
  }

  Widget _dateRow(StaffThemeProvider theme, String label, DateTime? current,
      bool optional) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: theme.textHigh,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                primary: theme.violet,
                onPrimary: Colors.white,
                surface: theme.surface,
                onSurface: theme.textHigh,
              )),
              child: child!,
            ),
          );
          if (picked != null && mounted) {
            setState(() {
              if (optional)
                _nextDate = picked;
              else
                _sessionDate = picked;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              color: theme.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border)),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, color: theme.violet, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              current != null
                  ? DateFormat('dd MMMM yyyy').format(current)
                  : 'Select date',
              style: TextStyle(
                  color: current != null ? theme.textHigh : theme.textLow,
                  fontSize: 13),
            )),
            if (optional && current != null)
              GestureDetector(
                onTap: () => setState(() => _nextDate = null),
                child:
                    Icon(Icons.close_rounded, size: 16, color: theme.textMid),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STUDENT PROFILE SCREEN  (matches profile.dart style)
// ══════════════════════════════════════════════════════════════════════════════

class StudentProfileScreen extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> initialData;
  const StudentProfileScreen(
      {super.key, required this.studentId, required this.initialData});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  String? _photoUrl;
  List<dynamic> _sessions = [];

  late AnimationController _appBarGlow;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _stagger = List.generate(
        6,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
            ));
    _fetchAll();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchStudent(), _fetchPhoto(), _fetchSessions()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _staggerCtrl.forward();
    }
  }

  Future<void> _fetchStudent() async {
    try {
      final res = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/students/${widget.studentId}'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = json.decode(res.body) as Map<String, dynamic>;
        if (d['success'] == true) setState(() => _studentData = d['data']);
      }
    } catch (_) {}
    _studentData ??= widget.initialData;
  }

  Future<void> _fetchPhoto() async {
    try {
      final url =
          'https://apierp.bhc.edu.in/photos/uploads/${widget.studentId}';
      final res = await http.head(Uri.parse(url));
      if (res.statusCode == 200) setState(() => _photoUrl = url);
    } catch (_) {}
  }

  Future<void> _fetchSessions() async {
    try {
      final auth = context.read<AuthProvider>();
      final dept = auth.userData?['department_code'];
      final staffId = auth.userData?['staff_id'];
      if (dept == null || staffId == null) return;
      final res = await http.get(
        Uri.parse(
            'https://apierp.bhc.edu.in/api/staff/mentorship/get_department_session/$dept'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = json.decode(res.body) as Map<String, dynamic>;
        if (d['success'] == true) {
          final all = (d['data'] as List)
              .where((s) =>
                  s['student_id'].toString() == widget.studentId &&
                  s['mentor_id'] == staffId)
              .toList();
          all.sort((a, b) => DateTime.parse(b['session_date'])
              .compareTo(DateTime.parse(a['session_date'])));
          setState(() => _sessions = all);
        }
      }
    } catch (_) {}
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(_stagger[i]),
          child: child,
        ),
      );

  // ── APP BAR ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.violet.withOpacity(0.2 + _appBarGlow.value * 0.15),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    theme.violet.withOpacity(0.06 + _appBarGlow.value * 0.04),
                blurRadius: 20,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: theme.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: theme.textHigh, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: theme.violet.withOpacity(0.3), blurRadius: 10)
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.elevated,
                      child: Icon(Icons.school_rounded,
                          color: theme.violet, size: 16),
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
                      Text('Student Profile',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      Text('Mentee Details',
                          style: TextStyle(
                              color: theme.violet.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.green.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.green,
                      boxShadow: [
                        BoxShadow(
                            color: theme.green.withOpacity(0.6), blurRadius: 4)
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('ACTIVE',
                      style: TextStyle(
                          color: theme.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ]),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),
      ),
    );
  }

  // ── HERO HEADER ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader(StaffThemeProvider theme) {
    final data = _studentData ?? widget.initialData;
    final name = data['name'] ?? data['student_name'] ?? 'Student';
    final prog = data['program_type'] ?? 'UG';
    final batch = data['batch'] ?? '';
    final stream = data['stream'] ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.elevated, theme.elevated2, theme.surface],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Stack(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32)),
          child: CustomPaint(
            painter: _GridPainter(color: theme.violet.withOpacity(0.04)),
            size: const Size(double.infinity, 360),
          ),
        ),
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) => Positioned(
            top: -30 + _glowCtrl.value * 10,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.violet.withOpacity(0.05 + _glowCtrl.value * 0.03),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(children: [
            Stack(alignment: Alignment.bottomRight, children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 106 + _pulseCtrl.value * 4,
                  height: 106 + _pulseCtrl.value * 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.violet
                        .withOpacity(0.08 + _pulseCtrl.value * 0.04),
                    boxShadow: [
                      BoxShadow(
                          color: theme.violet
                              .withOpacity(0.25 + _pulseCtrl.value * 0.1),
                          blurRadius: 24)
                    ],
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.violet.withOpacity(0.5), width: 2.5),
                  color: theme.elevated,
                ),
                child: ClipOval(
                  child: _photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _photoUrl!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://apierp.bhc.edu.in'
                          },
                          placeholder: (_, __) => Container(
                            color: theme.elevated,
                            child: Center(
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: theme.violet))),
                          ),
                          errorWidget: (_, __, ___) =>
                              _avatarFallback(theme, name),
                        )
                      : _avatarFallback(theme, name),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: theme.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.bg, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: theme.green.withOpacity(0.5), blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.verified_rounded,
                    size: 14, color: Colors.black),
              ),
            ]),
            const SizedBox(height: 18),
            Text(name,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.textHigh,
                    letterSpacing: -0.3,
                    height: 1.1),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.violet.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.violet.withOpacity(0.35)),
              ),
              child: Text(widget.studentId,
                  style: TextStyle(
                      color: theme.violet,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            if (stream.isNotEmpty)
              Text(stream,
                  style: TextStyle(
                      color: theme.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            if (batch.isNotEmpty)
              Text(batch, style: TextStyle(color: theme.textLow, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, children: [
              _quickBadge(theme, Icons.school_rounded, prog,
                  prog == 'PG' ? theme.amber : theme.cyan),
              _quickBadge(
                  theme, Icons.check_circle_rounded, 'Active', theme.green),
              _quickBadge(theme, Icons.groups_rounded, 'Mentee', theme.violet),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final data = _studentData ?? widget.initialData;
                  final nm = data['name'] ?? data['student_name'] ?? '';
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        border: Border.all(color: theme.border),
                      ),
                      child: CreateSessionSheet(
                          studentId: widget.studentId, studentName: nm),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [theme.green, theme.green.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: theme.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        const Text('CREATE MENTORING SESSION',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _avatarFallback(StaffThemeProvider theme, String name) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').length > 1
            ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
                .toUpperCase()
            : name.trim()[0].toUpperCase();
    return Container(
      color: theme.elevated,
      child: Center(
          child: Text(initials,
              style: TextStyle(
                  color: theme.violet,
                  fontSize: 32,
                  fontWeight: FontWeight.w700))),
    );
  }

  Widget _quickBadge(
      StaffThemeProvider theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── INFO CARD ─────────────────────────────────────────────────────────────

  Widget _infoCard(StaffThemeProvider theme, String title, IconData icon,
      Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 16)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 1)),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(children: rows)),
      ]),
    );
  }

  Widget _infoRow(StaffThemeProvider theme, String label, String value,
      {IconData? icon, Color? color}) {
    final display = value.isNotEmpty ? value : 'Not Available';
    final hasValue = value.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (color ?? theme.textLow).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: (color ?? theme.textLow).withOpacity(0.2)),
            ),
            child: Icon(icon, size: 15, color: color ?? theme.textMid),
          ),
          const SizedBox(width: 12),
        ] else
          const SizedBox(width: 44),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textMid,
                  fontSize: 11,
                  letterSpacing: 0.2)),
          const SizedBox(height: 3),
          Text(display,
              style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? theme.textHigh : theme.textLow,
                  fontWeight: FontWeight.w500,
                  height: 1.4)),
        ])),
      ]),
    );
  }

  // ── SESSION HISTORY ───────────────────────────────────────────────────────

  Widget _buildSessionHistory(StaffThemeProvider theme) {
    if (_sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: theme.elevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(children: [
          Icon(Icons.meeting_room_outlined, size: 42, color: theme.textLow),
          const SizedBox(height: 10),
          Text('No Sessions Yet',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textMid)),
          const SizedBox(height: 4),
          Text('No mentoring sessions conducted yet.',
              style: TextStyle(fontSize: 12, color: theme.textLow)),
        ]),
      );
    }
    return Column(
        children: _sessions.map((s) {
      final status = s['status'] ?? 'scheduled';
      final date = DateTime.parse(s['session_date']).toLocal();
      final nextRaw = s['next_session_date'];
      final next =
          nextRaw != null ? DateTime.tryParse(nextRaw)?.toLocal() : null;
      final details = s['details_matters'] is List &&
              (s['details_matters'] as List).isNotEmpty
          ? (s['details_matters'] as List).first
          : {};
      final color = status == 'completed'
          ? theme.green
          : status == 'scheduled'
              ? theme.amber
              : theme.pink;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    status == 'completed'
                        ? Icons.check_circle_rounded
                        : status == 'scheduled'
                            ? Icons.schedule_rounded
                            : Icons.cancel_rounded,
                    size: 17,
                    color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(DateFormat('dd MMM yyyy').format(date),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textHigh))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border)),
                child: Column(children: [
                  if ((details['attendance'] ?? '').toString().isNotEmpty)
                    _sessionDetailRow(
                        theme, 'Attendance', details['attendance'].toString()),
                  if ((details['academicPerformance'] ?? '')
                      .toString()
                      .isNotEmpty)
                    _sessionDetailRow(theme, 'Academic',
                        details['academicPerformance'].toString()),
                  if ((details['arrears'] ?? '').toString().isNotEmpty)
                    _sessionDetailRow(
                        theme, 'Arrears', details['arrears'].toString()),
                ]),
              ),
            ],
            if ((s['mentor_feedback'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FEEDBACK',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: theme.textMid,
                              letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(s['mentor_feedback'].toString(),
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textHigh,
                              height: 1.4)),
                    ]),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: theme.textMid),
                const SizedBox(width: 6),
                Text('Next: ${DateFormat('dd MMM yyyy').format(next)}',
                    style: TextStyle(fontSize: 12, color: theme.textHigh)),
              ]),
            ],
          ]),
        ),
      );
    }).toList());
  }

  Widget _sessionDetailRow(
      StaffThemeProvider theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: theme.textMid,
                    fontWeight: FontWeight.w500))),
        Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: theme.textHigh))),
      ]),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final data = _studentData ?? widget.initialData;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: theme.violet
                            .withOpacity(0.08 + _pulseCtrl.value * 0.04),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: theme.violet.withOpacity(0.3)),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.violet,
                            backgroundColor: theme.violet.withOpacity(0.1)),
                        Icon(Icons.person_rounded,
                            size: 24, color: theme.violet.withOpacity(0.6)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Loading Profile…',
                      style: TextStyle(
                          fontSize: 14,
                          color: theme.textMid,
                          fontWeight: FontWeight.w600)),
                ]))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(children: [
                _buildHeroHeader(theme),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(children: [
                    _animated(
                        0,
                        _infoCard(theme, 'PERSONAL INFORMATION',
                            Icons.person_rounded, theme.cyan, [
                          _infoRow(theme, 'Full Name',
                              data['name'] ?? data['student_name'] ?? '',
                              icon: Icons.person_outline_rounded,
                              color: theme.cyan),
                          _infoRow(theme, 'Roll Number', widget.studentId,
                              icon: Icons.badge_rounded, color: theme.violet),
                          _infoRow(theme, 'Mobile',
                              data['contact']?['mobile_no']?.toString() ?? '',
                              icon: Icons.phone_rounded, color: theme.green),
                          _infoRow(theme, 'Email',
                              data['contact']?['student_email'] ?? '',
                              icon: Icons.email_rounded, color: theme.amber),
                        ])),
                    const SizedBox(height: 14),
                    _animated(
                        1,
                        _infoCard(theme, 'ACADEMIC INFORMATION',
                            Icons.school_rounded, theme.violet, [
                          _infoRow(
                              theme,
                              'Program',
                              data['current_academic']?['program_name'] ??
                                  data['program_type'] ??
                                  '',
                              icon: Icons.book_rounded,
                              color: theme.violet),
                          _infoRow(
                              theme,
                              'Department',
                              data['current_academic']?['department_name'] ??
                                  '',
                              icon: Icons.business_rounded,
                              color: theme.cyan),
                          _infoRow(theme, 'Section',
                              data['current_academic']?['section'] ?? '',
                              icon: Icons.category_rounded, color: theme.amber),
                          _infoRow(theme, 'Batch', data['batch'] ?? '',
                              icon: Icons.group_rounded, color: theme.green),
                        ])),
                    const SizedBox(height: 14),
                    _animated(
                        2,
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Mentoring Sessions',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: theme.textHigh)),
                                    Text('${_sessions.length} total',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textMid)),
                                  ]),
                              const SizedBox(height: 12),
                              _buildSessionHistory(theme),
                            ])),
                  ]),
                ),
              ]),
            ),
    );
  }
}

// ── Grid Painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const sp = 28.0;
    for (double x = 0; x <= size.width; x += sp)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += sp)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
