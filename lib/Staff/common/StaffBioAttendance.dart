import 'dart:convert';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import '../theme_provider.dart';

class StaffBioAttendanceScreen extends StatefulWidget {
  const StaffBioAttendanceScreen({super.key});

  @override
  State<StaffBioAttendanceScreen> createState() =>
      _StaffBioAttendanceScreenState();
}

class _StaffBioAttendanceScreenState extends State<StaffBioAttendanceScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _today;
  bool _loading = true;
  String? _error;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String _search = '';
  int _activePreset = 30;
  int? _bioId;
  String? _staffId;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _appBarGlow;
  late AnimationController _heroCtrl;
  late AnimationController _listCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _listFade;

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _stagger = List.generate(
        5,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.12, 1.0, curve: Curves.easeOutCubic),
            ));
    _heroFade =
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide =
        Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _heroCtrl, curve: Curves.easeOutCubic));
    _listFade =
        CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() {
      setState(() {
        _search = _searchCtrl.text.toLowerCase();
        _applyFilter();
      });
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _heroCtrl.dispose();
    _listCtrl.dispose();
    _staggerCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
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

  // ── API ───────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      _staffId = auth.userData?['staff_id']?.toString();
      if (_staffId == null) throw Exception('Staff ID not available');
      final res = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/staff/$_staffId'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        _profile = json.decode(res.body);
        _bioId = _profile?['bio_id'];
        if (_bioId == null) throw Exception('Bio ID not found');
        await _loadAttendance();
      } else {
        throw Exception('Profile load failed: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAttendance() async {
    if (_bioId == null) return;
    setState(() => _loading = true);
    try {
      final f = DateFormat('yyyy-MM-dd').format(_from);
      final t = DateFormat('yyyy-MM-dd').format(_to);
      final url =
          'https://apierp.bhc.edu.in/api/staff/attendance/$_bioId?fromDate=$f&toDate=$t';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Referer': 'http://117.232.64.75'
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<dynamic> raw = [];
        if (data['attendance'] is List)
          raw = data['attendance'];
        else if (data['records'] is List)
          raw = data['records'];
        else if (data['data'] is List)
          raw = data['data'];
        else if (data is List)
          raw = data;
        else {
          for (var v in data.values) {
            if (v is List) { raw = v; break; }
          }
        }
        _records = raw
            .map((r) => _process(Map<String, dynamic>.from(r)))
            .toList()
          ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _today = _records.firstWhere((r) => r['date'] == todayStr,
            orElse: () => <String, dynamic>{});
        if (_today!.isEmpty) _today = null;
        _computeStats();
        _applyFilter();
        if (mounted) {
          setState(() => _loading = false);
          _heroCtrl.forward(from: 0);
          _listCtrl.forward(from: 0);
          _staggerCtrl.forward(from: 0);
        }
      } else if (res.statusCode == 404) {
        _records = [];
        _computeStats();
        _applyFilter();
        if (mounted) {
          setState(() => _loading = false);
          _heroCtrl.forward(from: 0);
          _listCtrl.forward(from: 0);
          _staggerCtrl.forward(from: 0);
        }
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _process(Map<String, dynamic> r) {
    final firstIn = r['first_in'] ?? r['check_in'] ?? r['in_time'];
    final lastOut = r['last_out'] ?? r['check_out'] ?? r['out_time'];
    final firstInStatus = r['first_in_status'] ?? r['status'];
    final firstInLate = r['first_in_late'] ?? r['late_status'];
    final firstInPlace = r['first_in_place'] ?? r['location'] ?? '';
    final lastOutPlace = r['last_out_place'] ?? r['check_out_place'] ?? '';
    final dateStr = r['date'] ?? r['attendance_date'] ?? '';

    final hasIn = firstIn != null &&
        firstIn.toString().trim().isNotEmpty &&
        firstIn.toString() != 'null';
    final inStatus = firstInStatus?.toString().toLowerCase() ?? '';
    final lastOutRaw = lastOut?.toString().trim() ?? '';
    final hasOut = lastOutRaw.isNotEmpty &&
        lastOutRaw != 'null' &&
        lastOutRaw != firstIn?.toString().trim();

    if (!hasIn || inStatus != 'cin') {
      return {
        ...r,
        'date': dateStr,
        'status': 'Absent',
        'statusKey': 'absent',
        'hasOut': false,
        'inDisplay': '--:--',
        'outDisplay': '--:--',
        'inPlace': '',
        'outPlace': '',
        'first_in': null,
        'last_out': null,
      };
    }
    final late =
        firstInLate?.toString().toLowerCase().contains('late') ?? false;
    return {
      ...r,
      'date': dateStr,
      'status': late ? 'Late' : 'On Time',
      'statusKey': late ? 'late' : 'ontime',
      'hasOut': hasOut,
      'inDisplay': _fmtTime(firstIn),
      'outDisplay': hasOut ? _fmtTime(lastOut) : '--:--',
      'inPlace': firstInPlace.toString(),
      'outPlace': hasOut ? lastOutPlace.toString() : '',
      'first_in': firstIn,
      'last_out': hasOut ? lastOut : null,
      'first_in_late': firstInLate,
    };
  }

  void _computeStats() {
    int onTime = 0, late = 0, absent = 0;
    for (final r in _records) {
      final s = r['statusKey'];
      if (s == 'ontime') onTime++;
      else if (s == 'late') late++;
      else absent++;
    }
    final total = _records.length;
    _stats = {
      'total': total,
      'onTime': onTime,
      'late': late,
      'absent': absent,
      'pct': total == 0 ? 0.0 : (onTime + late) / total * 100,
    };
  }

  void _applyFilter() {
    _filtered = _records.where((r) {
      if (_search.isEmpty) return true;
      final d = (r['date'] ?? '').toLowerCase();
      final day = _getDayName(r['date']).toLowerCase();
      final s = (r['status'] ?? '').toLowerCase();
      final p = (r['inPlace'] ?? '').toLowerCase();
      return d.contains(_search) ||
          day.contains(_search) ||
          s.contains(_search) ||
          p.contains(_search);
    }).toList();
  }

  void _setPreset(int days) {
    setState(() {
      _activePreset = days;
      _to = DateTime.now();
      _from = DateTime.now().subtract(Duration(days: days - 1));
    });
    _loadAttendance();
  }

  Future<void> _pickDate(bool isFrom) async {
    final theme = context.read<StaffThemeProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: isFrom ? _to : DateTime.now(),
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
    if (picked == null) return;
    setState(() {
      if (isFrom) _from = picked;
      else _to = picked;
      _activePreset = -1;
    });
    _loadAttendance();
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _fmtTime(dynamic v) {
    if (v == null || v.toString().trim().isEmpty || v == 'null')
      return '--:--';
    try {
      String t = v.toString().trim();
      if (t.contains(' ')) t = t.split(' ').last;
      final parts = t.split(':');
      if (parts.length < 2) return '--:--';
      final h = int.parse(parts[0]);
      final m = parts[1].substring(0, 2);
      final period = h >= 12 ? 'PM' : 'AM';
      final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$dh:${m.padLeft(2, '0')} $period';
    } catch (_) {
      return '--:--';
    }
  }

  String _getDayName(String? d) {
    if (d == null || d.isEmpty) return '';
    try { return DateFormat('EEEE').format(DateTime.parse(d)); }
    catch (_) { return ''; }
  }

  double _hoursWorked(dynamic inT, dynamic outT) {
    if (inT == null || outT == null) return 0;
    try {
      DateTime? parse(dynamic v) {
        String t = v.toString().trim();
        if (t.contains(' ')) t = t.split(' ').last;
        final p = t.split(':');
        if (p.length < 2) return null;
        return DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
      }
      final a = parse(inT), b = parse(outT);
      if (a == null || b == null) return 0;
      final diff = b.difference(a);
      return diff.isNegative
          ? diff.inMinutes / 60 + 24
          : diff.inMinutes / 60;
    } catch (_) { return 0; }
  }

  Color _statusColor(StaffThemeProvider theme, String? key) {
    switch (key) {
      case 'ontime': return theme.green;
      case 'late':   return theme.amber;
      default:       return theme.pink;
    }
  }

  String _initials(String? n) {
    if (n == null || n.isEmpty) return '?';
    final p = n.trim().split(' ');
    return p.length > 1
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : n[0].toUpperCase();
  }

  String _pctLabel(double p) {
    if (p >= 95) return 'Excellent ✦';
    if (p >= 90) return 'Great Work';
    if (p >= 80) return 'Good';
    if (p >= 75) return 'Satisfactory';
    if (p >= 60) return 'Needs Attention';
    return 'Critical';
  }

  Color _pctColor(StaffThemeProvider theme, double p) {
    if (p >= 90) return theme.green;
    if (p >= 75) return theme.cyan;
    if (p >= 60) return theme.amber;
    return theme.pink;
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
                      Text('Bio Attendance',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                      Text('Biometric Records',
                          style: TextStyle(
                              color: theme.cyan.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.green.withOpacity(0.3)),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.green,
                            boxShadow: [BoxShadow(
                                color: theme.green.withOpacity(0.6),
                                blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('LIVE',
                            style: TextStyle(
                                color: theme.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ]),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: theme.textMid, size: 20),
                  onPressed: _loadAttendance,
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
          isHod: _isHod, currentRoute: '/bio-attendance'),
      body: _loading
          ? _buildLoading(theme)
          : _error != null
              ? _buildError(theme)
              : RefreshIndicator(
                  onRefresh: _loadAttendance,
                  color: theme.cyan,
                  backgroundColor: theme.surface,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: FadeTransition(
                          opacity: _listFade,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 40),
                            child: Column(children: [
                              _animated(0, _buildHero(theme)),
                              const SizedBox(height: 14),
                              _animated(1, _buildStats(theme)),
                              const SizedBox(height: 14),
                              _animated(2, _buildDateSection(theme)),
                              const SizedBox(height: 14),
                              _animated(3, _buildSearchBar(theme)),
                              const SizedBox(height: 14),
                              _animated(4, _buildList(theme)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────
  Widget _buildHero(StaffThemeProvider theme) {
    return SlideTransition(
      position: _heroSlide,
      child: FadeTransition(
        opacity: _heroFade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.bannerGradient,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cyan.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: theme.cyan.withOpacity(0.08), blurRadius: 30)
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile row
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [theme.cyan, theme.violet]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: theme.cyan.withOpacity(0.4),
                            blurRadius: 12)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials(_profile?['name']),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        _profile?['name'] ?? 'Staff Member',
                        style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        _heroChip(theme, Icons.badge_outlined,
                            _profile?['staff_id'] ?? _staffId ?? '—'),
                        const SizedBox(width: 6),
                        _heroChip(theme, Icons.fingerprint,
                            'Bio: ${_bioId ?? '—'}'),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                    height: 1,
                    color: theme.border.withOpacity(0.5)),
                const SizedBox(height: 16),
                // Today section
                _buildTodayRow(theme),
              ]),
        ),
      ),
    );
  }

  Widget _heroChip(StaffThemeProvider theme, IconData icon, String label) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cyan.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.cyan.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: theme.cyan),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.textMid,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildTodayRow(StaffThemeProvider theme) {
    final t = _today;
    if (t == null || t.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.amber.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 15, color: theme.amber),
          const SizedBox(width: 8),
          Text('No check-in recorded today',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.textMid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
    }

    final statusKey = t['statusKey'] ?? 'absent';
    final statusColor = _statusColor(theme, statusKey);
    final isPresent = statusKey != 'absent';
    final hasOut = t['hasOut'] as bool;
    final inDisplay = t['inDisplay'] as String;
    final outDisplay = t['outDisplay'] as String;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(
          "Today • ${DateFormat('dd MMM').format(DateTime.now())}",
          style: TextStyle(
              fontSize: 11,
              color: theme.textLow,
              fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            (t['status'] ?? 'Absent').toUpperCase(),
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: statusColor,
                letterSpacing: 0.8),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _timeBlock(theme,
            label: 'CHECK IN',
            time: inDisplay,
            color: theme.green,
            icon: Icons.login_rounded,
            active: isPresent)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(children: [
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: theme.textLow),
            if (isPresent && hasOut)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_hoursWorked(t['first_in'], t['last_out']).toStringAsFixed(1)}h',
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.cyan,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ]),
        ),
        Expanded(child: _timeBlock(theme,
            label: 'CHECK OUT',
            time: outDisplay,
            color: theme.pink,
            icon: Icons.logout_rounded,
            active: hasOut)),
      ]),
    ]);
  }

  Widget _timeBlock(StaffThemeProvider theme, {
    required String label,
    required String time,
    required Color color,
    required IconData icon,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: active
            ? color.withOpacity(0.1)
            : theme.elevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? color.withOpacity(0.3)
              : theme.border.withOpacity(0.5),
        ),
      ),
      child: Row(children: [
        Icon(icon,
            size: 15, color: active ? color : theme.textLow),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  color: active ? color.withOpacity(0.7) : theme.textLow,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(time,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: active ? theme.textHigh : theme.textLow)),
        ]),
      ]),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────
  Widget _buildStats(StaffThemeProvider theme) {
    if (_stats == null) return const SizedBox.shrink();
    final pct = _stats!['pct'] as double;
    final pc = _pctColor(theme, pct);
    final onTime = _stats!['onTime'] as int;
    final late = _stats!['late'] as int;
    final absent = _stats!['absent'] as int;
    final total = _stats!['total'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
              color: theme.cyan.withOpacity(0.05), blurRadius: 14)
        ],
      ),
      child: Row(children: [
        SizedBox(
          width: 68, height: 68,
          child: CustomPaint(
            painter: _ArcRingPainter(
              value: pct / 100,
              ringColor: pc,
              trackColor: theme.elevated2,
              strokeWidth: 6,
            ),
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text('${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: pc,
                        height: 1)),
                Text('attend.',
                    style: TextStyle(
                        fontSize: 7,
                        color: theme.textLow,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(_pctLabel(pct),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pc)),
            const SizedBox(height: 8),
            Row(children: [
              _statChip(theme, '$onTime', 'On Time', theme.green),
              const SizedBox(width: 6),
              _statChip(theme, '$late', 'Late', theme.amber),
              const SizedBox(width: 6),
              _statChip(theme, '$absent', 'Absent', theme.pink),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.cyan.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text('$total',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: theme.cyan)),
            Text('days',
                style: TextStyle(
                    fontSize: 9,
                    color: theme.textLow,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  Widget _statChip(StaffThemeProvider theme, String val,
      String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(val,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── Date Section ──────────────────────────────────────────────────
  Widget _buildDateSection(StaffThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
              color: theme.violet.withOpacity(0.04), blurRadius: 14)
        ],
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.violet.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
              border:
                  Border.all(color: theme.violet.withOpacity(0.25)),
            ),
            child: Icon(Icons.date_range_rounded,
                size: 14, color: theme.violet),
          ),
          const SizedBox(width: 10),
          Text('Date Range',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            '${DateFormat('dd MMM').format(_from)} – ${DateFormat('dd MMM').format(_to)}',
            style:
                TextStyle(fontSize: 11, color: theme.textLow),
          ),
        ]),
        const SizedBox(height: 14),
        // Presets
        Row(
          children: [7, 15, 30, 60].map((d) {
            final active = _activePreset == d;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: d != 60 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => _setPreset(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(
                              colors: [theme.violet, theme.cyan])
                          : null,
                      color: active ? null : theme.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: active
                              ? Colors.transparent
                              : theme.border),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: theme.violet
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text('${d}D',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : theme.textMid)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Date pickers
        Row(children: [
          Expanded(
              child: _datePicker(theme, 'From', _from, true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: theme.textLow),
          ),
          Expanded(
              child: _datePicker(theme, 'To', _to, false)),
        ]),
        const SizedBox(height: 12),
        // Apply button
        GestureDetector(
          onTap: _loadAttendance,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [theme.cyan, theme.violet]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: theme.cyan.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Icon(Icons.search_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Show Records',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _datePicker(StaffThemeProvider theme, String label,
      DateTime date, bool isFrom) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 12, color: theme.cyan),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.textLow,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(DateFormat('dd MMM yyyy').format(date),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textHigh),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────
  Widget _buildSearchBar(StaffThemeProvider theme) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(fontSize: 13, color: theme.textHigh),
        decoration: InputDecoration(
          hintText: 'Search by date, status, location…',
          hintStyle: TextStyle(fontSize: 13, color: theme.textLow),
          prefixIcon: Icon(Icons.search_rounded,
              color: theme.cyan, size: 18),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: theme.textMid),
                  onPressed: () => _searchCtrl.clear())
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 4),
        ),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────
  Widget _buildList(StaffThemeProvider theme) {
    return Column(children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.history_rounded,
              size: 14, color: theme.cyan),
        ),
        const SizedBox(width: 10),
        Text('Attendance History',
            style: TextStyle(
                color: theme.textHigh,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${_filtered.length} of ${_records.length}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.cyan)),
        ),
      ]),
      const SizedBox(height: 12),
      if (_filtered.isEmpty)
        _buildEmpty(theme)
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filtered.length,
          itemBuilder: (_, i) =>
              _attendanceCard(theme, _filtered[i]),
        ),
    ]);
  }

  Widget _buildEmpty(StaffThemeProvider theme) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(children: [
          Icon(
            _search.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.calendar_today_outlined,
            size: 44,
            color: theme.textLow,
          ),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty
                ? 'No matches found'
                : 'No records found',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textMid),
          ),
          const SizedBox(height: 4),
          Text(
            _search.isNotEmpty
                ? 'Try different keywords'
                : 'Try a different date range',
            style: TextStyle(fontSize: 12, color: theme.textLow),
          ),
        ]),
      );

  // ── Attendance Card ───────────────────────────────────────────────
  Widget _attendanceCard(
      StaffThemeProvider theme, Map<String, dynamic> r) {
    final dateStr = r['date'] ?? '';
    final statusKey = r['statusKey'] ?? 'absent';
    final status = r['status'] ?? 'Absent';
    final statusColor = _statusColor(theme, statusKey);
    final isPresent = statusKey != 'absent';
    final hasOut = r['hasOut'] as bool;
    final inDisplay = r['inDisplay'] as String;
    final outDisplay = r['outDisplay'] as String;
    final inPlace = r['inPlace'] as String;
    final isToday =
        dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

    DateTime? dateObj;
    try { dateObj = DateTime.parse(dateStr); } catch (_) {}

    return GestureDetector(
      onTap: () => _showDetails(theme, r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isToday
              ? theme.cyan.withOpacity(0.05)
              : theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? theme.cyan.withOpacity(0.3)
                : statusColor.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
                color: statusColor.withOpacity(isToday ? 0.08 : 0.04),
                blurRadius: isToday ? 12 : 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 54,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(
                  dateObj != null
                      ? DateFormat('dd').format(dateObj)
                      : '--',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: statusColor),
                ),
                Text(
                  dateObj != null
                      ? DateFormat('MMM').format(dateObj)
                      : '',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: statusColor.withOpacity(0.7),
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  dateObj != null
                      ? DateFormat('EEE').format(dateObj)
                      : '',
                  style: TextStyle(
                      fontSize: 8,
                      color: statusColor.withOpacity(0.5)),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(
                      _getDayName(dateStr),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.textHigh),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              theme.cyan.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                        child: Text('TODAY',
                            style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: theme.cyan,
                                letterSpacing: 0.5)),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  Row(children: [
                    Icon(Icons.login_rounded,
                        size: 11,
                        color: isPresent
                            ? theme.green
                            : theme.textLow),
                    const SizedBox(width: 4),
                    Text(inDisplay,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPresent
                                ? theme.textHigh
                                : theme.textLow)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        size: 9, color: theme.textLow),
                    const SizedBox(width: 6),
                    Icon(Icons.logout_rounded,
                        size: 11,
                        color: hasOut
                            ? theme.pink
                            : theme.textLow),
                    const SizedBox(width: 4),
                    Text(outDisplay,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasOut
                                ? theme.textHigh
                                : theme.textLow)),
                    if (isPresent && hasOut) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.cyan.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_hoursWorked(r['first_in'], r['last_out']).toStringAsFixed(1)}h',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.cyan),
                        ),
                      ),
                    ],
                  ]),
                  if (isPresent && inPlace.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 9, color: theme.textLow),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(inPlace,
                            style: TextStyle(
                                fontSize: 9,
                                color: theme.textLow),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right_rounded,
                  size: 16, color: theme.textLow),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Detail Sheet ──────────────────────────────────────────────────
  void _showDetails(
      StaffThemeProvider theme, Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.border),
        ),
        padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: _detailContent(theme, r),
        ),
      ),
    );
  }

  Widget _detailContent(
      StaffThemeProvider theme, Map<String, dynamic> r) {
    final dateStr = r['date'] ?? '';
    final statusKey = r['statusKey'] ?? 'absent';
    final status = r['status'] ?? 'Absent';
    final statusColor = _statusColor(theme, statusKey);
    final isPresent = statusKey != 'absent';
    final hasOut = r['hasOut'] as bool;
    final inDisplay = r['inDisplay'] as String;
    final outDisplay = r['outDisplay'] as String;
    final inPlace = r['inPlace'] as String;
    final outPlace = r['outPlace'] as String;
    final lateNote = r['first_in_late']?.toString() ?? '';

    DateTime? dateObj;
    try { dateObj = DateTime.parse(dateStr); } catch (_) {}

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
      Center(
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: theme.border,
              borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 20),
      // Header
      Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Text(
              dateObj != null
                  ? DateFormat('dd').format(dateObj)
                  : '--',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: statusColor),
            ),
            Text(
              dateObj != null
                  ? DateFormat('MMM').format(dateObj)
                  : '',
              style: TextStyle(
                  fontSize: 9,
                  color: statusColor.withOpacity(0.7)),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              _getDayName(dateStr),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textHigh),
            ),
            if (dateObj != null)
              Text(DateFormat('dd MMMM yyyy').format(dateObj),
                  style: TextStyle(
                      fontSize: 12, color: theme.textLow)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: statusColor.withOpacity(0.3)),
              ),
              child: Text(status,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      Divider(color: theme.border),
      const SizedBox(height: 16),
      if (isPresent) ...[
        _timelineRow(theme,
            label: 'Check In',
            time: inDisplay,
            place: inPlace,
            color: theme.green,
            icon: Icons.login_rounded,
            lateNote: lateNote.toLowerCase().contains('late')
                ? lateNote
                : null,
            showLine: hasOut),
        if (hasOut) ...[
          const SizedBox(height: 4),
          _timelineRow(theme,
              label: 'Check Out',
              time: outDisplay,
              place: outPlace,
              color: theme.pink,
              icon: Icons.logout_rounded,
              showLine: false),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.cyan.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.timer_outlined,
                    size: 18, color: theme.cyan),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Total Hours Worked',
                    style: TextStyle(
                        fontSize: 11, color: theme.textMid)),
                Text(
                  '${_hoursWorked(r['first_in'], r['last_out']).toStringAsFixed(1)} hours',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.cyan),
                ),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Completed',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.green)),
              ),
            ]),
          ),
        ],
      ] else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.pink.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: theme.pink.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.cancel_outlined, color: theme.pink, size: 20),
            const SizedBox(width: 12),
            Text('No check-in recorded for this day.',
                style: TextStyle(
                    fontSize: 13, color: theme.textMid)),
          ]),
        ),
      ],
      const SizedBox(height: 8),
    ]);
  }

  Widget _timelineRow(StaffThemeProvider theme, {
    required String label,
    required String time,
    required String place,
    required Color color,
    required IconData icon,
    String? lateNote,
    required bool showLine,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        if (showLine)
          Container(
            width: 2, height: 32,
            color: theme.border,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
      ]),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: theme.textLow,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: theme.textHigh)),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 10, color: theme.textLow),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(place,
                      style: TextStyle(
                          fontSize: 11, color: theme.textMid),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            if (lateNote != null) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('⚠ $lateNote',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.amber,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            if (showLine) const SizedBox(height: 4),
          ]),
        ),
      ),
    ]);
  }

  // ── Loading / Error ───────────────────────────────────────────────
  Widget _buildLoading(StaffThemeProvider theme) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(
            width: 60, height: 60,
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
          Text('Loading attendance…',
              style: TextStyle(
                  fontSize: 14,
                  color: theme.textMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Please wait',
              style:
                  TextStyle(fontSize: 12, color: theme.textLow)),
        ]),
      );

  Widget _buildError(StaffThemeProvider theme) {
    final isServerDown = (_error ?? '').contains('10.10.0') ||
        (_error ?? '').contains('Failed to connect') ||
        (_error ?? '').contains('SocketException');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isServerDown ? theme.amber : theme.pink)
                  .withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isServerDown
                  ? Icons.dns_rounded
                  : Icons.wifi_off_rounded,
              size: 40,
              color: isServerDown ? theme.amber : theme.pink,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isServerDown
                ? 'Biometric Server Offline'
                : 'Connection Error',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textHigh),
          ),
          const SizedBox(height: 12),
          Text(
            isServerDown
                ? 'The biometric server is unreachable.\nPlease contact IT Support.'
                : (_error ?? 'Check your internet connection.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: theme.textMid,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [theme.cyan, theme.violet]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: theme.cyan.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Text('Try Again',
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
}

// ── Arc Ring Painter ──────────────────────────────────────────────────
class _ArcRingPainter extends CustomPainter {
  final double value;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  const _ArcRingPainter({
    required this.value,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -1.5707963267948966;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (value > 0) {
      final arcPaint = Paint()
        ..color = ringColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        value * 6.283185307179586,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.value != value || old.ringColor != ringColor;
}