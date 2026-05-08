// hall_booking_screen.dart — Redesigned to match Staff ERP design system
import 'dart:convert';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';



class HallBookingScreen extends StatefulWidget {
  const HallBookingScreen({super.key});

  @override
  State<HallBookingScreen> createState() => _HallBookingScreenState();
}

class _HallBookingScreenState extends State<HallBookingScreen>
    with TickerProviderStateMixin {
  // ── API ──────────────────────────────────────────────────────
  final String _base = "https://apierp.bhc.edu.in/api";
  final String _ref = "http://117.232.64.75";

  // ── STATE ────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _halls = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loadingHalls = true;
  bool _loadingDepts = true;
  String? _selectedHallId;
  String? _selectedDept;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isSubmitting = false;
  String? _staffId;
  String? _staffName;

  // Controllers
  final _eventCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _inchargeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _participantsCtrl = TextEditingController();
  final _mikesCtrl = TextEditingController();
  final _chairsCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  // ── Animations ───────────────────────────────────────────────
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

    final auth = context.read<AuthProvider>();
    _staffId = auth.userData?['staff_id']?.toString();
    _staffName = auth.userData?['name']?.toString();

    _fetchHalls();
    _fetchDepartments();

    _staggerCtrl.forward();
    _pageEnterCtrl.forward();
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
      7,
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
    for (final c in [
      _eventCtrl,
      _descCtrl,
      _inchargeCtrl,
      _emailCtrl,
      _contactCtrl,
      _participantsCtrl,
      _mikesCtrl,
      _chairsCtrl,
      _otherCtrl
    ]) {
      c.dispose();
    }
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

  // ── API CALLS ────────────────────────────────────────────────
// Update _fetchHalls to handle errors gracefully
Future<void> _fetchHalls() async {
  try {
    final res = await http.get(
      Uri.parse("https://apierp.bhc.edu.in/office/hall/data/"),
      headers: {'Referer': _ref, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final d = json.decode(res.body);
      if (d['success'] == true && mounted) {
        setState(() {
          _halls = List<Map<String, dynamic>>.from(d['data'] ?? []);
          _loadingHalls = false;
        });
      } else {
        setState(() {
          _halls = [];
          _loadingHalls = false;
        });
      }
    } else {
      setState(() {
        _halls = [];
        _loadingHalls = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _halls = [];
        _loadingHalls = false;
      });
      // Optionally show a snackbar error
      _snack('Failed to load halls. Please check your connection.', error: true);
    }
  }
}

  Future<void> _fetchDepartments() async {
    try {
      final res = await http.get(
        Uri.parse("$_base/admin/departments"),
        headers: {'Referer': _ref, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (d['departments'] is List) {
          setState(() {
            _departments = (d['departments'] as List)
                .map((e) => {
                      '_id': e['_id']?.toString() ?? '',
                      'department_code': e['department_code']?.toString() ?? '',
                      'department_name': e['department_name']?.toString() ?? '',
                    })
                .toList();
          });
        }
      }
    } catch (_) {}
    setState(() => _loadingDepts = false);
  }

  Future<void> _pickDate(bool isFrom) async {
    final theme = context.read<StaffThemeProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: theme.cyan),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final dt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    setState(() => isFrom ? _fromDate = dt : _toDate = dt);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      _snack('Please select both start and end time', error: true);
      return;
    }
    if (_selectedHallId == null) {
      _snack('Please select a hall', error: true);
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      _snack('End time must be after start time', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = {
        "bookingType": "Hall",
        "hall": _selectedHallId,
        "rooms": [],
        "from": _fromDate!.toUtc().toIso8601String(),
        "to": _toDate!.toUtc().toIso8601String(),
        "eventName": _eventCtrl.text.trim(),
        "description": _descCtrl.text.trim(),
        "incharge": _inchargeCtrl.text.trim(),
        "participants": int.tryParse(_participantsCtrl.text) ?? 0,
        "mikes": int.tryParse(_mikesCtrl.text) ?? 0,
        "chairs": int.tryParse(_chairsCtrl.text) ?? 0,
        "otherRequirements": _otherCtrl.text.trim(),
        "departmentName": _selectedDept ?? "",
        "hostelName": "",
        "email": _emailCtrl.text.trim(),
        "contactNumber": _contactCtrl.text.trim(),
        "staff_id": _staffId ?? "",
        "status": "Pending",
      };

      final res = await http.post(
        Uri.parse("$_base/office/hall/booking"),
        headers: {
          'Referer': _ref,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      final d = json.decode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && d['success'] == true) {
        _snack('Hall booked successfully!');
        _clearForm();
      } else {
        _snack(d['message'] ?? 'Booking failed', error: true);
      }
    } catch (e) {
      _snack('Connection error. Please try again.', error: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedHallId = null;
      _selectedDept = null;
      _fromDate = null;
      _toDate = null;
    });
    for (final c in [
      _eventCtrl,
      _descCtrl,
      _inchargeCtrl,
      _emailCtrl,
      _contactCtrl,
      _participantsCtrl,
      _mikesCtrl,
      _chairsCtrl,
      _otherCtrl
    ]) {
      c.clear();
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final theme = context.read<StaffThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: error ? theme.error : theme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _fmt(DateTime? dt) => dt == null
      ? 'Select date & time'
      : DateFormat('dd MMM yyyy • hh:mm a').format(dt);

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
                          child: Icon(Icons.meeting_room_rounded,
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
                          "Hall Booking",
                          style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Submit a booking request",
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
                      color: theme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Text(
                          "REQUEST",
                          style: TextStyle(
                            color: theme.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // IconButton(
                  //   icon: Icon(Icons.refresh_rounded,
                  //       color: theme.textMid, size: 20),
                  //   onPressed: () {
                  //     setState(() {
                  //       _loadingHalls = true;
                  //       _loadingDepts = true;
                  //     });
                  //     _fetchHalls();
                  //     _fetchDepartments();
                  //   },
                  // ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<StaffThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(
        isHod: _isHod,
        currentRoute: '/hall-booking',
      ),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  // Hero Banner
                  _animated(0, _buildHeroBanner(theme)),
                  const SizedBox(height: 20),

                  // Section 1: Hall Selection
                  _animated(1, _buildSectionHeader(
                    theme, '01', 'Select Hall', Icons.meeting_room_rounded, theme.cyan)),
                  const SizedBox(height: 10),
                  _animated(1, _buildHallDropdown(theme)),
                  const SizedBox(height: 22),

                  // Section 2: Date & Time
                  _animated(2, _buildSectionHeader(
                    theme, '02', 'Date & Time', Icons.calendar_month_rounded, theme.green)),
                  const SizedBox(height: 10),
                  _animated(2, _buildDateTimeCard(theme, isFrom: true)),
                  const SizedBox(height: 10),
                  _animated(2, _buildDateTimeCard(theme, isFrom: false)),
                  const SizedBox(height: 22),

                  // Section 3: Event Details
                  _animated(3, _buildSectionHeader(
                    theme, '03', 'Event Details', Icons.event_note_rounded, theme.amber)),
                  const SizedBox(height: 10),
                  _animated(3, _buildEventCard(theme)),
                  const SizedBox(height: 22),

                  // Section 4: Contact Details
                  _animated(4, _buildSectionHeader(
                    theme, '04', 'Contact Details', Icons.contact_phone_rounded, theme.violet)),
                  const SizedBox(height: 10),
                  _animated(4, _buildContactCard(theme)),
                  const SizedBox(height: 22),

                  // Section 5: Requirements
                  _animated(5, _buildSectionHeader(
                    theme, '05', 'Requirements', Icons.checklist_rounded, theme.pink)),
                  const SizedBox(height: 10),
                  _animated(5, _buildRequirementsCard(theme)),
                  const SizedBox(height: 22),

                  // Section 6: Department (Optional)
                  _animated(6, _buildSectionHeader(
                    theme, '06', 'Department (Optional)', Icons.business_rounded, theme.cyanDim)),
                  const SizedBox(height: 10),
                  _animated(6, _buildDeptDropdown(theme)),
                  const SizedBox(height: 32),

                  // Submit Button
                  _animated(6, _buildSubmitButton(theme)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HERO BANNER ─────────────────────────────────────────────────────────
  Widget _buildHeroBanner(StaffThemeProvider theme) {
    return Container(
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
            color: theme.cyan.withOpacity(0.08),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.cyan,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: theme.cyan.withOpacity(0.6), blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BOOKING REQUEST',
                      style: TextStyle(
                        color: theme.cyan.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Hall Booking',
                  style: TextStyle(
                    color: theme.textHigh,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _staffName ?? 'Staff Member',
                  style: TextStyle(
                    color: theme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _infoChip(
                  theme,
                  Icons.info_outline_rounded,
                  'Fill all required fields (*). Admin will review your request.',
                  theme.cyan,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.cyan.withOpacity(0.25)),
            ),
            child: Icon(
              Icons.meeting_room_rounded,
              color: theme.cyan,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

// Fix the info chip in _buildHeroBanner
Widget _infoChip(StaffThemeProvider theme, IconData icon, String label, Color color) {
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
        Flexible(  // ← Added Flexible to prevent overflow
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,  // ← Allow wrapping
          ),
        ),
      ],
    ),
  );
}



  // ─── SECTION HEADER ──────────────────────────────────────────────────────
  Widget _buildSectionHeader(
    StaffThemeProvider theme,
    String num,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textHigh,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ─── HALL DROPDOWN ───────────────────────────────────────────────────────
// Replace the _buildHallDropdown method with this:

// Replace the _buildHallDropdown method with this:

Widget _buildHallDropdown(StaffThemeProvider theme) {
  if (_loadingHalls) {
    return _buildSkeleton(theme);
  }

  return Container(
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.border),
      boxShadow: [
        BoxShadow(
          color: theme.cyan.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: DropdownButtonFormField<String>(
      value: _selectedHallId,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.textLow),
      dropdownColor: theme.surface,
      isDense: true,
      hint: Text(
        'Choose a hall',
        style: TextStyle(color: theme.textLow, fontSize: 13),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.location_city_rounded, color: theme.cyan, size: 20),
        filled: true,
        fillColor: theme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.error),
        ),
        errorStyle: TextStyle(fontSize: 11, color: theme.error),
      ),
      items: _halls.isEmpty
          ? [
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 18, color: theme.textLow),
                        const SizedBox(width: 8),
                        Text(
                          'No halls available',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textLow,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          : _halls.map((h) {
              return DropdownMenuItem<String>(
                value: h['_id'],
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_rounded, size: 14, color: theme.cyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h['name'] ?? 'Unknown Hall',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textHigh,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${h['capacity'] ?? 0} seats',
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.cyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      onChanged: _halls.isEmpty ? null : (v) => setState(() => _selectedHallId = v),
      validator: (v) => v == null ? 'Please select a hall' : null,
    ),
  );
}

// Similarly for department dropdown (though it's optional):

Widget _buildDeptDropdown(StaffThemeProvider theme) {
  if (_loadingDepts) {
    return _buildSkeleton(theme);
  }

  return Container(
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.border),
      boxShadow: [
        BoxShadow(
          color: theme.cyanDim.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: DropdownButtonFormField<String>(
      value: _selectedDept,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.textLow),
      dropdownColor: theme.surface,
      hint: Text(
        'Select department (optional)',
        style: TextStyle(color: theme.textLow, fontSize: 13),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.business_center_rounded, color: theme.cyanDim, size: 20),
        filled: true,
        fillColor: theme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.cyanDim, width: 1.5),
        ),
      ),
      items: _departments.isEmpty
          ? [
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 18, color: theme.textLow),
                        const SizedBox(width: 8),
                        Text(
                          'No departments available',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textLow,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          : _departments.map((d) {
              return DropdownMenuItem<String>(
                value: d['department_name'],
                child: Text(
                  d['department_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textHigh,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
      onChanged: _departments.isEmpty ? null : (v) => setState(() => _selectedDept = v),
    ),
  );
}


// Replace the _buildDeptDropdown method with this:

// Widget _buildDeptDropdown(StaffThemeProvider theme) {
//   if (_loadingDepts) {
//     return _buildSkeleton(theme);
//   }

//   // Check if departments list is empty (optional notice, not required field)
//   if (_departments.isEmpty) {
//     return _buildEmptyState(
//       theme,
//       icon: Icons.business_outlined,
//       title: 'No Departments',
//       message: 'Department list is currently unavailable. You can still submit without selecting one.',
//       actionLabel: 'Retry',
//       onAction: () {
//         setState(() {
//           _loadingDepts = true;
//         });
//         _fetchDepartments();
//       },
//       compact: true, // Make it smaller since this is optional
//     );
//   }

//   return Container(
//     decoration: BoxDecoration(
//       color: theme.surface,
//       borderRadius: BorderRadius.circular(14),
//       border: Border.all(color: theme.border),
//       boxShadow: [
//         BoxShadow(
//           color: theme.cyanDim.withOpacity(0.04),
//           blurRadius: 8,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: DropdownButtonFormField<String>(
//       value: _selectedDept,
//       isExpanded: true,
//       icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.textLow),
//       dropdownColor: theme.surface,
//       hint: Text(
//         'Select department (optional)',
//         style: TextStyle(color: theme.textLow, fontSize: 13),
//       ),
//       decoration: InputDecoration(
//         prefixIcon: Icon(Icons.business_center_rounded, color: theme.cyanDim, size: 20),
//         filled: true,
//         fillColor: theme.surface,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: BorderSide(color: theme.cyanDim, width: 1.5),
//         ),
//       ),
//       items: _departments.map((d) {
//         return DropdownMenuItem<String>(
//           value: d['department_name'],
//           child: Text(
//             d['department_name'] ?? 'Unknown',
//             style: TextStyle(
//               fontSize: 13,
//               color: theme.textHigh,
//               fontWeight: FontWeight.w500,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         );
//       }).toList(),
//       onChanged: (v) => setState(() => _selectedDept = v),
//     ),
//   );
// }



// Add this helper method for empty states:

Widget _buildEmptyState(
  StaffThemeProvider theme, {
  required IconData icon,
  required String title,
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  bool compact = false,
}) {
  if (compact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textMid,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: theme.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.border),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.amber.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 42, color: theme.amber),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.textMid,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.cyan, theme.violet],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.cyan.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // ─── DATE TIME CARD ──────────────────────────────────────────────────────
  Widget _buildDateTimeCard(StaffThemeProvider theme, {required bool isFrom}) {
    final dt = isFrom ? _fromDate : _toDate;
    final hasDate = dt != null;
    final label = isFrom ? 'Start Date & Time' : 'End Date & Time';
    final icon = isFrom ? Icons.play_arrow_rounded : Icons.stop_rounded;

    return GestureDetector(
      onTap: () => _pickDate(isFrom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasDate ? theme.cyan.withOpacity(0.04) : theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? theme.cyan.withOpacity(0.3) : theme.border,
            width: hasDate ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.cyan.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: hasDate ? theme.cyan.withOpacity(0.12) : theme.elevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: hasDate ? theme.cyan : theme.textLow,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasDate ? theme.cyan : theme.textLow,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmt(dt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasDate ? theme.textHigh : theme.textLow,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_calendar_rounded,
              color: hasDate ? theme.cyan : theme.textLow,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  // ─── EVENT CARD ──────────────────────────────────────────────────────────
  Widget _buildEventCard(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.amber.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          _buildField(
            theme,
            ctrl: _eventCtrl,
            label: 'Event Name',
            icon: Icons.celebration_rounded,
            required: true,
          ),
          _buildField(
            theme,
            ctrl: _descCtrl,
            label: 'Description',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          _buildField(
            theme,
            ctrl: _inchargeCtrl,
            label: 'Person In-charge',
            icon: Icons.badge_rounded,
            required: true,
            last: true,
          ),
        ],
      ),
    );
  }

  // ─── CONTACT CARD ────────────────────────────────────────────────────────
  Widget _buildContactCard(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.violet.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          _buildField(
            theme,
            ctrl: _emailCtrl,
            label: 'Email Address',
            icon: Icons.email_rounded,
            type: TextInputType.emailAddress,
            required: true,
          ),
          _buildField(
            theme,
            ctrl: _contactCtrl,
            label: 'Contact Number',
            icon: Icons.phone_rounded,
            type: TextInputType.phone,
            required: true,
            last: true,
          ),
        ],
      ),
    );
  }

  // ─── REQUIREMENTS CARD ───────────────────────────────────────────────────
  Widget _buildRequirementsCard(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.pink.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildField(
                  theme,
                  ctrl: _participantsCtrl,
                  label: 'Participants',
                  icon: Icons.people_rounded,
                  type: TextInputType.number,
                  required: true,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  theme,
                  ctrl: _mikesCtrl,
                  label: 'Mikes',
                  icon: Icons.mic_rounded,
                  type: TextInputType.number,
                  compact: true,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  theme,
                  ctrl: _chairsCtrl,
                  label: 'Chairs',
                  icon: Icons.chair_rounded,
                  type: TextInputType.number,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  theme,
                  ctrl: _otherCtrl,
                  label: 'Other Req.',
                  icon: Icons.more_horiz_rounded,
                  compact: true,
                  last: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── DEPARTMENT DROPDOWN ─────────────────────────────────────────────────
  // Widget _buildDeptDropdown(StaffThemeProvider theme) {
  //   if (_loadingDepts) {
  //     return _buildSkeleton(theme);
  //   }

  //   return Container(
  //     decoration: BoxDecoration(
  //       color: theme.surface,
  //       borderRadius: BorderRadius.circular(14),
  //       border: Border.all(color: theme.border),
  //       boxShadow: [
  //         BoxShadow(
  //           color: theme.cyanDim.withOpacity(0.04),
  //           blurRadius: 8,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: DropdownButtonFormField<String>(
  //       value: _selectedDept,
  //       isExpanded: true,
  //       icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.textLow),
  //       dropdownColor: theme.surface,
  //       hint: Text(
  //         'Select department (optional)',
  //         style: TextStyle(color: theme.textLow, fontSize: 13),
  //       ),
  //       decoration: InputDecoration(
  //         prefixIcon: Icon(Icons.business_center_rounded, color: theme.cyanDim, size: 20),
  //         filled: true,
  //         fillColor: theme.surface,
  //         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  //         border: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(14),
  //           borderSide: BorderSide.none,
  //         ),
  //         enabledBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(14),
  //           borderSide: BorderSide.none,
  //         ),
  //         focusedBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(14),
  //           borderSide: BorderSide(color: theme.cyanDim, width: 1.5),
  //         ),
  //       ),
  //       items: _departments.map((d) {
  //         return DropdownMenuItem<String>(
  //           value: d['department_name'],
  //           child: Text(
  //             d['department_name'] ?? 'Unknown',
  //             style: TextStyle(
  //               fontSize: 13,
  //               color: theme.textHigh,
  //               fontWeight: FontWeight.w500,
  //             ),
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         );
  //       }).toList(),
  //       onChanged: (v) => setState(() => _selectedDept = v),
  //     ),
  //   );
  // }




  // ─── FORM FIELD ──────────────────────────────────────────────────────────
  Widget _buildField(
    StaffThemeProvider theme, {
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType type = TextInputType.text,
    bool required = false,
    bool last = false,
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: last ? 12 : (compact ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textMid,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 3),
                Text(
                  '*',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: type,
            style: TextStyle(
              fontSize: 13,
              color: theme.textHigh,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(
                color: theme.textLow,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, size: 17, color: theme.cyan),
              filled: true,
              fillColor: theme.elevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.cyan, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.error, width: 1.5),
              ),
              errorStyle: TextStyle(fontSize: 11, color: theme.error),
            ),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
                : null,
          ),
        ],
      ),
    );
  }



  // ─── SUBMIT BUTTON ───────────────────────────────────────────────────────
  Widget _buildSubmitButton(StaffThemeProvider theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.cyan, theme.violet],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: theme.cyan.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSubmitting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Submitting…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Submit Booking Request',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(StaffThemeProvider theme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.cyan,
          ),
        ),
      ),
    );
  }
}