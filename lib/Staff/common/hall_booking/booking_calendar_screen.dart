// booking_calendar_screen.dart — Redesigned to match Staff ERP design system

import 'dart:convert';
import 'package:bhc_erp/Staff/common/hall_booking/bookings_list_screen.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen>
    with TickerProviderStateMixin {
  // ── API ──────────────────────────────────────────────────
  final String _base = "https://apierp.bhc.edu.in/api";
  final String _ref = "http://117.232.64.75";

  // ── STATE ────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime.now();
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  String _view = 'Day'; // Day | Week | Month

  // ── Animations ───────────────────────────────────────────
  late AnimationController _appBarGlow;
  late AnimationController _pageEnterCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  final ScrollController _scrollController = ScrollController();

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetch();

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
      5,
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
    _scrollController.dispose();
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

  // ── API ──────────────────────────────────────────────────
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse("$_base/office/hall/booking/"),
        headers: {'Referer': _ref, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (d['success'] == true) {
          _all = d['data'] ?? [];
        } else {
          _error = d['message'] ?? 'No data returned.';
        }
      } else {
        _error = 'Server error: ${res.statusCode}';
      }
    } catch (_) {
      _error = 'Could not connect. Check your internet.';
    }

    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    switch (_view) {
      case 'Day':
        final ds = _fmt(_selectedDate, 'yyyy-MM-dd');
        _filtered = _all.where((b) {
          final d = _pd(b['from']);
          return d != null && _fmt(d, 'yyyy-MM-dd') == ds;
        }).toList();
        break;
      case 'Week':
        final start = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        _filtered = _all.where((b) {
          final d = _pd(b['from']);
          return d != null &&
              !d.isBefore(DateTime(start.year, start.month, start.day)) &&
              !d.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
        }).toList();
        break;
      case 'Month':
        _filtered = _all.where((b) {
          final d = _pd(b['from']);
          return d != null &&
              d.year == _selectedDate.year &&
              d.month == _selectedDate.month;
        }).toList();
        break;
    }
    _filtered.sort((a, b) {
      final da = _pd(a['from']);
      final db = _pd(b['from']);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
  }

  void _changeView(String v) {
    setState(() => _view = v);
    _applyFilter();
  }

  void _prevPeriod() {
    setState(() {
      switch (_view) {
        case 'Day':
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case 'Week':
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case 'Month':
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
          _calendarMonth = _selectedDate;
          break;
      }
      _applyFilter();
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_view) {
        case 'Day':
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case 'Week':
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case 'Month':
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          _calendarMonth = _selectedDate;
          break;
      }
      _applyFilter();
    });
  }

  Future<void> _pickDate() async {
    final theme = context.read<StaffThemeProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: theme.cyan,
            onPrimary: Colors.white,
            surface: theme.surface,
            onSurface: theme.textHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _calendarMonth = picked;
        _applyFilter();
      });
    }
  }

  // ── HELPERS ──────────────────────────────────────────────
  DateTime? _pd(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime d, String pattern) => DateFormat(pattern).format(d);
  String _fmtTime(dynamic v) {
    final d = _pd(v);
    return d == null ? '--:--' : _fmt(d, 'hh:mm a');
  }

  String _periodLabel() {
    switch (_view) {
      case 'Day':
        final isToday = _fmt(_selectedDate, 'yyyy-MM-dd') ==
            _fmt(DateTime.now(), 'yyyy-MM-dd');
        return isToday ? 'Today' : _fmt(_selectedDate, 'EEE, dd MMM yyyy');
      case 'Week':
        final start = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${_fmt(start, 'dd MMM')} – ${_fmt(end, 'dd MMM yyyy')}';
      case 'Month':
        return _fmt(_selectedDate, 'MMMM yyyy');
    }
    return '';
  }

  Color _typeColor(StaffThemeProvider theme, String type) =>
      type == 'Hall' ? theme.cyan : theme.green;

  IconData _typeIcon(String type) =>
      type == 'Hall' ? Icons.meeting_room_rounded : Icons.bed_rounded;

  Color _statusColor(StaffThemeProvider theme, String s) {
    switch (s.toLowerCase()) {
      case 'approved': return theme.green;
      case 'pending': return theme.amber;
      case 'rejected':
      case 'cancelled': return theme.error;
      case 'completed': return theme.violet;
      default: return theme.textLow;
    }
  }

  bool _dayHasBooking(DateTime day) {
    final ds = _fmt(day, 'yyyy-MM-dd');
    return _all.any((b) {
      final d = _pd(b['from']);
      return d != null && _fmt(d, 'yyyy-MM-dd') == ds;
    });
  }

  // ─── FUTURISTIC APP BAR ───────────────────────────────────
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
                          "Booking Calendar",
                          style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "View hall & room bookings",
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
                          "${_filtered.length}",
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
                    onPressed: _fetch,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── VIEW TOGGLE ─────────────────────────────────────────
  Widget _buildViewToggle(StaffThemeProvider theme) {
    final views = ['Day', 'Week', 'Month'];
    return _animated(
      0,
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        height: 44,
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: views.map((v) {
            final active = _view == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => _changeView(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(colors: [theme.cyan, theme.violet])
                        : null,
                    color: active ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      v,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : theme.textMid,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── DATE NAVIGATOR ──────────────────────────────────────
  Widget _buildDateNavigator(StaffThemeProvider theme) {
    return _animated(
      1,
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            _navButton(theme, Icons.chevron_left_rounded, _prevPeriod),
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cyan.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: theme.cyan),
                      const SizedBox(width: 8),
                      Text(
                        _periodLabel(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _navButton(theme, Icons.chevron_right_rounded, _nextPeriod),
          ],
        ),
      ),
    );
  }

  Widget _navButton(StaffThemeProvider theme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Icon(icon, color: theme.cyan, size: 20),
      ),
    );
  }

  // ─── WEEK STRIP (Day view only) ──────────────────────────
  Widget _buildWeekStrip(StaffThemeProvider theme) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final base = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1));
      return base.add(Duration(days: i));
    });

    return _animated(
      2,
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: days.map((d) {
            final isSelected = _fmt(d, 'yyyy-MM-dd') ==
                _fmt(_selectedDate, 'yyyy-MM-dd');
            final isToday = _fmt(d, 'yyyy-MM-dd') ==
                _fmt(today, 'yyyy-MM-dd');
            final hasBooking = _dayHasBooking(d);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = d;
                    _applyFilter();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [theme.cyan, theme.violet])
                        : null,
                    color: isSelected
                        ? null
                        : isToday
                            ? theme.cyan.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isToday ? theme.cyan.withOpacity(0.3) : Colors.transparent,
                          ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _fmt(d, 'E')[0],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : theme.textLow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(d, 'd'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : isToday ? theme.cyan : theme.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasBooking
                              ? (isSelected ? Colors.white : theme.amber)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── STATS ROW ───────────────────────────────────────────
 // ─── STATS ROW ───────────────────────────────────────────
Widget _buildStatsRow(StaffThemeProvider theme) {
  final hallCount = _filtered
      .where((b) => (b['bookingType'] ?? '') == 'Hall')
      .length;
  final roomCount = _filtered
      .where((b) => (b['bookingType'] ?? '') != 'Hall')
      .length;
  final pendingCount = _filtered
      .where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending')
      .length;

  return _animated(
    3,
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(  // ← Wrap with SingleChildScrollView
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statPill(theme, '${_filtered.length} Total', theme.textMid, Icons.event_rounded),
            const SizedBox(width: 8),
            _statPill(theme, '$hallCount Hall', theme.cyan, Icons.meeting_room_rounded),
            const SizedBox(width: 8),
            _statPill(theme, '$roomCount Room', theme.green, Icons.bed_rounded),
            const SizedBox(width: 8),
            _statPill(theme, '$pendingCount Pending', theme.amber, Icons.schedule_rounded),
          ],
        ),
      ),
    ),
  );
}


  Widget _statPill(StaffThemeProvider theme, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BODY ─────────────────────────────────────────────────
  Widget _buildBody(StaffThemeProvider theme) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.cyan),
              ),
            ),
            const SizedBox(height: 16),
            Text('Loading calendar...', style: TextStyle(fontSize: 14, color: theme.textMid)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, size: 48, color: theme.error),
              ),
              const SizedBox(height: 20),
              Text(
                'Connection Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.textHigh),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: theme.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _fetch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_view == 'Month') {
      return _buildMonthGrid(theme);
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded, size: 56, color: theme.textLow),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookings for this $_view',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textMid),
            ),
            const SizedBox(height: 6),
            Text('Try a different date', style: TextStyle(fontSize: 13, color: theme.textLow)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: theme.cyan,
      backgroundColor: theme.surface,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _view == 'Week' ? _buildWeekItems(theme).length : _filtered.length,
        itemBuilder: (_, i) {
          if (_view == 'Week') {
            return _buildWeekItems(theme)[i];
          }
          return _buildBookingCard(theme, _filtered[i]);
        },
      ),
    );
  }

  // ─── WEEK ITEMS (grouped by day) ─────────────────────────
  List<Widget> _buildWeekItems(StaffThemeProvider theme) {
    final grouped = <String, List<dynamic>>{};
    for (final b in _filtered) {
      final d = _pd(b['from']);
      if (d == null) continue;
      final key = _fmt(d, 'yyyy-MM-dd');
      grouped.putIfAbsent(key, () => []).add(b);
    }

    final sorted = grouped.keys.toList()..sort();
    final widgets = <Widget>[];

    for (final key in sorted) {
      final date = DateTime.parse(key);
      final isToday = key == _fmt(DateTime.now(), 'yyyy-MM-dd');
      widgets.add(_dayGroupHeader(theme, date, isToday, grouped[key]!.length));
      for (final b in grouped[key]!) {
        widgets.add(_buildBookingCard(theme, b));
      }
      widgets.add(const SizedBox(height: 8));
    }

    if (widgets.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: Column(children: [
              Icon(Icons.event_busy_rounded, size: 56, color: theme.textLow),
              const SizedBox(height: 12),
              Text('No bookings this week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textMid)),
            ]),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _dayGroupHeader(StaffThemeProvider theme, DateTime date, bool isToday, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isToday ? theme.cyan.withOpacity(0.08) : theme.elevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? theme.cyan.withOpacity(0.3) : theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isToday ? LinearGradient(colors: [theme.cyan, theme.violet]) : null,
              color: isToday ? null : theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isToday ? Colors.transparent : theme.border),
            ),
            child: Center(
              child: Text(
                _fmt(date, 'd'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white : theme.textHigh,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmt(date, 'EEEE'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isToday ? theme.cyan : theme.textHigh,
                ),
              ),
              Text(
                _fmt(date, 'dd MMM yyyy'),
                style: TextStyle(fontSize: 11, color: theme.textLow),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count booking${count != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.cyan),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MONTH GRID ──────────────────────────────────────────
  Widget _buildMonthGrid(StaffThemeProvider theme) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();

    return Column(
      children: [
        // Weekday headers
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textLow)),
                ),
              );
            }).toList(),
          ),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + lastDay.day,
            itemBuilder: (_, i) {
              if (i < startOffset) return const SizedBox();
              final day = DateTime(
                  _selectedDate.year, _selectedDate.month, i - startOffset + 1);
              final isSelected = _fmt(day, 'yyyy-MM-dd') == _fmt(_selectedDate, 'yyyy-MM-dd');
              final isToday = _fmt(day, 'yyyy-MM-dd') == _fmt(today, 'yyyy-MM-dd');
              final hasBooking = _dayHasBooking(day);
              final dayBookings = _all.where((b) {
                final d = _pd(b['from']);
                return d != null && _fmt(d, 'yyyy-MM-dd') == _fmt(day, 'yyyy-MM-dd');
              }).length;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                    _view = 'Day';
                    _applyFilter();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [theme.cyan, theme.violet])
                        : null,
                    color: isSelected
                        ? null
                        : isToday
                            ? theme.cyan.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isToday ? theme.cyan.withOpacity(0.3) : Colors.transparent,
                          ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? theme.cyan
                                  : theme.textHigh,
                        ),
                      ),
                      if (hasBooking) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            dayBookings.clamp(1, 3),
                            (_) => Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white.withOpacity(0.8) : theme.amber,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const Divider(height: 24),

        // Month bookings list
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No bookings in ${_fmt(_selectedDate, 'MMMM')}',
                    style: TextStyle(fontSize: 13, color: theme.textLow),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _buildBookingCard(theme, _filtered[i]),
                ),
        ),
      ],
    );
  }

  // ─── BOOKING CARD ────────────────────────────────────────
  Widget _buildBookingCard(StaffThemeProvider theme, dynamic b) {
    final type = (b['bookingType'] ?? 'Hall').toString();
    final status = (b['status'] ?? 'pending').toString();
    final tc = _typeColor(theme, type);
    final sc = _statusColor(theme, status);
    final from = _pd(b['from']);
    final isToday = from != null &&
        _fmt(from, 'yyyy-MM-dd') == _fmt(DateTime.now(), 'yyyy-MM-dd');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? tc.withOpacity(0.3) : theme.border),
        boxShadow: [
          BoxShadow(color: tc.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailsScreen(booking: b),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tc, tc.withOpacity(0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: tc.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(_typeIcon(type), size: 11, color: tc),
                                const SizedBox(width: 4),
                                Text(type,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tc)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sc.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: sc.withOpacity(0.3)),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b['eventName'] ?? 'Untitled Event',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.textHigh),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (b['departmentName'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          b['departmentName'],
                          style: TextStyle(fontSize: 11, color: theme.textMid),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.elevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: tc),
                            const SizedBox(width: 6),
                            Text(_fmtTime(b['from']),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textHigh)),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 11, color: theme.textLow),
                            const SizedBox(width: 6),
                            Text(_fmtTime(b['to']),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textHigh)),
                            if (_view == 'Month' && from != null) ...[
                              const Spacer(),
                              Text(_fmt(from, 'dd MMM'),
                                  style: TextStyle(fontSize: 11, color: theme.textLow)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 12, color: theme.textLow),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              b['incharge'] ?? 'N/A',
                              style: TextStyle(fontSize: 11, color: theme.textMid),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b['participants'] != null) ...[
                            Icon(Icons.people_rounded, size: 12, color: theme.textLow),
                            const SizedBox(width: 4),
                            Text('${b['participants']}',
                                style: TextStyle(fontSize: 11, color: theme.textMid)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MAIN BUILD ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<StaffThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(
        isHod: _isHod,
        currentRoute: '/booking-calendar',
      ),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Column(
            children: [
              _buildViewToggle(theme),
              _buildDateNavigator(theme),
              if (_view == 'Day') _buildWeekStrip(theme),
              _buildStatsRow(theme),
              const Divider(height: 1),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }
}