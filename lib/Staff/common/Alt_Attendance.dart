// ==========================================================================
//  ALTERNATIVE ATTENDANCE — pick UG/PG → Department → Program → Year →
//  Section → Day Order → Hour(s) → Date, fetch students, mark & submit.
//  Not restricted to the staff's own timetable (class_attend) like the
//  regular Class Attendance screen — staff can pick any class taught in
//  the college.
// ==========================================================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../theme_provider.dart';
import '../widgets/app_drawer.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';

const String _kBaseApiUrl = 'https://apierp.bhc.edu.in';
const String _kRefererUrl = 'http://10.240.151.162';

Map<String, String> get _headers => {
      'Referer': _kRefererUrl,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

// ==========================================================================
//  Shared app bar (matches the app-wide profile / class-attendance format)
// ==========================================================================
PreferredSizeWidget _brandAppBar(
  BuildContext context,
  StaffThemeProvider t, {
  required String title,
  required String subtitle,
  Widget? trailing,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.cyan.withOpacity(0.18))),
        boxShadow: [
          BoxShadow(color: t.cyan.withOpacity(0.06), blurRadius: 16),
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
                    color: t.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(Icons.menu_rounded, color: t.textHigh, size: 18),
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
                  Text(title,
                      style: TextStyle(
                          color: t.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                  Text(subtitle,
                      style: TextStyle(
                          color: t.cyan.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 8),
          ]),
        ),
      ),
    ),
  );
}

// ==========================================================================
//  STEP 1 — Manual class + day order/hour selection
// ==========================================================================
class AlternativeAttendanceScreen extends StatefulWidget {
  final String staffId;
  const AlternativeAttendanceScreen({super.key, required this.staffId});

  @override
  State<AlternativeAttendanceScreen> createState() =>
      _AlternativeAttendanceScreenState();
}

