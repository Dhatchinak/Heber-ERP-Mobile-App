import 'dart:async';
import 'dart:convert';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/screens/staff_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/utils/api_constants.dart';

class OTPLoginScreen extends StatefulWidget {
  const OTPLoginScreen({super.key});

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _staffNumberController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _otpSent = false;
  bool _showResendButton = false;
  int _resendTimer = 60;
  Timer? _timer;
  String _errorMessage = '';
  String _successMessage = '';
  String? _staffName;
  String? _emailAddress;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _departments = ['STE', 'ANT', 'ATE', 'STC'];
  String _selectedDepartment = 'STE';

  // ── BUG 1 FIX: All headers now use ApiConstants — no raw IP anywhere ──────
  Map<String, String> get _apiHeaders => ApiConstants.headers;
  Map<String, String> get _otpHeaders => ApiConstants.otpHeaders;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // ── BUG 2 FIX: Don't start timer on page open — start only after OTP sent ─
    // Removed: _startResendTimer() from initState

    // ── BUG 3 FIX: Backspace handling — move focus to previous box ────────────
    for (int i = 0; i < _otpControllers.length; i++) {
      _otpFocusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[i].text.isEmpty &&
            i > 0) {
          _otpFocusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _staffNumberController.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _showResendButton = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            _timer?.cancel();
            _showResendButton = true;
          }
        });
      }
    });
  }

  Future<void> _sendOTP() async {
    if (_staffNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your staff number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final staffId =
          'BHC-$_selectedDepartment-${_staffNumberController.text.trim().padLeft(5, '0')}';
      await _sendOTPToEmail(staffId);
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOTPToEmail(String staffId) async {
    // ── BUG 1 FIX cont.: Using ApiConstants URL, no raw IP in Referer ─────────
    final response = await http
        .get(
          Uri.parse('${ApiConstants.staffSendOtp}/$staffId'),
          headers: _apiHeaders,
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('SendOTP status: ${response.statusCode} body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _successMessage =
              data['message']?.toString() ?? 'OTP sent to your email';
        });
        _startResendTimer(); // ← timer starts HERE, after OTP actually sent
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      }
      return;
    }
    throw Exception('Failed to send OTP (${response.statusCode})');
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final staffId =
          'BHC-$_selectedDepartment-${_staffNumberController.text.trim().padLeft(5, '0')}';

      final response = await http
          .post(
            Uri.parse(ApiConstants.staffVerifyOtp),
            headers: _otpHeaders,
            body: json.encode({'staff_id': staffId, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          'VerifyOTP status: ${response.statusCode} body: ${response.body}');

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;

        // ── BUG 4 FIX: success check — handle both bool true and string "true" ──
        final isSuccess = body['success'] == true ||
            body['success']?.toString().toLowerCase() == 'true' ||
            body['status']?.toString().toLowerCase() == 'success';

        if (!isSuccess) {
          throw Exception(
              body['message']?.toString() ?? 'OTP verification failed.');
        }

        // ── BUG 5 FIX: extract token from response and pass to saveStaffSession ─
        final token =
            body['token']?.toString() ?? body['access_token']?.toString() ?? '';
        final refreshToken = body['refresh_token']?.toString() ?? '';
        final userData =
            (body['data'] ?? body['user'] ?? body) as Map<String, dynamic>;

        if (token.isEmpty) {
          throw Exception('Server did not return a token. Contact support.');
        }

        // Ensure staff_id is present
        if (userData['staff_id'] == null) userData['staff_id'] = staffId;

        if (!mounted) return;
        final authProvider = context.read<AuthProvider>();
        await authProvider.saveStaffSession(
          accessToken: token,
          refreshToken: refreshToken,
          userData: userData,
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboard()),
          (route) => false,
        );
      } else if (response.statusCode == 401) {
        throw Exception('Incorrect OTP. Please try again.');
      } else if (response.statusCode == 410) {
        throw Exception('OTP has expired. Please request a new one.');
      } else {
        throw Exception('Verification failed (${response.statusCode})');
      }
    } on http.ClientException catch (e) {
      debugPrint('OTPScreen._verifyOTP: network error — $e');
      if (mounted)
        setState(
            () => _errorMessage = 'Connection error. Check your internet.');
    } catch (e) {
      debugPrint('OTPScreen._verifyOTP: $e');
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _timer?.cancel();
    setState(() {
      _otpSent = false;
      for (var c in _otpControllers) c.clear();
      _errorMessage = '';
      _successMessage = '';
      _staffName = null;
      _emailAddress = null;
      _showResendButton = false;
      _resendTimer = 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: theme.cyan.withOpacity(0.3), blurRadius: 20)
                  ],
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'BISHOP HEBER COLLEGE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.textHigh,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Staff Authentication Portal',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Container(
                width: 60,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                ),
              ),
              const SizedBox(height: 48),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child:
                    _otpSent ? _buildOTPForm(theme) : _buildStaffIdForm(theme),
              ),
              const SizedBox(height: 32),
              // Error message
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.pink.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.pink.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: theme.pink, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_errorMessage,
                            style: TextStyle(color: theme.pink, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              // Success message
              if (_successMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.green.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: theme.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_successMessage,
                            style: TextStyle(color: theme.green, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 48),
              Text(
                '© 2026 Bishop Heber College. All rights reserved.',
                style: TextStyle(fontSize: 12, color: theme.textLow),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffIdForm(StaffThemeProvider theme) {
    return Column(
      children: [
        // Department dropdown
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              icon: Icon(Icons.expand_more_rounded, color: theme.cyan),
              isExpanded: true,
              style: TextStyle(
                  fontSize: 16,
                  color: theme.textHigh,
                  fontWeight: FontWeight.w600),
              dropdownColor: theme.surface,
              borderRadius: BorderRadius.circular(14),
              onChanged: (v) => setState(() => _selectedDepartment = v!),
              items: _departments
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Staff number input
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: TextFormField(
            controller: _staffNumberController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textHigh),
            decoration: InputDecoration(
              hintText: 'Enter 5-digit number',
              hintStyle: TextStyle(color: theme.textLow, fontSize: 16),
              counterText: '',
              border: InputBorder.none,
              prefix: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'BHC-$_selectedDepartment-',
                  style: TextStyle(
                      fontSize: 16,
                      color: theme.cyan,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Preview card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cyan.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.cyan, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Staff ID',
                        style: TextStyle(fontSize: 12, color: theme.textMid)),
                    Text(
                      'BHC-$_selectedDepartment-${_staffNumberController.text.trim().padLeft(5, '0')}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.cyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Send OTP button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 15)
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white))
                  : const Text('Send Verification Code',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPForm(StaffThemeProvider theme) {
    return Column(
      children: [
        // Email confirmation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.green.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code sent to:',
                  style: TextStyle(fontSize: 12, color: theme.textMid)),
              const SizedBox(height: 8),
              Text(
                _emailAddress ?? 'your registered email',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.green),
              ),
              const SizedBox(height: 12),
              Divider(color: theme.green.withOpacity(0.1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.badge_rounded, color: theme.green, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'BHC-$_selectedDepartment-${_staffNumberController.text.trim().padLeft(5, '0')}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textHigh),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _otpControllers[index].text.isNotEmpty
                    ? theme.cyan.withOpacity(0.1)
                    : theme.elevated,
                border: Border.all(
                  color: _otpControllers[index].text.isNotEmpty
                      ? theme.cyan
                      : theme.border,
                ),
              ),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textHigh),
                decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none),
                onChanged: (value) {
                  setState(() {}); // refresh box border color
                  if (value.isNotEmpty && index < 5) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) _otpFocusNodes[index + 1].requestFocus();
                    });
                  }
                  // Auto-verify when last digit entered
                  if (value.isNotEmpty && index == 5) {
                    final otp = _otpControllers.map((c) => c.text).join();
                    if (otp.length == 6) {
                      Future.delayed(
                          const Duration(milliseconds: 300), _verifyOTP);
                    }
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // Timer + resend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: theme.textMid),
            const SizedBox(width: 8),
            Text(
              _showResendButton
                  ? 'Code expired'
                  : 'Expires in 0:${_resendTimer.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 13, color: theme.textMid),
            ),
            const Spacer(),
            TextButton(
              onPressed: _showResendButton ? _sendOTP : null,
              style: TextButton.styleFrom(foregroundColor: theme.cyan),
              child: Text(
                'Resend Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _showResendButton ? theme.cyan : theme.textLow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Verify button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.green, theme.cyan]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: theme.green.withOpacity(0.3), blurRadius: 15)
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white))
                  : const Text('Verify & Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _resetForm,
          style: TextButton.styleFrom(foregroundColor: theme.textMid),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_rounded, size: 18, color: theme.textMid),
              const SizedBox(width: 8),
              const Text('Change Staff ID',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
