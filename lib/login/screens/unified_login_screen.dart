import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_constants.dart';
import '../../Staff/screens/staff_dashboard.dart';
import '../../Student/screens/main_page.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 40),

            // ── Logo ──────────────────────────────────────────────────────
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.elevated,
                border: Border.all(color: theme.cyan.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: theme.cyan.withOpacity(0.15), blurRadius: 24)
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/bhclogo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.school_rounded, size: 44, color: theme.cyan),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Bishop Heber College',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.textHigh,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: theme.primaryGradient),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'UNIFIED ERP PORTAL',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 36),

            // ── Tab Bar ───────────────────────────────────────────────────
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.border),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: theme.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: theme.cyan.withOpacity(0.3), blurRadius: 8)
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: theme.textMid,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '👨‍🏫  Staff'),
                  Tab(text: '🎓  Student'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Tab Views ─────────────────────────────────────────────────
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StaffLoginTab(theme: theme),
                  _StudentLoginTab(theme: theme),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              '© 2025 Bishop Heber College ERP',
              style: TextStyle(fontSize: 11, color: theme.textLow),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF TAB — Staff ID → Send OTP → Verify OTP → Dashboard
// ══════════════════════════════════════════════════════════════════════════════

class _StaffLoginTab extends StatefulWidget {
  final AppThemeProvider theme;
  const _StaffLoginTab({required this.theme});

  @override
  State<_StaffLoginTab> createState() => _StaffLoginTabState();
}

class _StaffLoginTabState extends State<_StaffLoginTab> {
  // Staff ID is built as BHC-{dept}-{5digits}, matching working OTPLoginScreen
  final _numCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  static const List<String> _depts = ['STE', 'ANT', 'ATE', 'STC'];
  String _dept = 'STE';
  String? _maskedEmail;

  bool _otpSent = false;
  bool _loading = false;
  bool _canResend = false;
  int _countdown = 60;
  Timer? _timer;

  // Correct headers — matching working OTPLoginScreen
  static const Map<String, String> _h = {
    'Referer': 'https://stafferp.bhc.edu.in/',
    'Origin': 'https://stafferp.bhc.edu.in',
    'Accept': 'application/json',
  };
  static const Map<String, String> _hJson = {
    'Referer': 'http://117.232.64.75',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  String get _staffId =>
      'BHC-$_dept-${_numCtrl.text.trim().padLeft(5, '0')}';

  @override
  void dispose() {
    _numCtrl.dispose();
    for (var c in _otpCtrl) c.dispose();
    for (var f in _otpFocus) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdown--;
        if (_countdown <= 0) { t.cancel(); _canResend = true; }
      });
    });
  }

  Future<void> _sendOtp() async {
    final num = _numCtrl.text.trim();
    if (num.isEmpty || num.length > 5) {
      _err('Enter your 5-digit staff number');
      return;
    }
    setState(() => _loading = true);
    try {
      // Step 1: verify staff exists (GET /api/staff/{staffId})
      final checkRes = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/staff/$_staffId'),
        headers: _h,
      ).timeout(const Duration(seconds: 10));

      if (checkRes.statusCode != 200) {
        _err('Staff ID not found. Please check and try again.');
        return;
      }

      final staffData = json.decode(checkRes.body);
      final d = staffData['data'] ?? staffData;
      final email = d['college_email']?.toString() ?? d['email']?.toString() ?? '';
      _maskedEmail = email.isNotEmpty ? _mask(email) : 'your registered email';

      // Step 2: send OTP (GET /staff/login/{staffId}) — matches working app
      final otpRes = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/staff/login/$_staffId'),
        headers: _h,
      ).timeout(const Duration(seconds: 15));

      if (otpRes.statusCode == 200) {
        setState(() => _otpSent = true);
        _startCountdown();
        _showInfo('OTP sent to ${_maskedEmail ?? "your email"}');
      } else {
        _err('Failed to send OTP (${otpRes.statusCode}). Try again.');
      }
    } catch (_) {
      _err('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.map((c) => c.text).join();
    if (otp.length != 6) { _err('Enter the 6-digit OTP'); return; }
    setState(() => _loading = true);

    try {
      // POST /api/staff/login/otp with {staff_id, otp} — matches working app
      final verRes = await http.post(
        Uri.parse('https://apierp.bhc.edu.in/api/staff/login/otp'),
        headers: _hJson,
        body: json.encode({'staff_id': _staffId, 'otp': otp}),
      ).timeout(const Duration(seconds: 15));

      if (verRes.statusCode == 200) {
        final d = json.decode(verRes.body);
        if (d['success'] == true) {
          final userData = (d['data'] ?? d['user'] ?? d) as Map<String, dynamic>;
          userData['staff_id'] ??= _staffId;

          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.loginWithOTP(userData);

          if (!mounted) return;
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const StaffDashboard()));
          return;
        }
        _err(d['message']?.toString() ?? 'Invalid OTP. Please try again.');
      } else {
        _err('Verification failed (${verRes.statusCode}). Try again.');
      }
    } catch (_) {
      _err('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mask(String email) {
    final parts = email.split('@');
    if (parts.length < 2) return email;
    final local = parts[0];
    return '${local.length > 3 ? local.substring(0, 3) : local}***@${parts[1]}';
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: widget.theme.isDarkMode
            ? const Color(0xFF111428)
            : Colors.blueGrey.shade700));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _otpSent ? _buildOtpStep(t) : _buildIdStep(t),
    );
  }

  Widget _buildIdStep(AppThemeProvider t) {
    return Column(key: const ValueKey('id'), children: [
      // Info card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cyan.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.cyan.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.badge_rounded, color: t.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select department and enter your 5-digit staff number.',
              style: TextStyle(color: t.textMid, fontSize: 12),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Department dropdown
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _dept,
            isExpanded: true,
            icon: Icon(Icons.expand_more_rounded, color: t.cyan),
            style: TextStyle(fontSize: 14, color: t.textHigh, fontWeight: FontWeight.w600),
            dropdownColor: t.elevated,
            borderRadius: BorderRadius.circular(14),
            onChanged: (v) => setState(() => _dept = v!),
            items: _depts.map((d) =>
              DropdownMenuItem(value: d, child: Text(d))
            ).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Number field with prefix
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          Text('BHC-$_dept-',
              style: TextStyle(color: t.cyan, fontSize: 14, fontWeight: FontWeight.w700)),
          Expanded(
            child: TextField(
              controller: _numCtrl,
              keyboardType: TextInputType.number,
              maxLength: 5,
              style: TextStyle(color: t.textHigh, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '00000',
                hintStyle: TextStyle(color: t.textLow),
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),

      // Preview
      Align(
        alignment: Alignment.centerLeft,
        child: Text('Staff ID: $_staffId',
            style: TextStyle(color: t.textMid, fontSize: 11)),
      ),
      const SizedBox(height: 20),

      _btn(label: 'Send OTP', loading: _loading, theme: t, onTap: _sendOtp),
    ]);
  }

  Widget _buildOtpStep(AppThemeProvider t) {
    return Column(key: const ValueKey('otp'), children: [
      // Back
      Row(children: [
        GestureDetector(
          onTap: () => setState(() { _otpSent = false; _timer?.cancel(); }),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.arrow_back_rounded, color: t.textHigh, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'OTP sent to ${_maskedEmail ?? "your registered email"}',
            style: TextStyle(color: t.textMid, fontSize: 12),
          ),
        ),
      ]),
      const SizedBox(height: 20),

      Text('Enter 6-digit OTP',
          style: TextStyle(color: t.textHigh, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),

      // OTP boxes
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => SizedBox(
          width: 46,
          child: TextField(
            controller: _otpCtrl[i],
            focusNode: _otpFocus[i],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.textHigh),
            keyboardType: TextInputType.number,
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.cyan, width: 2)),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                FocusScope.of(context).requestFocus(_otpFocus[i + 1]);
              } else if (v.isEmpty && i > 0) {
                FocusScope.of(context).requestFocus(_otpFocus[i - 1]);
              }
              if (i == 5 && v.isNotEmpty) _verifyOtp();
            },
          ),
        )),
      ),
      const SizedBox(height: 20),

      _btn(label: 'Verify & Login', loading: _loading, theme: t, onTap: _verifyOtp),
      const SizedBox(height: 12),

      Center(
        child: TextButton(
          onPressed: _canResend ? _sendOtp : null,
          child: Text(
            _canResend ? 'Resend OTP' : 'Resend in ${_countdown}s',
            style: TextStyle(
                color: _canResend ? t.cyan : t.textLow,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STUDENT TAB — Roll No → DOB picker → Student Dashboard
// ══════════════════════════════════════════════════════════════════════════════

class _StudentLoginTab extends StatefulWidget {
  final AppThemeProvider theme;
  const _StudentLoginTab({required this.theme});

  @override
  State<_StudentLoginTab> createState() => _StudentLoginTabState();
}

class _StudentLoginTabState extends State<_StudentLoginTab> {
  final _rollCtrl = TextEditingController();
  DateTime? _dob;
  bool _loading = false;

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final roll = _rollCtrl.text.trim().toUpperCase();
    if (roll.isEmpty) { _err('Please enter your Roll Number'); return; }
    if (_dob == null) { _err('Please select your Date of Birth'); return; }

    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.studentBase}/$roll'),
        headers: ApiConstants.headers,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final studentData = data['data'] ?? data;

        String serverDob = studentData['personal_info']?['dob']?.toString() ??
            studentData['dob']?.toString() ?? '';
        if (serverDob.contains('T')) serverDob = serverDob.split('T')[0];

        final enteredDob =
            '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';

        if (serverDob == enteredDob) {
          final name = studentData['name']?.toString() ?? 'Student';
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.saveStudentSession(
              rollNo: roll, name: name, dob: enteredDob);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MainPage(rollNo: roll, studentName: name),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
            ),
          );
        } else {
          _err('Date of Birth does not match our records.');
        }
      } else {
        _err('Roll Number not found. Please check and try again.');
      }
    } catch (_) {
      _err('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(children: [
      // Info card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.violet.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.violet.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.school_rounded, color: t.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enter your Roll Number and Date of Birth to login.',
              style: TextStyle(color: t.textMid, fontSize: 12),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Roll No field
      _field(
        controller: _rollCtrl,
        hint: 'Roll Number (e.g. 22MCS001)',
        icon: Icons.badge_rounded,
        theme: t,
        inputFormatters: [UpperCaseTextFormatter()],
      ),
      const SizedBox(height: 14),

      // DOB picker
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1980),
            lastDate: DateTime.now(),
            builder: (ctx, child) =>
                Theme(data: t.themeData, child: child!),
          );
          if (picked != null) setState(() => _dob = picked);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _dob != null ? t.cyan.withOpacity(0.5) : t.border),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded,
                color: _dob != null ? t.cyan : t.textLow, size: 20),
            const SizedBox(width: 12),
            Text(
              _dob != null
                  ? '${_dob!.day.toString().padLeft(2, '0')} / '
                    '${_dob!.month.toString().padLeft(2, '0')} / '
                    '${_dob!.year}'
                  : 'Date of Birth',
              style: TextStyle(
                  color: _dob != null ? t.textHigh : t.textLow,
                  fontSize: 14,
                  fontWeight:
                      _dob != null ? FontWeight.w600 : FontWeight.normal),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: t.textLow, size: 18),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      _btn(label: 'Login', loading: _loading, theme: t, onTap: _verify),
    ]);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

Widget _field({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required AppThemeProvider theme,
  List<TextInputFormatter>? inputFormatters,
  TextInputType? keyboardType,
}) {
  return Container(
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.border),
    ),
    child: TextField(
      controller: controller,
      style: TextStyle(color: theme.textHigh, fontSize: 14),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textLow, fontSize: 13),
        prefixIcon: Icon(icon, color: theme.cyan, size: 20),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}

Widget _btn({
  required String label,
  required bool loading,
  required AppThemeProvider theme,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.primaryGradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: theme.cyan.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
      ),
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    return newVal.copyWith(text: newVal.text.toUpperCase());
  }
}