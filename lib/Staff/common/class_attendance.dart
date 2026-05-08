import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'dart:convert';
import 'dart:async';

const String _kBaseApiUrl = 'https://apierp.bhc.edu.in';
const String _kRefererUrl = 'http://117.232.64.75';

class ProfessionalClassAttendanceScreen extends StatefulWidget {
  final String staffId;
  final Map<String, dynamic>? selectedClass;
  final DateTime? selectedDate;
  final int? selectedDayOrder;
  final List<int>? selectedHours;
  final Map<String, dynamic>? preselectedClass;
  final int? preselectedDayOrder;
  final List<int>? preselectedHours;
  final String? baseApiUrl;
  final String? refererUrl;

  const ProfessionalClassAttendanceScreen({
    super.key,
    required this.staffId,
    this.selectedClass,
    this.selectedDate,
    this.selectedDayOrder,
    this.selectedHours,
    this.preselectedClass,
    this.preselectedDayOrder,
    this.preselectedHours,
    this.baseApiUrl,
    this.refererUrl,
  });

  @override
  State<ProfessionalClassAttendanceScreen> createState() =>
      _ProfessionalClassAttendanceScreenState();
}

class _ProfessionalClassAttendanceScreenState
    extends State<ProfessionalClassAttendanceScreen>
    with TickerProviderStateMixin {

  // ── Animations ──────────────────────────────────────────────────
  late AnimationController _appBarGlow;
  late AnimationController _pageEnter;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  // ── State ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _assignedClasses = [];
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  List<String> _classOptions = [];
  Map<String, Map<String, dynamic>> _classDetails = {};
  String? _selectedClass;
  int? _selectedDayOrder;
  List<int> _selectedHours = [];
  String? _staffId;
  Map<int, List<int>> _yourAssignedHours = {};
  final List<int> _allDayOrders = [1, 2, 3, 4, 5, 6];
  final List<int> _allHours = [1, 2, 3, 4, 5];

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.preselectedClass != null) {
      _selectedDayOrder = widget.preselectedDayOrder;
      _selectedHours = widget.preselectedHours ?? [];
    }
    _initialize();
  }

  void _initAnimations() {
    _appBarGlow = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pageEnter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _stagger = List.generate(
        6,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.12, 1.0, curve: Curves.easeOutCubic),
            ));
    _pageFade =
        CurvedAnimation(parent: _pageEnter, curve: Curves.easeOut);
    _pageSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _pageEnter, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageEnter.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_stagger[i]),
          child: child,
        ),
      );

  // ── Init & Fetch ─────────────────────────────────────────────────
  void _initialize() {
    final auth = context.read<AuthProvider>();
    _staffId = auth.userData?['staff_id'] ?? widget.staffId;
    if (_staffId != null) {
      _fetchClasses().then((_) {
        if (mounted && widget.preselectedClass != null) {
          setState(() {
            _selectedClass =
                _findFormattedClassName(widget.preselectedClass!);
            _selectedDayOrder = widget.preselectedDayOrder;
            _selectedHours = widget.preselectedHours ?? [];
          });
        }
      });
    } else {
      setState(() {
        _errorMessage = 'Staff ID not found';
        _isLoading = false;
      });
    }
  }

  Map<String, String> get _headers => {
        'Referer': _kRefererUrl,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _httpGet(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers.addAll(_headers);
      final streamed =
          await client.send(req).timeout(const Duration(seconds: 10));
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<void> _fetchClasses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final res = await _httpGet('$_kBaseApiUrl/api/staff/$_staffId');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final classes = data['class_attend'] as List? ?? [];
        _assignedClasses = classes.where((c) {
          final p = (c as Map<String, dynamic>)['program_id']?.toString() ?? '';
          return p.startsWith('UG-') || p.startsWith('PG-');
        }).map((e) => {
              'program_id': e['program_id']?.toString() ?? '',
              'year': e['year']?.toString() ?? '',
              'section_name': e['section_name']?.toString() ?? '',
              'shift': e['shift']?.toString() ?? '1',
              'dayOrder': e['dayOrder'] != null
                  ? int.tryParse(e['dayOrder'].toString()) ?? 0
                  : null,
              'hour': e['hour'] != null
                  ? int.tryParse(e['hour'].toString()) ?? 0
                  : null,
            }).toList();
        _formatClassOptions();
        if (mounted) {
          setState(() => _isLoading = false);
          _staggerCtrl.forward();
        }
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
    }
  }

 void _formatClassOptions() {
  final map = <String, Map<String, dynamic>>{};
  for (var cls in _assignedClasses) {
    final p = cls['program_id']?.toString() ?? '';
    final y = cls['year']?.toString() ?? '';
    final s = cls['section_name']?.toString() ?? '';
    final sh = cls['shift']?.toString() ?? '1';

    if (p.isEmpty) continue;

    final name = _formatProgramId(p, y, s, sh);
    map[name] = cls;
  }
  setState(() {
    _classDetails = map;
    _classOptions = map.keys.toList()..sort();
  });
}


  void _onClassSelected(String? val) {
    setState(() {
      _selectedClass = val;
      _selectedDayOrder = null;
      _selectedHours.clear();
      if (val != null && _classDetails.containsKey(val)) {
        final cls = _classDetails[val]!;
        final hours = <int, List<int>>{};
        for (var c in _assignedClasses) {
          if (c['program_id'] == cls['program_id'] &&
              c['year'] == cls['year'] &&
              c['section_name'] == cls['section_name'] &&
              c['dayOrder'] != null &&
              c['hour'] != null) {
            hours
                .putIfAbsent(c['dayOrder'], () => [])
                .add(c['hour']);
          }
        }
        hours.forEach((k, v) => v.sort());
        _yourAssignedHours = hours;
      }
    });
  }

  void _toggleHour(int h) {
    setState(() {
      if (_selectedHours.contains(h)) {
        _selectedHours.remove(h);
      } else {
        _selectedHours.add(h);
      }
      _selectedHours.sort();
    });
  }

  void _navigateToMark() async {
    if (_selectedClass == null) {
      _snack('Please select a class');
      return;
    }
    if (_selectedDayOrder == null) {
      _snack('Please select a day order');
      return;
    }
    if (_selectedHours.isEmpty) {
      _snack('Please select at least one hour');
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessionalMarkAttendanceScreen(
          staffId: _staffId!,
          selectedClass: _classDetails[_selectedClass]!,
          selectedDate: _selectedDate,
          selectedDayOrder: _selectedDayOrder!,
          selectedHours: _selectedHours,
        ),
      ),
    );
    if (result == true) _snack('Attendance marked!', ok: true);
  }

  void _snack(String msg, {bool ok = false}) {
    final theme = context.read<StaffThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? theme.green : theme.pink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String? _findFormattedClassName(Map<String, dynamic> cls) {
    for (var e in _classDetails.entries) {
      if (e.value['program_id'] == cls['program_id'] &&
          e.value['year'].toString() == cls['year'].toString() &&
          e.value['section_name'] == cls['section_name']) return e.key;
    }
    return null;
  }

  // ── App Bar ───────────────────────────────────────────────────────
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
                  color: theme.cyan
                      .withOpacity(0.15 + _appBarGlow.value * 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                  color: theme.cyan
                      .withOpacity(0.05 + _appBarGlow.value * 0.04),
                  blurRadius: 20)
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
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class Attendance',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                      Text('Mark & Track',
                          style: TextStyle(
                              color: theme.cyan.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: theme.cyan.withOpacity(0.3)),
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
                    Text('LIVE',
                        style: TextStyle(
                            color: theme.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ]),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: theme.textMid, size: 20),
                  onPressed: _fetchClasses,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.staffThemeWatch;
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(
          isHod: _isHod, currentRoute: '/class-attendance'),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: _isLoading
              ? _buildLoading(theme)
              : _errorMessage.isNotEmpty
                  ? _buildError(theme)
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      child: Column(children: [
                        _animated(0, _buildDateCard(theme)),
                        const SizedBox(height: 14),
                        _animated(1, _buildClassCard(theme)),
                        if (_selectedClass != null) ...[
                          const SizedBox(height: 14),
                          _animated(2, _buildDayCard(theme)),
                        ],
                        if (_selectedDayOrder != null) ...[
                          const SizedBox(height: 14),
                          _animated(3, _buildHourCard(theme)),
                        ],
                        if (_selectedHours.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _animated(4, _buildProceedButton(theme)),
                        ],
                      ]),
                    ),
        ),
      ),
    );
  }

  // ── Date Card ─────────────────────────────────────────────────────
  Widget _buildDateCard(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.cyan.withOpacity(theme.isDarkMode ? 0.12 : 0.07),
            theme.violet.withOpacity(theme.isDarkMode ? 0.06 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.cyan.withOpacity(0.22)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [theme.cyan, theme.violet]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: theme.cyan.withOpacity(0.35), blurRadius: 10)
            ],
          ),
          child: const Icon(Icons.calendar_today_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            Text('Tap to change date',
                style:
                    TextStyle(color: theme.textMid, fontSize: 11)),
          ]),
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
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
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [theme.cyan, theme.violet]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: theme.cyan.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Text('Change',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ── Class Card ────────────────────────────────────────────────────
  Widget _buildClassCard(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
              color: theme.cyan.withOpacity(0.05), blurRadius: 14)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.cyan.withOpacity(0.25)),
            ),
            child:
                Icon(Icons.class_rounded, color: theme.cyan, size: 16),
          ),
          const SizedBox(width: 10),
          Text('Select Class',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_classOptions.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_classOptions.length} classes',
                  style: TextStyle(
                      color: theme.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: theme.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _selectedClass != null
                    ? theme.cyan.withOpacity(0.4)
                    : theme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedClass,
              isExpanded: true,
              dropdownColor: theme.surface,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child:
                    Icon(Icons.keyboard_arrow_down_rounded, color: theme.textMid),
              ),
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Choose your class...',
                    style: TextStyle(color: theme.textLow, fontSize: 13)),
              ),
              items: _classOptions.map((o) {
                return DropdownMenuItem<String>(
                  value: o,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(o,
                        style:
                            TextStyle(color: theme.textHigh, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: _onClassSelected,
            ),
          ),
        ),
        if (_selectedClass != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.cyan.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: theme.cyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_selectedClass!,
                    style: TextStyle(
                        color: theme.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Day Card ──────────────────────────────────────────────────────
Widget _buildDayCard(StaffThemeProvider theme) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.border),
      boxShadow: [
        BoxShadow(color: theme.violet.withOpacity(0.05), blurRadius: 14)
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.violet.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: theme.violet.withOpacity(0.25)),
          ),
          child: Icon(Icons.calendar_view_day_rounded,
              color: theme.violet, size: 14),
        ),
        const SizedBox(width: 8),
        Text('Day Order',
            style: TextStyle(
                color: theme.textHigh,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_selectedDayOrder != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.violet, theme.cyan]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: theme.violet.withOpacity(0.3), blurRadius: 6)
              ],
            ),
            child: Text('Day $_selectedDayOrder',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: 14),
      Row(
        children: _allDayOrders.map((day) {
          final isSel = _selectedDayOrder == day;
          final hasClass = _yourAssignedHours.containsKey(day);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedDayOrder = day;
                _selectedHours.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(
                    right: day != _allDayOrders.last ? 6 : 0),
                height: 46,
                decoration: BoxDecoration(
                  gradient: isSel
                      ? LinearGradient(
                          colors: [theme.violet, theme.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: isSel
                      ? null
                      : hasClass
                          ? theme.violet.withOpacity(0.07)
                          : theme.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel
                        ? Colors.transparent
                        : hasClass
                            ? theme.violet.withOpacity(0.35)
                            : theme.border,
                    width: isSel ? 0 : 1,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: theme.violet.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('D$day',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSel
                                  ? Colors.white
                                  : hasClass
                                      ? theme.violet
                                      : theme.textMid)),
                      if (hasClass)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? Colors.white : theme.violet,
                          ),
                        ),
                    ]),
              ),
            ),
          );
        }).toList(),
      ),
    ]),
  );
}


  // ── Hour Card ─────────────────────────────────────────────────────
