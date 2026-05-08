import 'dart:async';
import 'dart:convert';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

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

  static const List<String> _baseUrls = [
    'https://apierp.bhc.edu.in/api',
    'https://apierp.bhc.edu.in',
  ];

  static const Map<String, String> _headers = {
    'Referer': 'http://117.232.64.75',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

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
    _startResendTimer();

    for (int i = 0; i < _otpControllers.length; i++) {
      _otpControllers[i].addListener(() {
        if (_otpControllers[i].text.isNotEmpty && i < 5) {
          _otpFocusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _staffNumberController.dispose();
    for (var controller in _otpControllers) controller.dispose();
    for (var focusNode in _otpFocusNodes) focusNode.dispose();
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
    if (_staffNumberController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter staff number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final staffId = 'BHC-$_selectedDepartment-${_staffNumberController.text.padLeft(5, '0')}';
      await _verifyStaffId(staffId);
      await _sendOTPToEmail(staffId);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

 Future<void> _verifyStaffId(String staffId) async {
  // Try both patterns
  final endpoints = [
    'https://apierp.bhc.edu.in/api/staff/$staffId',
    'https://apierp.bhc.edu.in/staff/$staffId',
  ];
  
  final headers = {
    'Referer': 'https://stafferp.bhc.edu.in/',
    'Origin': 'https://stafferp.bhc.edu.in',
    'Accept': 'application/json',
  };
  
  for (final url in endpoints) {
    try {
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final staffData = data['data'] ?? data;
        if (mounted) {
          setState(() {
            _staffName = staffData['name'] ?? 'Staff Member';
            _emailAddress = staffData['college_email'] ?? staffData['email'] ?? 'your registered email';
          });
        }
        return;
      }
    } catch (_) {}
  }
  throw Exception('Staff ID not found in the system.');
}

Future<void> _sendOTPToEmail(String staffId) async {
  // Use GET instead of POST
  final url = 'https://apierp.bhc.edu.in/staff/login/$staffId';
  
  final headers = {
    'Referer': 'https://stafferp.bhc.edu.in/',
    'Origin': 'https://stafferp.bhc.edu.in',
    'Accept': 'application/json',
    
  };
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
    
    print('SEND OTP - STATUS: ${response.statusCode}');
    print('SEND OTP - BODY: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _successMessage = data['message'] ?? 'OTP sent successfully to your email';
        });
        _startResendTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
        });
      }
      return;
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  } catch (e) {
    print('SEND OTP ERROR: $e');
    throw Exception('Unable to send OTP. Please check your connection.');
  }
}

Future<void> _verifyOTP() async {
  final otp = _otpControllers.map((c) => c.text).join();
  if (otp.length != 6) {
    setState(() => _errorMessage = 'Please enter a 6-digit OTP');
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final staffId = 'BHC-$_selectedDepartment-${_staffNumberController.text.padLeft(5, '0')}';
    
    // For verification, use the /api endpoint with JSON body
    final url = 'https://apierp.bhc.edu.in/api/staff/login/otp';
    
    final headers = {
      'Referer': 'http://117.232.64.75',  // Keep original for /api endpoint
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode({'staff_id': staffId, 'otp': otp}),
    ).timeout(const Duration(seconds: 10));
    
    print('VERIFY OTP - STATUS: ${response.statusCode}');
    print('VERIFY OTP - BODY: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final userData = data['data'] ?? data['user'] ?? data;
        if (userData['staff_id'] == null) userData['staff_id'] = staffId;
        final authProvider = context.read<AuthProvider>();
        await authProvider.loginWithOTP(userData);
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/staff-dashboard', (route) => false);
        }
        return;
      } else {
        throw Exception(data['message'] ?? 'OTP verification failed.');
      }
    } else {
      throw Exception('Verification failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('VERIFY OTP ERROR: $e');
    setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
  } finally {
    setState(() => _isLoading = false);
  }
}


  void _resetForm() {
    setState(() {
      _otpSent = false;
      for (var controller in _otpControllers) controller.clear();
      _errorMessage = '';
      _successMessage = '';
      _staffName = null;
      _emailAddress = null;
    });
    _startResendTimer();
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
                  boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 20)],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
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
                style: TextStyle(fontSize: 14, color: theme.textMid, fontWeight: FontWeight.w600, letterSpacing: 1),
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
              // Form
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _otpSent ? _buildOTPForm(theme) : _buildStaffIdForm(theme),
              ),
              const SizedBox(height: 32),
              // Messages
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
                      Icon(Icons.error_outline_rounded, color: theme.pink, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_errorMessage, style: TextStyle(color: theme.pink, fontSize: 13))),
                    ],
                  ),
                ),
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
                      Icon(Icons.check_circle_rounded, color: theme.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_successMessage, style: TextStyle(color: theme.green, fontSize: 13))),
                    ],
                  ),
                ),
              const SizedBox(height: 48),
              // Footer
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
              style: TextStyle(fontSize: 16, color: theme.textHigh, fontWeight: FontWeight.w600),
              dropdownColor: theme.surface,
              borderRadius: BorderRadius.circular(14),
              onChanged: (newValue) => setState(() => _selectedDepartment = newValue!),
              items: _departments.map((value) {
                return DropdownMenuItem(value: value, child: Text(value));
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textHigh),
            decoration: InputDecoration(
              hintText: 'Enter 5-digit number',
              hintStyle: TextStyle(color: theme.textLow, fontSize: 16),
              counterText: '',
              border: InputBorder.none,
              prefix: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('BHC-$_selectedDepartment-',
                    style: TextStyle(fontSize: 16, color: theme.cyan, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
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
                    Text('Your Staff ID', style: TextStyle(fontSize: 12, color: theme.textMid)),
                    Text(
                      'BHC-$_selectedDepartment-${_staffNumberController.text.padLeft(5, '0')}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.cyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 15)],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('Send Verification Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPForm(StaffThemeProvider theme) {
    return Column(
      children: [
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
              Text('Code sent to:', style: TextStyle(fontSize: 12, color: theme.textMid)),
              const SizedBox(height: 8),
              Text(_emailAddress ?? 'your registered email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.green)),
              const SizedBox(height: 12),
              Divider(color: theme.green.withOpacity(0.1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.badge_rounded, color: theme.green, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'BHC-$_selectedDepartment-${_staffNumberController.text.padLeft(5, '0')}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: theme.textHigh),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _otpControllers[index].text.isNotEmpty ? theme.cyan.withOpacity(0.1) : theme.elevated,
                border: Border.all(color: _otpControllers[index].text.isNotEmpty ? theme.cyan : theme.border),
              ),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.textHigh),
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) _otpFocusNodes[index + 1].requestFocus();
                    });
                  }
                  if (value.isNotEmpty && index == 5) {
                    final otp = _otpControllers.map((c) => c.text).join();
                    if (otp.length == 6) {
                      Future.delayed(const Duration(milliseconds: 300), () => _verifyOTP());
                    }
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: theme.textMid),
            const SizedBox(width: 8),
            Text(
              'Code expires in 0:${_resendTimer.toString().padLeft(2, '0')}',
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
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.green, theme.cyan]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: theme.green.withOpacity(0.3), blurRadius: 15)],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
              Text('Change Staff ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}