class _AlternativeAttendanceScreenState
    extends State<AlternativeAttendanceScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _departments = []; // raw department objects

  String _level = 'UG';
  Map<String, dynamic>? _selectedDept;
  Map<String, dynamic>? _selectedProgram;
  int? _selectedYear;
  String? _selectedSection;
  String? _selectedShift;
  int? _dayOrder;
  final Set<int> _hours = {};
  DateTime _date = DateTime.now();
  final _topicCtrl = TextEditingController();

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  int get _stepsDone {
    int n = 0;
    if (_selectedDept != null) n++;
    if (_selectedProgram != null) n++;
    if (_selectedYear != null && _selectedSection != null) n++;
    if (_dayOrder != null) n++;
    if (_hours.isNotEmpty) n++;
    return n;
  }

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final res = await http
          .get(Uri.parse('$_kBaseApiUrl/api/admin/departments'),
              headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final depts = (data['departments'] ?? data['data'] ?? data) as List;
        _departments = depts.cast<Map<String, dynamic>>();
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'Failed to load departments (${res.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _deptsForLevel {
    return _departments.where((d) {
      final programs = (d['programs'] as List?) ?? [];
      return programs.any((p) => (p['program_id']?.toString() ?? '')
          .toUpperCase()
          .startsWith('$_level-'));
    }).toList();
  }

  List<Map<String, dynamic>> get _programsForDept {
    if (_selectedDept == null) return [];
    final programs = (_selectedDept!['programs'] as List?) ?? [];
    return programs
        .where((p) => (p['program_id']?.toString() ?? '')
            .toUpperCase()
            .startsWith('$_level-'))
        .cast<Map<String, dynamic>>()
        .toList();
  }

  List<int> get _yearsForProgram {
    if (_selectedProgram == null) return [];
    final years = (_selectedProgram!['years'] as List?) ?? [];
    return years
        .map((y) => int.tryParse(y['year'].toString()) ?? 0)
        .where((y) => y > 0)
        .toList()
      ..sort();
  }

  List<Map<String, dynamic>> get _sectionsForYear {
    if (_selectedProgram == null || _selectedYear == null) return [];
    final years = (_selectedProgram!['years'] as List?) ?? [];
    final match = years.firstWhere(
        (y) => int.tryParse(y['year'].toString()) == _selectedYear,
        orElse: () => null);
    if (match == null) return [];
    return ((match['sections'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  void _continue() {
    if (_selectedProgram == null ||
        _selectedYear == null ||
        _selectedSection == null) {
      _snack('Please complete Department, Program, Year and Section');
      return;
    }
    if (_dayOrder == null) {
      _snack('Please select a Day Order');
      return;
    }
    if (_hours.isEmpty) {
      _snack('Please select at least one Hour');
      return;
    }

    final hoursList = _hours.toList()..sort();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlternativeMarkAttendanceScreen(
          staffId: widget.staffId,
          selectedClass: {
            'program_id': _selectedProgram!['program_id'].toString(),
            'year': _selectedYear.toString(),
            'section_name': _selectedSection!,
            'shift': _selectedShift ?? '1',
          },
          selectedDate: _date,
          dayOrder: _dayOrder!,
          hours: hoursList,
          topic: _topicCtrl.text.trim(),
        ),
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<StaffThemeProvider>(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _brandAppBar(
        context,
        t,
        title: 'Alternative Attendance',
        subtitle: 'PICK ANY CLASS',
        trailing: Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: t.violet.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.violet.withOpacity(0.3)),
          ),
          child: Text('$_stepsDone/5',
              style: TextStyle(
                  color: t.violet, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ),
      drawer: AppDrawer(isHod: _isHod, currentRoute: '/alt-attendance'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.cyan))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_errorMessage,
                        style: TextStyle(color: t.textMid),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: _fetchDepartments,
                        child: const Text('Retry')),
                  ]),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: t.cyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cyan.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            Icon(Icons.event_available_rounded,
                                color: t.cyan, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Not limited to your assigned timetable',
                                style: TextStyle(
                                    color: t.textMid,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        _card(t, children: [
                          _sectionLabel(
                              t, '1', Icons.school_rounded, 'Program Level'),
                          Row(children: [
                            _levelChip(t, 'UG'),
                            const SizedBox(width: 10),
                            _levelChip(t, 'PG'),
                          ]),
                          const SizedBox(height: 16),
                          _sectionLabel(t, '2', Icons.apartment_rounded,
                              'Department & Program'),
                          _dropdownContainer<Map<String, dynamic>>(
                            t: t,
                            value: _selectedDept,
                            hint: 'Select department',
                            itemLabel: (d) =>
                                '${d['department_name'] ?? d['department_code']}',
                            items: _deptsForLevel,
                            onChanged: (v) => setState(() {
                              _selectedDept = v;
                              _selectedProgram = null;
                              _selectedYear = null;
                              _selectedSection = null;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _dropdownContainer<Map<String, dynamic>>(
                            t: t,
                            value: _selectedProgram,
                            hint: 'Select program',
                            itemLabel: (p) =>
                                '${p['program_name'] ?? p['program_id']}',
                            items: _programsForDept,
                            onChanged: (v) => setState(() {
                              _selectedProgram = v;
                              _selectedYear = null;
                              _selectedSection = null;
                            }),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _card(t, children: [
                          _sectionLabel(
                              t, '3', Icons.groups_rounded, 'Year & Section'),
                          Row(children: [
                            Expanded(
                              child: _dropdownContainer<int>(
                                t: t,
                                value: _selectedYear,
                                hint: 'Year',
                                itemLabel: (y) => 'Year $y',
                                items: _yearsForProgram,
                                onChanged: (v) => setState(() {
                                  _selectedYear = v;
                                  _selectedSection = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dropdownContainer<Map<String, dynamic>>(
                                t: t,
                                value: _sectionsForYear.firstWhere(
                                    (s) =>
                                        s['section_name'] == _selectedSection,
                                    orElse: () => {}),
                                hint: 'Section',
                                itemLabel: (s) => '${s['section_name']}',
                                items: _sectionsForYear,
                                onChanged: (v) => setState(() {
                                  _selectedSection =
                                      v?['section_name']?.toString();
                                  _selectedShift =
                                      (v?['section_shift']?.toString() ?? '1')
                                          .replaceAll(RegExp(r'[^0-9]'), '');
                                  if (_selectedShift == null ||
                                      _selectedShift!.isEmpty) {
                                    _selectedShift = '1';
                                  }
                                }),
                              ),
                            ),
                          ]),
                        ]),
                        const SizedBox(height: 11),
                        _card(t, children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel(
                                        t, '4', Icons.schedule_rounded, 'Day'),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: List.generate(6, (i) => i + 1)
                                          .map((d) {
                                        final selected = _dayOrder == d;
                                        return _squareChip(
                                          t,
                                          label: '$d',
                                          selected: selected,
                                          color: t.cyan,
                                          onTap: () =>
                                              setState(() => _dayOrder = d),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel(
                                        t,
                                        '5',
                                        Icons.access_time_filled_rounded,
                                        'Hour'),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: List.generate(5, (i) => i + 1)
                                          .map((h) {
                                        final selected = _hours.contains(h);
                                        return _squareChip(
                                          t,
                                          label: '$h',
                                          selected: selected,
                                          color: t.violet,
                                          onTap: () => setState(() => selected
                                              ? _hours.remove(h)
                                              : _hours.add(h)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 11),
                        _card(t, children: [
                          _sectionLabel(
                              t, '6', Icons.calendar_month_rounded, 'Date'),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 30)),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _date = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: t.elevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: t.border),
                              ),
                              child: Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 18, color: t.cyan),
                                const SizedBox(width: 10),
                                Text(DateFormat('dd MMM yyyy').format(_date),
                                    style: TextStyle(
                                        color: t.textHigh,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Icon(Icons.expand_more_rounded,
                                    size: 18, color: t.textLow),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionLabel(t, '7', Icons.edit_note_rounded,
                              'Topic (optional)'),
                          Container(
                            decoration: BoxDecoration(
                              color: t.elevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.border),
                            ),
                            child: TextField(
                              controller: _topicCtrl,
                              style: TextStyle(color: t.textHigh, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'What will be covered',
                                hintStyle:
                                    TextStyle(color: t.textLow, fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: t.primaryGradient),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: t.cyan.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _continue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.groups_2_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Find Students',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                ),
    );
  }

  Widget _card(StaffThemeProvider t, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionLabel(
      StaffThemeProvider t, String step, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.cyan.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Text(step,
              style: TextStyle(
                  color: t.cyan, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: t.textMid),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: t.textMid)),
      ]),
    );
  }

  Widget _levelChip(StaffThemeProvider t, String level) {
    final selected = _level == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _level = level;
          _selectedDept = null;
          _selectedProgram = null;
          _selectedYear = null;
          _selectedSection = null;
        }),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient:
                selected ? LinearGradient(colors: t.primaryGradient) : null,
            color: selected ? null : t.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.transparent : t.border),
          ),
          child: Text(level,
              style: TextStyle(
                  color: selected ? Colors.white : t.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _pillChip(
    StaffThemeProvider t, {
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : t.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : t.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : t.textMid,
                fontWeight: FontWeight.w600,
                fontSize: 12.5)),
      ),
    );
  }

  Widget _squareChip(
    StaffThemeProvider t, {
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : t.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : t.border),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : t.textMid,
                fontWeight: FontWeight.w800,
                fontSize: 13.5)),
      ),
    );
  }

  Widget _dropdownContainer<T>({
    required StaffThemeProvider t,
    required T? value,
    required String hint,
    required String Function(T) itemLabel,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    // Guard against a stale value not present in the current items list.
    final safeValue = items.contains(value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: t.textLow, fontSize: 13)),
          icon: Icon(Icons.expand_more_rounded, color: t.cyan),
          dropdownColor: t.elevated,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
              color: t.textHigh, fontSize: 14, fontWeight: FontWeight.w600),
          items: items
              .map((e) =>
                  DropdownMenuItem<T>(value: e, child: Text(itemLabel(e))))
              .toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

// ==========================================================================
//  STEP 2 — Fetch students for the picked class/date and mark attendance
//  Fast-mark UX: everyone defaults to Present. Tap a row once to flag
//  Absent, tap again to flag Late, tap a third time to restore Present.
//  This turns a 40-student class from ~80 taps (3 buttons each) into a
//  handful of taps — you only touch the exceptions.
// ==========================================================================
class AlternativeMarkAttendanceScreen extends StatefulWidget {
  final String staffId;
  final Map<String, dynamic> selectedClass;
  final DateTime selectedDate;
  final int dayOrder;
  final List<int> hours;
  final String topic;

  const AlternativeMarkAttendanceScreen({
    super.key,
    required this.staffId,
    required this.selectedClass,
    required this.selectedDate,
    required this.dayOrder,
    required this.hours,
    this.topic = '',
  });

  @override
  State<AlternativeMarkAttendanceScreen> createState() =>
      _AlternativeMarkAttendanceScreenState();
}

class _AlternativeMarkAttendanceScreenState
    extends State<AlternativeMarkAttendanceScreen> {
  List<dynamic> _students = [];
  Map<String, String> _status = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  String? _resolvedBatch;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const List<String> _cycle = ['present', 'absent', 'late'];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<String?> _resolveBatch() async {
    final year = int.tryParse(widget.selectedClass['year'].toString()) ?? 1;
    final currentYear = DateTime.now().year;
    final isPg = widget.selectedClass['program_id']
        .toString()
        .toUpperCase()
        .startsWith('PG-');
    final span = isPg ? 2 : 3;
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final candidates = <String>{
      '${currentYear - (year - 1)}-${currentYear - (year - 1) + span}',
      '$currentYear-${currentYear + span}',
      '${currentYear - year}-${currentYear - year + span + 1}',
    };
    for (final batch in candidates) {
      final url = '$_kBaseApiUrl/api/students/attendance/class/'
          '${widget.selectedClass['program_id']}/$batch/'
          '${widget.selectedClass['section_name']}/$formattedDate';
      try {
        final res = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) return batch;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final batch = await _resolveBatch();
      if (batch == null) {
        setState(() {
          _errorMessage = 'No students found for this class/date.';
          _isLoading = false;
        });
        return;
      }
      _resolvedBatch = batch;
      final formattedDate =
          DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      final url = '$_kBaseApiUrl/api/students/attendance/class/'
          '${widget.selectedClass['program_id']}/$batch/'
          '${widget.selectedClass['section_name']}/$formattedDate';
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final students = (data['attendanceData'] ?? []) as List;
        _students = students;
        // Fast-mark default: everyone starts Present unless already marked.
        _status = {
          for (var s in students)
            s['roll_no'].toString(): (() {
              final existing = s['attendance']?['status']?.toString();
              if (existing == null ||
                  existing.isEmpty ||
                  existing == 'not_marked') {
                return 'present';
              }
              return existing;
            })()
        };
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'Failed to load students (${res.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredStudents {
    if (_query.isEmpty) return _students;
    return _students.where((s) {
      final name = (s['name']?.toString() ?? '').toLowerCase();
      final roll = (s['roll_no']?.toString() ?? '').toLowerCase();
      return name.contains(_query) || roll.contains(_query);
    }).toList();
  }

  void _cycleStatus(String roll) {
    final current = _status[roll] ?? 'present';
    final idx = _cycle.indexOf(current);
    final next = _cycle[(idx + 1) % _cycle.length];
    setState(() => _status[roll] = next);
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _students) {
        _status[s['roll_no'].toString()] = status;
      }
    });
  }

  void _showStatusSheet(String status, Color color) {
    final t = Provider.of<StaffThemeProvider>(context, listen: false);
    final list = _students
        .where((s) => (_status[s['roll_no'].toString()] ?? 'present') == status)
        .toList();
    final label = status[0].toUpperCase() + status.substring(1);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: t.border),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('$label Students (${list.length})',
                    style: TextStyle(
                        color: t.textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            Divider(color: t.border, height: 1),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('No students marked $label',
                          style: TextStyle(color: t.textLow)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(14),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final name = s['name']?.toString() ?? '';
                        final roll = s['roll_no'].toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: t.elevated,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(_initials(name),
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          color: t.textHigh,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Text(roll,
                                      style: TextStyle(
                                          color: t.textLow, fontSize: 10.5)),
                                ],
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_students.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final records = _status.entries
          .where((e) => e.value != 'not_marked')
          .map((e) => {'roll_no': e.key, 'status': e.value})
          .toList();

      final body = {
        'staff_id': widget.staffId,
        'hours': widget.hours,
        'dayOrder': widget.dayOrder,
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'attendanceType': 'hourly',
        'attendance_record': records,
        'hour_stat': {
          'topicDelivered': widget.topic,
          'klevel': [],
          'ict': false,
          'teachingMethod': [],
        },
      };

      final res = await http
          .post(
            Uri.parse('$_kBaseApiUrl/api/students/attendance/mark-attendance'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      setState(() => _isSaving = false);
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Attendance saved successfully'),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save (${res.statusCode}).'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Color _statusColor(StaffThemeProvider t, String s) {
    switch (s) {
      case 'present':
        return t.green;
      case 'absent':
        return t.pink;
      case 'late':
        return t.amber;
      default:
        return t.textLow;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'present':
        return Icons.check_rounded;
      case 'absent':
        return Icons.close_rounded;
      case 'late':
        return Icons.schedule_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<StaffThemeProvider>(context);
    final presentCount = _status.values.where((s) => s == 'present').length;
    final absentCount = _status.values.where((s) => s == 'absent').length;
    final lateCount = _status.values.where((s) => s == 'late').length;
    final total = _students.length;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _brandAppBar(
        context,
        t,
        title:
            '${widget.selectedClass['program_id']} • Y${widget.selectedClass['year']}${widget.selectedClass['section_name']}',
        subtitle:
            'DAY ${widget.dayOrder} · HR ${widget.hours.join(", ")} · ${DateFormat('dd MMM').format(widget.selectedDate)}',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.cyan))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage,
                        style: TextStyle(color: t.textMid),
                        textAlign: TextAlign.center),
                  ),
                )
              : Column(children: [
                  // ── Live stats + quick actions ─────────────────────
                  Container(
                    color: t.surface,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(children: [
                      Row(children: [
                        GestureDetector(
                          onTap: () => _showStatusSheet('present', t.green),
                          child: _statChip(t, 'Present', presentCount, t.green),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showStatusSheet('absent', t.pink),
                          child: _statChip(t, 'Absent', absentCount, t.pink),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showStatusSheet('late', t.amber),
                          child: _statChip(t, 'Late', lateCount, t.amber),
                        ),
                        const Spacer(),
                        Text('$total total',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: t.textLow,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 10),
                      // Progress bar of marked coverage
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 6,
                          child: Row(children: [
                            if (presentCount > 0)
                              Expanded(
                                  flex: presentCount,
                                  child: Container(color: t.green)),
                            if (absentCount > 0)
                              Expanded(
                                  flex: absentCount,
                                  child: Container(color: t.pink)),
                            if (lateCount > 0)
                              Expanded(
                                  flex: lateCount,
                                  child: Container(color: t.amber)),
                            if (presentCount + absentCount + lateCount == 0)
                              Expanded(child: Container(color: t.elevated)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(color: t.textHigh, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search name or roll no.',
                              hintStyle:
                                  TextStyle(color: t.textLow, fontSize: 12.5),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 18, color: t.textLow),
                              filled: true,
                              fillColor: t.elevated,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide(color: t.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide(color: t.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide(color: t.cyan),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconAction(
                          t,
                          icon: Icons.done_all_rounded,
                          color: t.green,
                          tooltip: 'Mark all Present',
                          onTap: () => _markAll('present'),
                        ),
                        const SizedBox(width: 6),
                        _iconAction(
                          t,
                          icon: Icons.clear_all_rounded,
                          color: t.pink,
                          tooltip: 'Mark all Absent',
                          onTap: () => _markAll('absent'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.touch_app_rounded,
                            size: 13, color: t.textLow),
                        const SizedBox(width: 5),
                        Text('Tap a card to cycle Present → Absent → Late',
                            style: TextStyle(fontSize: 10.5, color: t.textLow)),
                      ]),
                    ]),
                  ),
                  // ── Student list ─────────────────────────────────
                  Expanded(
                    child: _filteredStudents.isEmpty
                        ? Center(
                            child: Text('No students match your search',
                                style: TextStyle(color: t.textLow)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredStudents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final s = _filteredStudents[i];
                              final roll = s['roll_no'].toString();
                              final name = s['name']?.toString() ?? roll;
                              final status = _status[roll] ?? 'present';
                              final c = _statusColor(t, status);
                              return GestureDetector(
                                onTap: () => _cycleStatus(roll),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: t.surface,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                        color: c.withOpacity(0.5), width: 1.2),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: c.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(_initials(name),
                                          style: TextStyle(
                                              color: c,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: t.textHigh,
                                                  fontSize: 13.5)),
                                          Text(roll,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: t.textLow)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: c,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(_statusIcon(status),
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                                status[0].toUpperCase() +
                                                    status.substring(1),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11.5)),
                                          ]),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border(top: BorderSide(color: t.border)),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                              '${presentCount + absentCount + lateCount}/$total students marked',
                              style: TextStyle(
                                  color: t.textLow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: t.primaryGradient),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: t.cyan.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.cloud_upload_rounded,
                                            color: Colors.white, size: 19),
                                        SizedBox(width: 8),
                                        Text('Submit Attendance',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                fontSize: 15.5,
                                                letterSpacing: 0.2)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }

  Widget _statChip(StaffThemeProvider t, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: t.textMid, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _iconAction(
    StaffThemeProvider t, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