Widget _buildHourCard(StaffThemeProvider theme) {
  final assigned = _yourAssignedHours[_selectedDayOrder] ?? [];
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.border),
      boxShadow: [
        BoxShadow(color: theme.green.withOpacity(0.05), blurRadius: 14)
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: theme.green.withOpacity(0.25)),
          ),
          child: Icon(Icons.access_time_rounded, color: theme.green, size: 14),
        ),
        const SizedBox(width: 8),
        Text('Select Hours',
            style: TextStyle(
                color: theme.textHigh,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_selectedHours.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.green.withOpacity(0.3)),
            ),
            child: Text('${_selectedHours.length} selected',
                style: TextStyle(
                    color: theme.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: 12),
      // Quick picks
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          if (assigned.isNotEmpty) ...[
            _quickChip(theme, 'My Hours', assigned, theme.cyan),
            const SizedBox(width: 6),
          ],
          _quickChip(theme, 'H 1-3', [1, 2, 3], theme.violet),
          const SizedBox(width: 6),
          _quickChip(theme, 'All', [1, 2, 3, 4, 5], theme.amber),
        ]),
      ),
      const SizedBox(height: 12),
      // Hour buttons
      Row(
        children: _allHours.map((h) {
          final isSel = _selectedHours.contains(h);
          final isMine = assigned.contains(h);
          return Expanded(
            child: GestureDetector(
              onTap: () => _toggleHour(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                    right: h != _allHours.last ? 6 : 0),
                height: 48,
                decoration: BoxDecoration(
                  gradient: isSel
                      ? LinearGradient(
                          colors: [theme.green, theme.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: isSel
                      ? null
                      : isMine
                          ? theme.green.withOpacity(0.07)
                          : theme.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel
                        ? Colors.transparent
                        : isMine
                            ? theme.green.withOpacity(0.35)
                            : theme.border,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: theme.green.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('H$h',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSel
                                  ? Colors.white
                                  : isMine
                                      ? theme.green
                                      : theme.textMid)),
                      if (isMine && !isSel)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.green,
                          ),
                        ),
                    ]),
              ),
            ),
          );
        }).toList(),
      ),
      if (_selectedHours.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: theme.green.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.green.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.schedule_rounded, color: theme.green, size: 13),
            const SizedBox(width: 8),
            Text(
              'Selected: ${_selectedHours.map((h) => 'H$h').join(', ')}',
              style: TextStyle(
                  color: theme.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ],
    ]),
  );
}


  Widget _quickChip(
      StaffThemeProvider theme, String label, List<int> hours, Color color) {
    if (hours.isEmpty) return const SizedBox.shrink();
    final isSel = hours.every(_selectedHours.contains) &&
        _selectedHours.length == hours.length;
    return GestureDetector(
      onTap: () => setState(() => _selectedHours = List.from(hours)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSel
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.7)])
              : null,
          color: isSel ? null : theme.elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSel ? Colors.transparent : theme.border),
          boxShadow: isSel
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSel ? Colors.white : theme.textMid)),
      ),
    );
  }

  // ── Proceed Button ────────────────────────────────────────────────
  Widget _buildProceedButton(StaffThemeProvider theme) {
    return GestureDetector(
      onTap: _navigateToMark,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [theme.cyan, theme.violet]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: theme.cyan.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.people_alt_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Text('Load Students & Mark Attendance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────────
  Widget _buildLoading(StaffThemeProvider theme) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: theme.cyan.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: theme.cyan),
          ),
        ),
        const SizedBox(height: 16),
        Text('Loading schedule...',
            style: TextStyle(color: theme.textMid, fontSize: 14)),
      ]),
    );
  }

  Widget _buildError(StaffThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded,
              size: 56, color: theme.pink),
          const SizedBox(height: 16),
          Text('Unable to Load',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMid, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchClasses,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [theme.cyan, theme.violet]),
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
  

