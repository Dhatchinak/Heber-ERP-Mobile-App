import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kApiBase = 'https://apierp.bhc.edu.in';
const String _kReferer = 'http://117.232.64.75';

class TimetableScreen extends StatefulWidget {
  final String rollNo;
  const TimetableScreen({super.key, required this.rollNo});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _student;
  Map<String, dynamic>? _timetable;
  bool _loading = true;
  String _error = '';
  int _selectedDay = 1; // 1–6, student chooses manually

  String _programName = '';
  String _section = '';
  int _year = 1;
  String _programId = '';
  String _shift = 'Regular';
  String _studentName = '';

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _pageAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _pageFade =
      CurvedAnimation(parent: _pageAnim, curve: Curves.easeOut);
  late final Animation<Offset> _pageSlide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _pageAnim, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _load();
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    _studentName = prefs.getString('studentName') ?? '';
    setState(() {});
  }

  // ── Time slots ─────────────────────────────────────────────────────────────
  static const Map<int, String> _slots = {
    1: '8:30 – 9:25',
    2: '9:25 – 10:20',
    3: '10:20 – 11:15',
    4: '11:30 – 12:20',
    5: '12:20 – 1:10',
    6: '2:00 – 3:00',
  };

  // ── Paper colors ────────────────────────────────────────────────────────────
  Color _paperColor(String type, ThemeProvider c) {
    final t = type.toLowerCase();
    if (t.contains('lab') || t.contains('prac')) return c.green;
    if (t.contains('core')) return c.cyan;
    if (t.contains('elective') || t.contains('nmec') || t.contains('optional'))
      return c.amber;
    if (t.contains('allied')) return c.violet;
    if (t.contains('project') || t.contains('research') ||
        t.contains('dissertation'))
      return c.pink;
    if (t.contains('language') || t.contains('english') ||
        t.contains('communicative'))
      return c.cyanDim;
    if (t.contains('seminar') || t.contains('tutorial')) return c.violetBright;
    return c.textMid;
  }

  IconData _paperIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('lab') || t.contains('prac')) return Icons.computer_rounded;
    if (t.contains('project') || t.contains('research'))
      return Icons.work_outline_rounded;
    if (t.contains('language') || t.contains('english'))
      return Icons.language_rounded;
    if (t.contains('elective') || t.contains('nmec'))
      return Icons.auto_stories_rounded;
    if (t.contains('allied')) return Icons.extension_rounded;
    if (t.contains('seminar') || t.contains('tutorial'))
      return Icons.forum_rounded;
    return Icons.menu_book_rounded;
  }

  // ── Data loading ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _fetchStudent();
      if (_error.isEmpty) await _fetchTimetable();
    } catch (e) {
      _fail('Unexpected error: $e');
    }
  }

  Future<void> _fetchStudent() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_kApiBase/api/students/${widget.rollNo}'),
            headers: {'Referer': _kReferer},
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        final d = j['data'];
        if (d != null) {
          _student = d;
          _programId = d['current_academic']?['program_id'] ?? '';
          _programName = d['current_academic']?['program_name'] ?? '';
          _section = d['current_academic']?['section'] ?? '';
          _year = _parseYear(d['batch'] ?? '');
          // Get student name from API response
          _studentName = d['name'] ?? _studentName;
        } else {
          _fail('Student not found.');
        }
      } else {
        _fail('Student API error ${res.statusCode}.');
      }
    } catch (e) {
      _fail('Network error: $e');
    }
  }

  Future<void> _fetchTimetable() async {
    if (!mounted) return;
    try {
      final deptCode =
          _student?['current_academic']?['department_code'] ?? '';
      if (deptCode.isEmpty) {
        _fail('Department code not found.');
        return;
      }
      final res = await http
          .get(
            Uri.parse('$_kApiBase/api/admin/departments/code/$deptCode'),
            headers: {'Accept': 'application/json', 'Referer': _kReferer},
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        final programs = j['programs'] as List? ?? [];
        for (final p in programs) {
          final pn = p['program_name']?.toString() ?? '';
          final pi = p['program_id']?.toString() ?? '';
          if (pn.toLowerCase().contains(_programName.toLowerCase()) ||
              pi == _programId) {
            for (final y in (p['years'] as List? ?? [])) {
              if (y['year'] == _year) {
                for (final s in (y['sections'] as List? ?? [])) {
                  if (s['section_name']?.toString() == _section) {
                    if (!mounted) return;
                    setState(() {
                      _timetable = {
                        'program_name': pn,
                        'section_shift':
                            s['section_shift']?.toString() ?? 'Regular',
                        'timetable': s['TimeTable'] as List? ?? [],
                      };
                      _shift = _timetable!['section_shift'];
                      _loading = false;
                    });
                    _pageAnim.forward();
                    return;
                  }
                }
              }
            }
          }
        }
        _fail('Timetable not found for $_programName · Yr $_year · Sec $_section');
      } else {
        _fail('Timetable API error ${res.statusCode}.');
      }
    } catch (e) {
      _fail('Failed to load timetable: $e');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _loading = false;
    });
  }

  int _parseYear(String batch) {
    try {
      final sy = int.tryParse(batch.split('-').first) ?? DateTime.now().year;
      final now = DateTime.now();
      return (now.year - sy + (now.month >= 6 ? 1 : 0)).clamp(1, 4);
    } catch (_) {
      return 1;
    }
  }

  List<dynamic> _dayClasses() {
    if (_timetable == null) return [];
    final tt = _timetable!['timetable'] as List;
    return (tt.firstWhere(
          (d) => d['dayOrder'] == _selectedDay,
          orElse: () => {'hours': []},
        )['hours'] as List?) ??
        [];
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isDarkMode
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: c.bg,
        drawer: CustomDrawer(
          rollNo: widget.rollNo,
          studentName: _studentName.isNotEmpty ? _studentName : 'Student',
          currentRoute: '/timetable',
        ),
        body: _loading
            ? _buildLoading(c)
            : _error.isNotEmpty
                ? _buildError(c)
                : _buildContent(c),
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────────────────────────
  Widget _buildLoading(ThemeProvider c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.cyan,
                backgroundColor: c.cyan.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Loading Timetable',
              style: TextStyle(
                color: c.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Fetching schedule…',
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
          ],
        ),
      );

  // ── Error ────────────────────────────────────────────────────────────────────
  Widget _buildError(ThemeProvider c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.pink.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.pink.withOpacity(0.22)),
                ),
                child: Icon(Icons.wifi_off_rounded, color: c.pink, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                'Could not load',
                style: TextStyle(
                  color: c.textHigh,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: c.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.cyan.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: c.cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Main content ─────────────────────────────────────────────────────────────
  Widget _buildContent(ThemeProvider c) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _appBar(c),
            SliverToBoxAdapter(child: _heroBanner(c)),
            SliverToBoxAdapter(child: _dayPickerSection(c)),
            SliverToBoxAdapter(child: _scheduleSection(c)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _appBar(ThemeProvider c) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 58,
      // ← Hamburger menu — opens drawer
      leading: Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _menuLine(c, 14),
                const SizedBox(height: 3),
                _menuLine(c, 10),
                const SizedBox(height: 3),
                _menuLine(c, 12),
              ],
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Timetable',
            style: TextStyle(
              color: c.textHigh,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            _programName.isNotEmpty ? _programName : 'Schedule',
            style: TextStyle(
              color: c.cyan.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: _load,
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.refresh_rounded, color: c.textMid, size: 18),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }

  Widget _menuLine(ThemeProvider c, double w) => Container(
        width: w,
        height: 2,
        decoration: BoxDecoration(
          color: c.textHigh,
          borderRadius: BorderRadius.circular(1),
        ),
      );

  // ── Hero banner ───────────────────────────────────────────────────────────
  Widget _heroBanner(ThemeProvider c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.cyan.withOpacity(0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.bannerGradient,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SCHEDULE',
                      style: TextStyle(
                        color: c.cyan.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _timetable?['program_name'] ?? _programName,
                  style: TextStyle(
                    color: c.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _heroPill('Year $_year', c.cyan, c),
                    _heroPill('Section $_section', c.violet, c),
                    _heroPill(_shift, c.green, c),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.cyan.withOpacity(0.22)),
            ),
            child: Column(
              children: [
                Text(
                  'DAY',
                  style: TextStyle(
                    color: c.textMid,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_selectedDay',
                  style: TextStyle(
                    color: c.cyan,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SELECTED',
                  style: TextStyle(
                    color: c.textLow,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String label, Color color, ThemeProvider c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  // ── Day picker (1–6 grid) ──────────────────────────────────────────────────
  Widget _dayPickerSection(ThemeProvider c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: c.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Choose Day Order',
                style: TextStyle(
                  color: c.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(6, (i) {
              final day = i + 1;
              final active = _selectedDay == day;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDay = day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? c.cyan : c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? c.cyan : c.border,
                        width: active ? 1.5 : 1,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: c.cyan.withOpacity(0.30),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: active ? Colors.white : c.textHigh,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'DAY',
                          style: TextStyle(
                            color: active
                                ? Colors.white.withOpacity(0.6)
                                : c.textLow,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? Colors.white.withOpacity(0.7)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Schedule section ────────────────────────────────────────────────────────
  Widget _scheduleSection(ThemeProvider c) {
    final classes = _dayClasses();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: c.violet,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Day $_selectedDay  —  Schedule',
                style: TextStyle(
                  color: c.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.cyan.withOpacity(0.22)),
                ),
                child: Text(
                  '${classes.length} class${classes.length != 1 ? 'es' : ''}',
                  style: TextStyle(
                    color: c.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (classes.isEmpty)
            _emptyDay(c)
          else
            ...classes.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _classCard(c, e.value as Map<String, dynamic>, e.key),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Class card ──────────────────────────────────────────────────────────────
  Widget _classCard(ThemeProvider c, Map<String, dynamic> item, int idx) {
    final hour = item['hour'] as int? ?? (idx + 1);
    final subject = item['paperTitle'] as String? ?? 'Subject';
    final faculty = item['staffName'] as String? ?? 'Staff';
    final paperType = item['paperType'] as String? ?? 'Class';
    final paperCode = item['paperCode'] as String? ?? '';
    final color = _paperColor(paperType, c);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + idx * 55),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 68,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$hour',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _slots[hour] ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _paperIcon(paperType),
                                  size: 10,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  paperType,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (paperCode.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Text(
                              paperCode,
                              style: TextStyle(
                                color: c.textLow,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subject,
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c.elevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: c.textLow,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              faculty,
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

  // ── Empty day ──────────────────────────────────────────────────────────────
  Widget _emptyDay(ThemeProvider c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
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
                color: c.green.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: c.green.withOpacity(0.2)),
              ),
              child:
                  Icon(Icons.celebration_rounded, color: c.green, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Free Day',
              style: TextStyle(
                color: c.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No classes scheduled for Day $_selectedDay',
              style: TextStyle(color: c.textMid, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}