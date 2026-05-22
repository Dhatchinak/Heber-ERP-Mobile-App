import 'package:bhc_erp/Student/screens/main_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_constants.dart';

class StudentDobScreen extends StatefulWidget {
  final String email;
  const StudentDobScreen({super.key, required this.email});

  @override
  State<StudentDobScreen> createState() => _StudentDobScreenState();
}

class _StudentDobScreenState extends State<StudentDobScreen> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _rollNo;

  @override
  void initState() {
    super.initState();
    _rollNo = _extractRollNo(widget.email);
  }

  String? _extractRollNo(String email) {
    final localPart = email.split('@').first;
    if (localPart.contains(RegExp(r'^\d{2}[A-Z]{3}\d{3}$'))) {
      return localPart.toUpperCase();
    }
    return null;
  }

  Future<void> _verifyAndLogin() async {
    if (_rollNo == null || _selectedDate == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedDob =
          '${_selectedDate!.year}-'
          '${_selectedDate!.month.toString().padLeft(2, '0')}-'
          '${_selectedDate!.day.toString().padLeft(2, '0')}';

      // ── Server-side DOB verification ───────────────────────────────────
      // POST roll_no + dob to the server; the server compares and returns
      // the student record only if DOB matches — no client-side comparison.
      final response = await http
          .post(
            Uri.parse(ApiConstants.studentVerifyDob),
            headers: ApiConstants.headers,
            body: json.encode({'roll_no': _rollNo, 'dob': formattedDob}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data        = json.decode(response.body) as Map<String, dynamic>;
        final studentData = (data['data'] ?? data) as Map<String, dynamic>?;

        if (studentData != null) {
          final studentName = studentData['name']?.toString() ?? 'Student';

          if (!mounted) return;
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.saveStudentSession(
            rollNo: _rollNo!,
            name:   studentName,
            dob:    formattedDob,
          );

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainPage(
                rollNo:       _rollNo!,
                studentName:  studentName,
              ),
            ),
          );
        } else {
          _showError('Student not found');
        }
      } else if (response.statusCode == 401) {
        _showError('Date of Birth does not match our records');
      } else if (response.statusCode == 404) {
        _showError('Student not found');
      } else {
        _showError('Verification failed. Please try again.');
      }
    } on http.ClientException catch (e) {
      debugPrint('StudentDobScreen: network error — $e');
      _showError('Connection error. Please check your internet.');
    } catch (e) {
      debugPrint('StudentDobScreen: unexpected error — $e');
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textHigh),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Student Verification',
          style: TextStyle(color: theme.textHigh, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Roll number display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.badge_rounded, color: theme.cyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Roll Number',
                              style: TextStyle(color: theme.textLow, fontSize: 11)),
                          Text(
                            _rollNo ?? 'Not detected',
                            style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Verify with Date of Birth',
                style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    builder: (context, child) =>
                        Theme(data: theme.themeData, child: child!),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: theme.cyan),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select Date of Birth',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? theme.textHigh
                              : theme.textLow,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.cyan,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify & Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