String _formatProgramId(String programId, String year, String section, String shift) {
  // Split by '-' → e.g. ['UG', 'BSC', 'CS'] or ['PG', 'MBA']
  final parts = programId.split('-');
  if (parts.isEmpty) return ' $year • $programId • Sec $section • Shift $shift';

  final level = parts[0].toUpperCase(); // UG / PG

  // Degree prefix map
  const degreeMap = {
    'UG': {
      'BSC': 'B.Sc',
      'BCA': 'BCA',
      'BBA': 'BBA',
      'BCOM': 'B.Com',
      'BA':   'B.A',
      'BCS':  'B.Cs',
      'BE':   'B.E',
      'BTECH':'B.Tech',
    },
    'PG': {
      'MSC':  'M.Sc',
      'MBA':  'MBA',
      'MCA':  'MCA',
      'MA':   'M.A',
      'MCOM': 'M.Com',
      'ME':   'M.E',
      'MTECH':'M.Tech',
      'MCS':  'M.Cs',
    },
  };

  String degreePrefix = '';
  int subjectStartIndex = 1; // default: subject starts at index 1

  if (parts.length >= 2) {
    final degreeKey = parts[1].toUpperCase();
    degreePrefix = degreeMap[level]?[degreeKey] ?? parts[1];
    subjectStartIndex = 2;
  } else {
    degreePrefix = level;
  }

  // Everything after degree = subject/specialization
  final subject = parts.length > subjectStartIndex
      ? parts.sublist(subjectStartIndex).join(' ').toUpperCase()
      : '';

  final prog = subject.isNotEmpty ? '$degreePrefix $subject' : degreePrefix;

  return ' $year • $prog • Sec $section • Shift $shift';
}

}
// ==========================================================================
//  MARK ATTENDANCE SCREEN
// ==========================================================================

class ProfessionalMarkAttendanceScreen extends StatefulWidget {
  final String staffId;
  final Map<String, dynamic> selectedClass;
  final DateTime selectedDate;
  final int selectedDayOrder;
  final List<int> selectedHours;

  // Kept for backwards compatibility — values are ignored.
  // URLs are hardcoded as _kBaseApiUrl / _kRefererUrl constants.
  // ignore: avoid_unused_constructor_parameters
  final String? baseApiUrl;
  // ignore: avoid_unused_constructor_parameters
  final String? refererUrl;

  const ProfessionalMarkAttendanceScreen({
    super.key,
    required this.staffId,
    required this.selectedClass,
    required this.selectedDate,
    required this.selectedDayOrder,
    required this.selectedHours,
    this.baseApiUrl,   // accepted but ignored — see _kBaseApiUrl
    this.refererUrl,   // accepted but ignored — see _kRefererUrl
  });

  @override
  State<ProfessionalMarkAttendanceScreen> createState() =>
      _ProfessionalMarkAttendanceScreenState();
}

class _ProfessionalMarkAttendanceScreenState
    extends State<ProfessionalMarkAttendanceScreen> {
  // ==================== COLOR SCHEME ====================
  final List<Color> _primaryGradient = const [
    Color(0xFF1E3A8A),
    Color(0xFF2563EB),
    Color(0xFF3B82F6),
  ];

  final Color _primaryDeep = const Color(0xFF1E3A8A);
  final Color _primaryRoyal = const Color(0xFF2563EB);
  final Color _primaryElectric = const Color(0xFF3B82F6);
  final Color _successGreen = const Color(0xFF10B981);
  final Color _warningOrange = const Color(0xFFF59E0B);
  final Color _dangerRed = const Color(0xFFEF4444);
  final Color _backgroundLight = const Color(0xFFF8FAFC);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF1F2937);
  final Color _textMedium = const Color(0xFF6B7280);
  final Color _textLight = const Color(0xFF9CA3AF);
  final Color _borderLight = const Color(0xFFE5E7EB);

  // State
  List<dynamic> _students = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRetrying = false;
  String _errorMessage = "";
  Map<String, String> _attendanceStatus = {};
  Map<String, Map<String, dynamic>> _existingAttendance = {};
  String _remarks = "";
  final TextEditingController _remarksController = TextEditingController();

  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _pendingCount = 0;

  String _searchQuery = "";
  String _filterStatus = "all";
  bool _showOnlyPending = false;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _showFloatingSummary = false;
  bool _showFloatingSaveButton = false;

  double _saveProgress = 0.0;
  String _saveStatus = "";

  final List<Map<String, dynamic>> _attendanceOptions = [
    {
      'value': 'present',
      'label': 'P',
      'icon': Icons.check_circle,
      'color': Color(0xFF10B981),
      'name': 'Present',
    },
    {
      'value': 'absent',
      'label': 'A',
      'icon': Icons.cancel,
      'color': Color(0xFFEF4444),
      'name': 'Absent',
    },
    {
      'value': 'late',
      'label': 'L',
      'icon': Icons.access_time,
      'color': Color(0xFFF59E0B),
      'name': 'Late',
    },
    {
      'value': 'not_marked',
      'label': '?',
      'icon': Icons.help_outline,
      'color': Color(0xFF9CA3AF),
      'name': 'Not Marked',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _remarksController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (offset > 200 && !_showFloatingSummary) {
      setState(() => _showFloatingSummary = true);
    } else if (offset <= 200 && _showFloatingSummary) {
      setState(() => _showFloatingSummary = false);
    }
    if (offset > 400 && !_showFloatingSaveButton) {
      setState(() => _showFloatingSaveButton = true);
    } else if (offset <= 400 && _showFloatingSaveButton) {
      setState(() => _showFloatingSaveButton = false);
    }
  }

  void _updateStats() {
    _presentCount =
        _attendanceStatus.values.where((s) => s == 'present').length;
    _absentCount =
        _attendanceStatus.values.where((s) => s == 'absent').length;
    _lateCount = _attendanceStatus.values.where((s) => s == 'late').length;
    _pendingCount =
        _attendanceStatus.values.where((s) => s == 'not_marked').length;
  }

  Map<String, String> get _headers => {
        'Referer': _kRefererUrl,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  // ==================== DATA FETCHING ====================

  Future<void> _fetchStudents() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _errorMessage = "";
      });

      final formattedDate =
          DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      String? batch = await _calculateBatch();

      if (batch == null) {
        batch = await _tryAlternativeBatchCalculations(formattedDate);
        if (batch == null) {
          if (!mounted) return;
          _safeSetState(() {
            _errorMessage =
                'Could not find valid batch for the selected class';
            _isLoading = false;
          });
          return;
        }
      }

      final url =
          "$_kBaseApiUrl/students/attendance/class/${widget.selectedClass['program_id']}/$batch/${widget.selectedClass['section_name']}/$formattedDate";

      final response = await _httpGetWithRetry(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final students = data['attendanceData'] ?? [];
        await _processStudentsData(students);
        if (!mounted) return;
        _safeSetState(() {
          _isLoading = false;
          _errorMessage = "";
          _updateStats();
        });
        if (_existingAttendance.isNotEmpty) {
          _showInfo(
              "Found ${_existingAttendance.length} existing attendance records");
        }
      } else {
        _safeSetState(() {
          _errorMessage =
              'Failed to load students. Status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        _errorMessage = "Error loading students: $e";
        _isLoading = false;
      });
    }
  }

  Future<http.Response> _httpGetWithRetry(String url,
      {int retryCount = 0}) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll(_headers);
        final streamedResponse = await client.send(request).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            client.close();
            throw TimeoutException('Request timed out');
          },
        );
        return await http.Response.fromStream(streamedResponse);
      } finally {
        client.close();
      }
    } on TimeoutException catch (e) {
      if (retryCount < 1) {
        await Future.delayed(Duration(seconds: 2));
        return _httpGetWithRetry(url, retryCount: retryCount + 1);
      } else {
        throw Exception('Request failed after retries: ${e.message}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _calculateBatch() async {
    final yearNum =
        int.parse(widget.selectedClass['year'].toString());
    if (widget.selectedClass['program_id'].toString().startsWith('PG-')) {
      const startYear = 2025;
      return '${startYear + yearNum - 1}-${startYear + yearNum + 1}';
    } else {
      const startYear = 2025;
      return '$startYear-${startYear + 3}';
    }
  }

  Future<String?> _tryAlternativeBatchCalculations(
      String formattedDate) async {
    final currentYear = DateTime.now().year;
    final yearNum =
        int.parse(widget.selectedClass['year'].toString());
    List<String> batchFormats = [];

    if (widget.selectedClass['program_id'].toString().startsWith('PG-')) {
      batchFormats = [
        '${currentYear + yearNum - 2}-${currentYear + yearNum}',
        '${currentYear + yearNum - 1}-${currentYear + yearNum + 1}',
        '${currentYear}-${currentYear + 2}',
      ];
    } else {
      batchFormats = [
        '${currentYear}-${currentYear + 3}',
        '${currentYear + yearNum - 1}-${currentYear + yearNum + 2}',
        '${currentYear - 1}-${currentYear + 2}',
      ];
    }

    for (final batch in batchFormats) {
      try {
        final url =
            "$_kBaseApiUrl/students/attendance/class/${widget.selectedClass['program_id']}/$batch/${widget.selectedClass['section_name']}/$formattedDate";
        final response = await _httpGetWithRetry(url);
        if (response.statusCode == 200) return batch;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  Future<void> _processStudentsData(List<dynamic> students) async {
    _students = students;
    _attendanceStatus.clear();
    _existingAttendance.clear();

    const chunkSize = 100;
    for (int i = 0; i < students.length; i += chunkSize) {
      if (!mounted) return;
      final end = (i + chunkSize < students.length)
          ? i + chunkSize
          : students.length;
      for (int j = i; j < end; j++) {
        final student = students[j];
        final rollNo = student['roll_no'].toString();
        final existingStatus = student['attendance']?['status'];
        if (existingStatus != null && existingStatus != 'not_marked') {
          _existingAttendance[rollNo] = {
            'status': existingStatus,
            'timestamp': student['attendance']?['timestamp'],
            'marked_by': student['attendance']?['marked_by'],
          };
        }
        _attendanceStatus[rollNo] = existingStatus ?? 'not_marked';
      }
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (!mounted) return;
    _updateStats();
  }

  // ==================== ATTENDANCE SAVING ====================

  Future<void> _saveAttendanceInBatches() async {
    if (widget.staffId.isEmpty ||
        widget.selectedHours.isEmpty ||
        _students.isEmpty) {
      _showError("Please complete all selections");
      return;
    }

    final markedStudents = _attendanceStatus.entries
        .where((entry) => entry.value != 'not_marked')
        .toList();

    if (markedStudents.isEmpty) {
      _showError("Please mark at least one student's attendance");
      return;
    }

    if (widget.selectedDate.isAfter(DateTime.now())) {
      _showError("Cannot mark attendance for future dates");
      return;
    }

    _safeSetState(() {
      _isSaving = true;
      _saveProgress = 0.1;
      _saveStatus = "Preparing session details...";
    });

    final now = DateTime.now();
    final diff = now.difference(widget.selectedDate).inHours;
    final isDelayed =
        diff > 24 && widget.selectedDate.isBefore(now);

    if (isDelayed) {
      final confirm = await _showDelayedSubmissionDialog(diff);
      if (!confirm) {
        _safeSetState(() => _isSaving = false);
        return;
      }
    }

    _safeSetState(() {
      _saveProgress = 0.2;
      _saveStatus = "Please add teaching details...";
    });

    final sessionDetails = await _showClassSessionDetailsDialog();
    if (!mounted) return;

    if (sessionDetails == null) {
      _safeSetState(() {
        _isSaving = false;
        _saveProgress = 0.0;
      });
      _showWarning("Attendance not saved");
      return;
    }

    _safeSetState(() {
      _saveProgress = 0.4;
      _saveStatus = "Reviewing attendance...";
    });

    final confirm =
        await _showDetailedSaveConfirmationDialog(markedStudents);
    if (!confirm) {
      _safeSetState(() => _isSaving = false);
      return;
    }

    _safeSetState(() {
      _saveProgress = 0.5;
      _saveStatus = "Saving attendance records...";
    });

    try {
      final attendanceSuccess = await _saveAttendanceWithProgress(
          markedStudents, isDelayed, sessionDetails);

      if (!mounted) return;

      if (attendanceSuccess) {
        _safeSetState(() {
          _saveProgress = 0.8;
          _saveStatus = "Saving teaching methodology...";
        });

        await Future.delayed(Duration(milliseconds: 800));

        _safeSetState(() {
          _saveProgress = 1.0;
          _saveStatus = "Complete!";
        });

        await Future.delayed(Duration(milliseconds: 500));
        _safeSetState(() => _isSaving = false);

        _showSuccess("✅ Attendance and session details saved successfully!");

        await Future.delayed(Duration(milliseconds: 1500));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _safeSetState(() {
          _isSaving = false;
          _saveProgress = 0.0;
        });
        _showError("Failed to save attendance. Please try again.");
      }
    } catch (e) {
      _safeSetState(() {
        _isSaving = false;
        _saveProgress = 0.0;
      });
      _showError("Error: ${e.toString()}");
    }
  }

  Future<bool> _saveAttendanceWithProgress(
    List<MapEntry<String, String>> markedStudents,
    bool isDelayed,
    Map<String, dynamic>? sessionDetails,
  ) async {
    try {
      for (int i = 0; i < 5; i++) {
        if (!mounted) return false;
        _safeSetState(() {
          _saveProgress = 0.5 + (i * 0.06);
          _saveStatus = "Saving batch ${i + 1} of 5...";
        });
        await Future.delayed(Duration(milliseconds: 400));
      }

      final attendanceRecords = markedStudents
          .map((entry) => {
                'roll_no': entry.key,
                'status': entry.value,
              })
          .toList();

      // Build kLevel array properly
      List<dynamic> kLevelArray = [];
      final kLevelRaw = sessionDetails?['kLevel'];
      if (kLevelRaw is List) {
        kLevelArray = kLevelRaw;
      } else if (kLevelRaw is String && kLevelRaw.isNotEmpty) {
        kLevelArray = kLevelRaw.contains(',')
            ? kLevelRaw.split(',').map((e) => e.trim()).toList()
            : [kLevelRaw];
      }

      final body = {
        'staff_id': widget.staffId,
        'hours': widget.selectedHours,
        'dayOrder': widget.selectedDayOrder,
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'attendanceType': 'hourly',
        'attendance_record': attendanceRecords,
        'hour_stat': {
          'topicDelivered': sessionDetails?['topic']?.toString().trim() ?? '',
          'klevel': kLevelArray,
          'ict': sessionDetails?['teachingToolsUsed'] ?? false,
          'teachingMethod': sessionDetails?['methodologies'] ?? [],
        }
      };

      final response = await http
          .post(
            Uri.parse("$_kBaseApiUrl/students/attendance/mark-attendance"),
            headers: {
              'Referer': _kRefererUrl,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(Duration(seconds: 35));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint("Error saving attendance: $e");
      return false;
    }
  }

  Future<bool> _saveAttendanceBatch(
    List<MapEntry<String, String>> markedStudents,
    bool isDelayed,
  ) async {
    try {
      final attendanceRecords = markedStudents
          .map((entry) => {
                'roll_no': entry.key,
                'status': entry.value,
              })
          .toList();

      final body = {
        'staff_id': widget.staffId,
        'hours': widget.selectedHours,
        'dayOrder': widget.selectedDayOrder,
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'attendanceType': 'hourly',
        'attendance_record': attendanceRecords,
      };

      final response = await http
          .post(
            Uri.parse("$_kBaseApiUrl/students/attendance/mark-attendance"),
            headers: {
              'Referer': _kRefererUrl,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(Duration(seconds: 35));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ATTENDANCE MARKING HELPERS ====================

  void _markAll(String status) {
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student['roll_no'].toString()] = status;
      }
      _updateStats();
    });
    _showInfo("All students marked as ${_getStatusName(status)}");
  }

  String _getStatusName(String status) {
    final option = _attendanceOptions.firstWhere(
      (opt) => opt['value'] == status,
      orElse: () => _attendanceOptions[3],
    );
    return option['name'];
  }

  void _markAllPresent() => _markAll('present');
  void _markAllAbsent() => _markAll('absent');
  void _markAllLate() => _markAll('late');

  void _clearAll() {
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student['roll_no'].toString()] = 'not_marked';
      }
      _updateStats();
    });
  }

  void _toggleAttendanceStatus(String rollNo) {
    final currentStatus = _attendanceStatus[rollNo] ?? 'not_marked';
    int currentIndex = _attendanceOptions
        .indexWhere((opt) => opt['value'] == currentStatus);
    int nextIndex = (currentIndex + 1) % _attendanceOptions.length;
    setState(() {
      _attendanceStatus[rollNo] = _attendanceOptions[nextIndex]['value'];
      _updateStats();
    });
  }

  // ==================== FILTERING ====================

  List get _filteredStudents {
    return _students.where((student) {
      final rollNo = student['roll_no'].toString().toLowerCase();
      final name = (student['name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final status = _attendanceStatus[rollNo] ?? 'not_marked';

      if (_searchQuery.isNotEmpty &&
          !rollNo.contains(query) &&
          !name.contains(query)) return false;
      if (_filterStatus != 'all' && status != _filterStatus) return false;
      if (_showOnlyPending && status != 'not_marked') return false;

      return true;
    }).toList();
  }

  // ==================== DIALOGS ====================

  Future<bool> _showDelayedSubmissionDialog(int hoursDelayed) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _warningOrange),
                SizedBox(width: 8),
                Text("Delayed Submission"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are trying to mark attendance for a date that is $hoursDelayed hours old.",
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 16, color: _warningOrange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This will be recorded as a delayed attendance submission.",
                          style: TextStyle(
                            fontSize: 12,
                            color: _warningOrange.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text("Cancel", style: TextStyle(color: _textMedium)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _warningOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Continue Anyway"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showDetailedSaveConfirmationDialog(
      List<MapEntry<String, String>> markedStudents) async {
    final presentCount =
        markedStudents.where((e) => e.value == 'present').length;
    final absentCount =
        markedStudents.where((e) => e.value == 'absent').length;
    final lateCount =
        markedStudents.where((e) => e.value == 'late').length;
    final totalMarked = markedStudents.length;

    final absentDetails =
        markedStudents.where((e) => e.value == 'absent').map((entry) {
      final student = _students.firstWhere(
        (s) => s['roll_no'].toString() == entry.key,
        orElse: () => {'name': 'Unknown', 'roll_no': entry.key},
      );
      return {'roll_no': entry.key, 'name': student['name'] ?? 'Unknown'};
    }).toList();

    bool isDialogSaving = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                backgroundColor: _cardWhite,
                insetPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: _primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.task_alt,
                                  color: Colors.white, size: 18),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text("Ready to save?",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  Text("Please review before saving",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withOpacity(0.9))),
                                ],
                              ),
                            ),
                            if (!isDialogSaving)
                              IconButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                icon: Icon(Icons.close,
                                    color: Colors.white, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                      // Stats
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                                child: _buildCompactStatCard('Present',
                                    presentCount, _successGreen, Icons.check_circle)),
                            SizedBox(width: 8),
                            Expanded(
                                child: _buildCompactStatCard('Absent',
                                    absentCount, _dangerRed, Icons.cancel)),
                            SizedBox(width: 8),
                            Expanded(
                                child: _buildCompactStatCard('Late',
                                    lateCount, _warningOrange, Icons.access_time)),
                          ],
                        ),
                      ),
                      // Class info
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.class_,
                                size: 16, color: _textMedium),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${widget.selectedClass['program_id']}",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textDark),
                                  ),
                                  Text(
                                    "Year ${widget.selectedClass['year']} • Sec ${widget.selectedClass['section_name']}",
                                    style: TextStyle(
                                        fontSize: 10, color: _textMedium),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _primaryRoyal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "Hrs: ${widget.selectedHours.join(',')}",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _primaryRoyal,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Absent list
                      if (absentDetails.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: _dangerRed),
                              SizedBox(width: 8),
                              Text("Absent Students",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textDark)),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _dangerRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text("$absentCount",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: _dangerRed,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            shrinkWrap: true,
                            itemCount: absentDetails.length > 5
                                ? 5
                                : absentDetails.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final student = absentDetails[index];
                              return Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _cardWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          _dangerRed.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _dangerRed.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Text('${index + 1}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _dangerRed)),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(student['name'],
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                  color: _textDark),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          Text(student['roll_no'],
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: _textMedium)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _dangerRed.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text('ABSENT',
                                          style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: _dangerRed)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (absentDetails.length > 5)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Text(
                              "+ ${absentDetails.length - 5} more absent students",
                              style: TextStyle(
                                  fontSize: 9,
                                  color: _textMedium,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                      // Total
                      Container(
                        margin: EdgeInsets.all(16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _successGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people,
                                    size: 14, color: _successGreen),
                                SizedBox(width: 6),
                                Text("Total Marked",
                                    style: TextStyle(
                                        fontSize: 11, color: _textDark)),
                              ],
                            ),
                            Text(
                              "$totalMarked/${_students.length}",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _successGreen),
                            ),
                          ],
                        ),
                      ),
                      // Buttons
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isDialogSaving
                                    ? null
                                    : () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textMedium,
                                  side: BorderSide(color: _borderLight),
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: Text("Cancel",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isDialogSaving
                                    ? null
                                    : () async {
                                        setDialogState(() =>
                                            isDialogSaving = true);
                                        await Future.delayed(
                                            Duration(milliseconds: 300));
                                        Navigator.pop(context, true);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _successGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: isDialogSaving
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                      Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text("Saving...",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save, size: 14),
                                          SizedBox(width: 4),
                                          Text("Save Now",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
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
              );
            },
          ),
        ) ??
        false;
  }

  Widget _buildCompactStatCard(
      String label, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(height: 4),
          Text(count.toString(),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style:
                  TextStyle(fontSize: 9, color: _textMedium)),
        ],
      ),
    );
  }

  void _retryFailedStudents(List<String> failedRollNos) {
    final failedEntries = _attendanceStatus.entries
        .where((entry) => failedRollNos.contains(entry.key))
        .toList();

    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
      _saveStatus =
          "Retrying ${failedRollNos.length} failed records...";
    });

    _retryBatch(failedEntries);
  }

  Future<void> _retryBatch(
      List<MapEntry<String, String>> failedEntries) async {
    try {
      if (!mounted) return;
      _safeSetState(() {
        _saveProgress = 0.5;
        _saveStatus = "Retrying ${failedEntries.length} failed records...";
      });

      final now = DateTime.now();
      final diff = now.difference(widget.selectedDate).inHours;
      final isDelayed =
          diff > 24 && widget.selectedDate.isBefore(now);

      final success = await _saveAttendanceBatch(failedEntries, isDelayed);
      if (!mounted) return;

      if (success) {
        for (var entry in failedEntries) {
          _existingAttendance[entry.key] = {
            'status': entry.value,
            'timestamp': DateTime.now().toIso8601String(),
            'marked_by': widget.staffId,
          };
        }
        _safeSetState(() {
          _isSaving = false;
          _saveProgress = 1.0;
          _updateStats();
        });
        _showSuccess(
            "✅ Successfully retried ${failedEntries.length} records!");
      } else {
        _safeSetState(() {
          _isSaving = false;
          _saveProgress = 0.0;
        });
        _showError("Retry failed. Please try again later.");
      }
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() => _isSaving = false);
      _showError("Retry error: $e");
    }
  }

  // ==================== SNACKBARS ====================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(message, style: TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _successGreen,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: 3),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _dangerRed,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _warningOrange,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _primaryRoyal,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildClassInfoBar(),
            if (_isSaving) _buildSavingProgressIndicator(),
            if (_students.isNotEmpty && !_isLoading)
              _buildFixedSearchAndFilterBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetchStudents,
                          color: _primaryRoyal,
                          backgroundColor: _cardWhite,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                if (_students.isNotEmpty) ...[
                                  _buildAttendanceStatsCard(),
                                  _buildAttendanceSection(),
                                  _buildRemarksSection(),
                                ] else if (!_isLoading &&
                                    _errorMessage.isEmpty)
                                  _buildEmptyState(),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          _students.isNotEmpty && _showFloatingSaveButton && !_isSaving
              ? _buildFloatingSaveButton()
              : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A8A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Mark Attendance',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: _fetchStudents,
        ),
      ],
    );
  }

  Widget _buildClassInfoBar() {
    final program =
        widget.selectedClass['program_id']?.toString() ?? '';
    final year = widget.selectedClass['year']?.toString() ?? '';
    final section =
        widget.selectedClass['section_name']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _cardWhite,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryRoyal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.class_, size: 18, color: _primaryRoyal),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark)),
                Text(
                  "Year $year • Sec $section • Day ${widget.selectedDayOrder} • Hours: ${widget.selectedHours.join(', ')}",
                  style: TextStyle(fontSize: 11, color: _textMedium),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              DateFormat('dd MMM yyyy').format(widget.selectedDate),
              style: TextStyle(
                  fontSize: 11,
                  color: _successGreen,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingProgressIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isRetrying ? Icons.refresh : Icons.cloud_upload,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRetrying
                          ? "Retrying..."
                          : "Saving Attendance",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark),
                    ),
                    SizedBox(height: 4),
                    Text(_saveStatus,
                        style:
                            TextStyle(fontSize: 12, color: _textMedium)),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryRoyal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(_saveProgress * 100).toInt()}%",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryRoyal),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _saveProgress,
              minHeight: 8,
              backgroundColor: _borderLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_primaryRoyal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Attendance Summary",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark)),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryRoyal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("${_students.length} Total",
                    style: TextStyle(
                        fontSize: 11,
                        color: _primaryRoyal,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatItem(
                      'Present', _presentCount, _successGreen, Icons.check_circle)),
              Expanded(
                  child: _buildStatItem(
                      'Absent', _absentCount, _dangerRed, Icons.cancel)),
              Expanded(
                  child: _buildStatItem(
                      'Late', _lateCount, _warningOrange, Icons.access_time)),
              Expanded(
                  child: _buildStatItem(
                      'Pending', _pendingCount, _textLight, Icons.help)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(height: 6),
        Text(count.toString(),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 10, color: _textMedium)),
      ],
    );
  }

  Widget _buildFixedSearchAndFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _cardWhite,
      child: Column(
        children: [
          // Search field
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: _textLight),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Search by name or roll no...",
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    onPressed: () =>
                        setState(() => _searchQuery = ""),
                    icon:
                        Icon(Icons.close, size: 16, color: _textMedium),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Quick-mark buttons
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _buildFixedActionButton(
                    "Present", Icons.check_circle, _successGreen, _markAllPresent),
                SizedBox(width: 8),
                _buildFixedActionButton(
                    "Absent", Icons.cancel, _dangerRed, _markAllAbsent),
                SizedBox(width: 8),
                _buildFixedActionButton(
                    "Late", Icons.access_time, _warningOrange, _markAllLate),
                SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  height: 40,
                  child: IconButton(
                    onPressed: _clearAll,
                    icon: Icon(Icons.clear_all,
                        size: 18, color: _textMedium),
                    style: IconButton.styleFrom(
                      backgroundColor: _cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: _borderLight),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFixedFilterChip("All", "all", _students.length),
                SizedBox(width: 8),
                _buildFixedFilterChip(
                    "Present", "present", _presentCount),
                SizedBox(width: 8),
                _buildFixedFilterChip("Absent", "absent", _absentCount),
                SizedBox(width: 8),
                _buildFixedFilterChip("Late", "late", _lateCount),
                SizedBox(width: 8),
                _buildFixedFilterChip(
                    "Pending", "pending", _pendingCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedFilterChip(
      String label, String value, int count) {
    final isSelected = (value == "pending" && _showOnlyPending) ||
        (value != "pending" && _filterStatus == value);

    return FilterChip(
      label: Text("$label $count"),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (value == "pending") {
            _showOnlyPending = selected;
            if (selected) _filterStatus = "all";
          } else {
            _filterStatus = selected ? value : "all";
            _showOnlyPending = false;
          }
        });
      },
      backgroundColor: _cardWhite,
      selectedColor: value == "present"
          ? _successGreen.withOpacity(0.2)
          : value == "absent"
              ? _dangerRed.withOpacity(0.2)
              : value == "late"
                  ? _warningOrange.withOpacity(0.2)
                  : _primaryRoyal.withOpacity(0.2),
      checkmarkColor: _primaryRoyal,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? _textDark : _textMedium,
        fontWeight:
            isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildAttendanceSection() {
    final filteredStudents = _filteredStudents;

    return Column(
      children: [
        if (_showFloatingSummary && _students.isNotEmpty)
          _buildFloatingSummaryBar(),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text("Student List",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark)),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryRoyal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Hours: ${widget.selectedHours.join(', ')}",
                        style: TextStyle(
                            fontSize: 11,
                            color: _primaryRoyal,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredStudents.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 40, color: _textLight),
                      SizedBox(height: 12),
                      Text("No students found",
                          style: TextStyle(
                              fontSize: 14, color: _textMedium)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: filteredStudents.length,
                  padding: EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final rollNo = student['roll_no'].toString();
                    final name = student['name'] ?? 'Unknown';
                    final status =
                        _attendanceStatus[rollNo] ?? 'not_marked';
                    final hasExisting =
                        _existingAttendance.containsKey(rollNo);

                    return _buildStudentCard(
                      index: _students.indexOf(student) + 1,
                      rollNo: rollNo,
                      name: name,
                      status: status,
                      hasExisting: hasExisting,
                    );
                  },
                ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: _borderLight))),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Showing ${filteredStudents.length} of ${_students.length}",
                      style:
                          TextStyle(fontSize: 11, color: _textMedium),
                    ),
                    if (filteredStudents.length < _students.length)
                      TextButton(
                        onPressed: () => setState(() {
                          _searchQuery = "";
                          _filterStatus = "all";
                          _showOnlyPending = false;
                        }),
                        style: TextButton.styleFrom(
                          minimumSize: Size(0, 0),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: Text("Clear Filters",
                            style: TextStyle(
                                fontSize: 11, color: _primaryRoyal)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingSummaryBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFloatingStatItem('P', _presentCount, _successGreen, Icons.check_circle),
          Container(width: 1, height: 20, color: _borderLight),
          _buildFloatingStatItem('A', _absentCount, _dangerRed, Icons.cancel),
          Container(width: 1, height: 20, color: _borderLight),
          _buildFloatingStatItem('L', _lateCount, _warningOrange, Icons.access_time),
          Container(width: 1, height: 20, color: _borderLight),
          _buildFloatingStatItem('?', _pendingCount, _textLight, Icons.help),
        ],
      ),
    );
  }

  Widget _buildFloatingStatItem(
      String label, int count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 4),
        Text('$count',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  Widget _buildStudentCard({
    required int index,
    required String rollNo,
    required String name,
    required String status,
    required bool hasExisting,
  }) {
    final statusInfo = _attendanceOptions.firstWhere(
      (opt) => opt['value'] == status,
      orElse: () => _attendanceOptions[3],
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasExisting
              ? _primaryRoyal.withOpacity(0.3)
              : status == 'not_marked'
                  ? _borderLight
                  : (statusInfo['color'] as Color).withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleAttendanceStatus(rollNo),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (statusInfo['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$index',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusInfo['color'])),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (hasExisting)
                            Container(
                              margin: EdgeInsets.only(left: 4),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _primaryRoyal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("saved",
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: _primaryRoyal,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(rollNo,
                          style: TextStyle(
                              fontSize: 11, color: _textMedium)),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (statusInfo['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusInfo['color'], width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusInfo['icon'],
                          size: 14, color: statusInfo['color']),
                      SizedBox(width: 4),
                      Text(statusInfo['label'],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusInfo['color'])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemarksSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, size: 18, color: _textMedium),
              SizedBox(width: 8),
              Text("Remarks (Optional)",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textDark)),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _remarksController,
            onChanged: (v) => setState(() => _remarks = v),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Add any remarks...",
              hintStyle: TextStyle(color: _textLight),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _primaryRoyal),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSaveButton() {
    final markedCount = _presentCount + _absentCount + _lateCount;
    final hasMarked = markedCount > 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      child: Material(
        elevation: 8,
        shadowColor: _primaryRoyal.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _saveAttendanceInBatches,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasMarked && !_isSaving
                    ? [_successGreen, _successGreen.withOpacity(0.8)]
                    : _isSaving
                        ? _primaryGradient
                        : [_textLight, _textLight.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isSaving ? Icons.hourglass_top : Icons.save,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      _isSaving ? "Saving..." : "Save Attendance",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (!_isSaving && hasMarked)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "$markedCount/${_students.length}",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else if (_isSaving)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "${(_saveProgress * 100).toInt()}%",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: _textLight),
          SizedBox(height: 16),
          Text("No students found",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textDark)),
          SizedBox(height: 8),
          Text("Tap refresh to try again",
              style: TextStyle(fontSize: 13, color: _textMedium)),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchStudents,
            icon: Icon(Icons.refresh, size: 18),
            label: Text("Refresh"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRoyal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _primaryRoyal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryRoyal),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text("Loading students...",
              style: TextStyle(fontSize: 13, color: _textMedium)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _dangerRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.error_outline, size: 48, color: _dangerRed),
            ),
            SizedBox(height: 16),
            Text("Unable to Load Students",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
            SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _textMedium)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchStudents,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRoyal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child:
                  Text("Try Again", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SESSION DETAILS DIALOG ====================

  Future<Map<String, dynamic>?> _showClassSessionDetailsDialog() async {
    List<String> selectedKLevels = [];
    bool? teachingToolsUsed;
    List<String> selectedMethodologies = [];
    final topicController = TextEditingController();

    final kLevels = ['K1', 'K2', 'K3', 'K4', 'K5', 'K6'];
    final methodologies = [
      'Participative Learning',
      'Experiential Learning',
      'Problem Solving',
      'Peer Teaching',
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: _cardWhite,
            insetPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.menu_book,
                              color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Session Details",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Add topic and teaching methodology details",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic
                          Text(
                            "Topic Delivered *",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 6),
                          TextField(
                            controller: topicController,
                            maxLines: 2,
                            style: TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  "Enter the topic you delivered...",
                              hintStyle: TextStyle(
                                  fontSize: 12, color: _textLight),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: _borderLight, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: _primaryRoyal, width: 1.5),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          SizedBox(height: 20),

                          // K Level (Multi-select)
                          Text(
                            "K Level *",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Select one or more K levels",
                            style: TextStyle(
                                fontSize: 11, color: _textLight),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: kLevels.map((level) {
                              final isSelected =
                                  selectedKLevels.contains(level);
                              return GestureDetector(
                                onTap: () => setDialogState(() {
                                  if (isSelected) {
                                    selectedKLevels.remove(level);
                                  } else {
                                    selectedKLevels.add(level);
                                  }
                                }),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: _primaryGradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : _cardWhite,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? _primaryRoyal
                                          : _borderLight,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    level,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : _textMedium,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),

                          // ICT / Teaching Tools
                          Text(
                            "Teaching Tools / ICT / E-Resources *",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactYesNoOption(
                                  label: "Yes",
                                  isSelected: teachingToolsUsed == true,
                                  onTap: () => setDialogState(
                                      () => teachingToolsUsed = true),
                                  color: _successGreen,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactYesNoOption(
                                  label: "No",
                                  isSelected:
                                      teachingToolsUsed == false,
                                  onTap: () => setDialogState(
                                      () => teachingToolsUsed = false),
                                  color: _dangerRed,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Teaching Methodology (Multi-select)
                          Text(
                            "Teaching Methodology *",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Select one or more methodologies",
                            style: TextStyle(
                                fontSize: 11, color: _textLight),
                          ),
                          SizedBox(height: 8),
                          ...methodologies.map((method) {
                            final isSelected =
                                selectedMethodologies.contains(method);
                            return GestureDetector(
                              onTap: () => setDialogState(() {
                                if (isSelected) {
                                  selectedMethodologies.remove(method);
                                } else {
                                  selectedMethodologies.add(method);
                                }
                              }),
                              child: Container(
                                margin: EdgeInsets.only(bottom: 6),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _primaryRoyal.withOpacity(0.05)
                                      : _cardWhite,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primaryRoyal
                                        : _borderLight,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _primaryRoyal
                                            : _cardWhite,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected
                                              ? _primaryRoyal
                                              : _borderLight,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(Icons.check,
                                              size: 12,
                                              color: Colors.white)
                                          : null,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        method,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? _primaryRoyal
                                              : _textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          SizedBox(height: 16),

                          // Info message
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _warningOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      _warningOrange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: _warningOrange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Please verify all information before submitting",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _warningOrange,
                                      fontWeight: FontWeight.w500,
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
                  // Footer buttons
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: _borderLight, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textMedium,
                              side: BorderSide(color: _borderLight),
                              padding:
                                  EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (topicController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Please enter the topic delivered"),
                                  backgroundColor: _dangerRed,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ));
                                return;
                              }
                              if (selectedKLevels.isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Please select at least one K level"),
                                  backgroundColor: _dangerRed,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ));
                                return;
                              }
                              if (teachingToolsUsed == null) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Please indicate if teaching tools were used"),
                                  backgroundColor: _dangerRed,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ));
                                return;
                              }
                              if (selectedMethodologies.isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Please select at least one teaching methodology"),
                                  backgroundColor: _dangerRed,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ));
                                return;
                              }
                              Navigator.pop(dialogContext, {
                                'topic': topicController.text,
                                'kLevel': selectedKLevels,
                                'teachingToolsUsed': teachingToolsUsed,
                                'methodologies': selectedMethodologies,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryRoyal,
                              foregroundColor: Colors.white,
                              padding:
                                  EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Submit",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      topicController.dispose();
    });

    return result;
  }

  Widget _buildCompactYesNoOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : _cardWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : _borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : _cardWhite,
                border: Border.all(
                  color: isSelected ? color : _borderLight,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child:
                          Icon(Icons.check, size: 10, color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : _textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}