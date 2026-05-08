// leave_management_system.dart
import 'dart:typed_data';

import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Models (keep as is)
class LeaveApplication {
  // ... (keep your existing LeaveApplication class)
  final String id;
  final String rollNo;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String? document1;
  final String deptName;
  final String section;
  final String shift;
  final String cyear;
  final String currentApprover;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int durationDays;
  final Map<String, dynamic> approvals;
  final DateTime appliedDate;

  LeaveApplication({
    required this.id,
    required this.rollNo,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.document1,
    required this.deptName,
    required this.section,
    required this.shift,
    required this.cyear,
    required this.currentApprover,
    required this.createdAt,
    required this.updatedAt,
    required this.durationDays,
    required this.approvals,
    required this.appliedDate,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['_id'] ?? '',
      rollNo: json['roll_no'] ?? '',
      leaveType: json['leave_type'] ?? '',
      fromDate: DateTime.parse(json['from_date']),
      toDate: DateTime.parse(json['to_date']),
      reason: json['reason'] ?? '',
      document1: json['document1'],
      deptName: json['dept_name'] ?? '',
      section: json['section'] ?? '',
      shift: json['shift'] ?? '',
      cyear: json['cyear']?.toString() ?? '',
      currentApprover: json['current_approver'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toString()),
      durationDays: json['duration_days'] ?? 0,
      approvals: Map<String, dynamic>.from(json['approvals'] ?? {}),
      appliedDate: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roll_no': rollNo,
      'leave_type': leaveType.toLowerCase(),
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'reason': reason,
      'document1': document1,
      'dept_name': deptName,
      'section': section,
      'shift': shift,
      'cyear': cyear,
    };
  }
}

// Student Model
class Student {
  final String rollNo;
  final String name;
  final String deptName;
  final String section;
  final String shift;
  final String batch;
  final String? stream;

  Student({
    required this.rollNo,
    required this.name,
    required this.deptName,
    required this.section,
    required this.shift,
    required this.batch,
    this.stream,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      rollNo: json['roll_no']?.toString() ?? '',
      name: json['name'] ?? '',
      deptName: json['current_academic']?['degree_name'] ?? 'Computer Science',
      section: json['current_academic']?['section'] ?? 'A',
      shift: json['current_academic']?['shift'] ?? 'Shift-1',
      batch: json['batch'] ?? '2024-2026',
      stream: json['stream'],
    );
  }

  String get cyear {
    try {
      final batchYears = batch.split('-');
      if (batchYears.length == 2) {
        final startYear = int.tryParse(batchYears[0]) ?? DateTime.now().year;
        final currentYear = DateTime.now().year;
        final yearDifference = currentYear - startYear;
        final currentMonth = DateTime.now().month;
        final academicYear = yearDifference + (currentMonth >= 6 ? 1 : 0);
        return academicYear.clamp(1, 4).toString();
      }
    } catch (e) {
      print('Error calculating cyear: $e');
    }
    return '1';
  }
}

// API Service (keep as is)
class LeaveService {
  static const String baseUrl = 'http://117.232.64.75/api/students/leaves';
  static const String baseUrl1 = 'http://117.232.64.75/api';

  static final Map<String, String> headers = {
    'Referer': 'http://10.227.250.162',
    "Accept": "application/json",
    'Content-Type': 'application/json',
  };

  static Future<Student?> getStudentData(String rollNo) async {
    try {
      print('🎯 Fetching student data for roll no: $rollNo');
      final response = await http
          .get(Uri.parse('$baseUrl1/students/$rollNo'), headers: headers)
          .timeout(Duration(seconds: 30));
      print('📡 Student API Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final studentData = result['data'];
          return Student.fromJson(studentData);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error fetching student data: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> applyLeave(LeaveApplication application) async {
    final client = http.Client();
    try {
      final requestBody = application.toJson();
      final response = await client
          .post(
            Uri.parse('$baseUrl/apply'),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(Duration(seconds: 30));
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }
      final responseBody = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': responseBody['success'] == true,
          'message': responseBody['message'] ?? 'Leave application submitted successfully!',
          'data': responseBody,
        };
      } else {
        return {
          'success': false,
          'message': 'Server returned status: ${response.statusCode}. ${responseBody['message'] ?? 'Unknown error'}',
          'data': responseBody,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection - $e',
      };
    } finally {
      client.close();
    }
  }

  static Future<List<LeaveApplication>> getLeaveApplications(String rollNo) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/rollno/$rollNo'), headers: headers)
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final List<LeaveApplication> applications = [];
          for (var appData in result['data']) {
            try {
              applications.add(LeaveApplication.fromJson(appData));
            } catch (e) {
              print('❌ Error parsing application: $e');
            }
          }
          return applications;
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching applications: $e');
      return [];
    }
  }
}

// Main Leave Management Screen
class LeaveManagementScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const LeaveManagementScreen({
    Key? key,
    required this.rollNo,
    required this.studentName,
  }) : super(key: key);

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  int _selectedIndex = 0;
  Student? _studentData;
  bool _isLoadingStudent = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final student = await LeaveService.getStudentData(widget.rollNo);
      setState(() {
        _studentData = student;
        _isLoadingStudent = false;
      });
    } catch (e) {
      print('Error loading student data: $e');
      setState(() => _isLoadingStudent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: widget.rollNo,
        studentName: widget.studentName,
        currentRoute: '/leave',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.all(16),
            color: c.surface,
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(c, 0, "Apply Leave", Icons.edit_calendar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTab(c, 1, "My Applications", Icons.history),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: _selectedIndex == 0
                ? ApplyManualScreen(
                    rollNo: widget.rollNo,
                    studentName: widget.studentName,
                    studentData: _studentData,
                    isLoadingStudent: _isLoadingStudent,
                  )
                : MyApplicationsScreen(
                    rollNo: widget.rollNo,
                    studentName: widget.studentName,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(ThemeProvider c, int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? c.cyan : c.textMid;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? c.cyan.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? c.cyan : c.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FUTURISTIC APP BAR ─────────────────────────────────────────────────
  PreferredSizeWidget _buildFuturisticAppBar(ThemeProvider c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.pink.withOpacity(0.2), width: 1)),
              boxShadow: [BoxShadow(color: c.pink.withOpacity(0.06), blurRadius: 20)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: c.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(Icons.menu_rounded, color: c.textHigh, size: 18),
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  // Container(
                  //   padding: const EdgeInsets.all(8),
                  //   decoration: BoxDecoration(
                  //     color: c.pink.withOpacity(0.12),
                  //     borderRadius: BorderRadius.circular(10),
                  //   ),
                  //   child: Icon(Icons.leave_bags_at_home_rounded, color: c.pink, size: 18),
                  // ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Leave Management", style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text("Student Leave Portal", style: TextStyle(color: c.pink.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.pink.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.pink,
                          boxShadow: [BoxShadow(color: c.pink.withOpacity(0.6), blurRadius: 4)]),
                        ),
                        const SizedBox(width: 5),
                        Text("LEAVE", style: TextStyle(color: c.pink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20),
                    onPressed: () {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Apply Manual Screen (keep most of your existing code, just update the build method)
class ApplyManualScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;
  final Student? studentData;
  final bool isLoadingStudent;

  const ApplyManualScreen({
    Key? key,
    required this.rollNo,
    required this.studentName,
    this.studentData,
    this.isLoadingStudent = false,
  }) : super(key: key);

  @override
  State<ApplyManualScreen> createState() => _ApplyManualScreenState();
}

class _ApplyManualScreenState extends State<ApplyManualScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String _selectedLeaveType = 'casual';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _reason = '';
  bool _isLoading = false;
  File? _selectedDocument;
  bool _isUploading = false;

  String get _deptName => widget.studentData?.deptName ?? 'Computer Science';
  String get _section => widget.studentData?.section ?? 'A';
  String get _shift => widget.studentData?.shift ?? 'Shift-1';
  String get _cyear => widget.studentData?.cyear ?? '3';

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Please check all required fields', isError: true);
      return;
    }

    if (_fromDate == null || _toDate == null) {
      _showMessage('Please select both start and end dates', isError: true);
      return;
    }

    if (_fromDate!.isAfter(_toDate!)) {
      _showMessage('End date cannot be before start date', isError: true);
      return;
    }

    if (_fromDate!.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      _showMessage('Leave dates cannot be in the past', isError: true);
      return;
    }

    if ((_selectedLeaveType == 'medical' || _selectedLeaveType == 'od') && _selectedDocument == null) {
      _showMessage('Please upload supporting document', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? base64Document;
      if (_selectedDocument != null) {
        List<int> documentBytes = await _selectedDocument!.readAsBytes();
        if (documentBytes.length > 5 * 1024 * 1024) {
          _showMessage('Document size exceeds 5MB limit', isError: true);
          setState(() => _isLoading = false);
          return;
        }
        base64Document = base64Encode(documentBytes);
      }

      final application = LeaveApplication(
        id: '',
        rollNo: widget.rollNo,
        leaveType: _selectedLeaveType,
        fromDate: _fromDate!,
        toDate: _toDate!,
        reason: _reason,
        document1: base64Document,
        deptName: _deptName,
        section: _section,
        shift: _shift,
        cyear: _cyear,
        currentApprover: 'classTeacher',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        durationDays: _toDate!.difference(_fromDate!).inDays + 1,
        approvals: {},
        appliedDate: DateTime.now(),
      );

      final result = await LeaveService.applyLeave(application);
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _showMessage(result['message']!, isError: false);
        _resetForm();
      } else {
        _showMessage(result['message']!, isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Unexpected error: $e', isError: true);
    }
  }

  Future<void> _pickDocument() async {
    try {
      setState(() => _isUploading = true);
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 50,
      );
      if (file != null) {
        setState(() => _selectedDocument = File(file.path));
        _showMessage('Document selected successfully', isError: false);
      }
    } catch (e) {
      _showMessage('Failed to select document: $e', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _reason = '';
      _selectedLeaveType = 'casual';
      _selectedDocument = null;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFDC2626) : Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Information
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cyan.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.person, color: c.cyan, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.studentName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textHigh)),
                          Text('Roll No: ${widget.rollNo}', style: TextStyle(fontSize: 12, color: c.textMid)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: c.border),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  children: [
                    _infoChip(c, 'Department', _deptName),
                    _infoChip(c, 'Section', _section),
                    _infoChip(c, 'Shift', _shift),
                    _infoChip(c, 'Year', _cyear),
                  ],
                ),
              ],
            ),
          ),
          // Leave Type
          Text("Leave Type *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh)),
          const SizedBox(height: 12),
          ..._buildLeaveTypeOptions(c),
          const SizedBox(height: 24),
          // Date Range
          Text("Leave Period *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh)),
          const SizedBox(height: 12),
          _buildDateRangeSection(c),
          const SizedBox(height: 24),
          // Reason
          Text("Reason for Leave *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh)),
          const SizedBox(height: 12),
          _buildReasonField(c),
          if (_selectedLeaveType == 'medical' || _selectedLeaveType == 'od') ...[
            const SizedBox(height: 24),
            _buildDocumentUploadSection(c),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: c.border)),
                  child: Text('Clear Form', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(backgroundColor: c.cyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(ThemeProvider c, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: c.textLow, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, color: c.textHigh, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _buildLeaveTypeOptions(ThemeProvider c) {
    return [
      _leaveTypeOption(c, 'Casual Leave', 'For personal reasons', 'casual', Icons.beach_access, c.cyan),
      const SizedBox(height: 12),
      _leaveTypeOption(c, 'Medical Leave', 'Requires documentation', 'medical', Icons.local_hospital, c.pink),
      const SizedBox(height: 12),
      _leaveTypeOption(c, 'Official Duty', 'Requires documentation', 'od', Icons.work, c.violet),
    ];
  }

  Widget _leaveTypeOption(ThemeProvider c, String title, String desc, String value, IconData icon, Color color) {
    final isSelected = _selectedLeaveType == value;
    return InkWell(
      onTap: () => setState(() => _selectedLeaveType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: isSelected ? color : color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: isSelected ? Colors.white : color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textHigh)),
                  Text(desc, style: TextStyle(fontSize: 12, color: c.textMid)),
                ],
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : c.textLow.withOpacity(0.3), width: 2),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _dateField(c, "From", true)),
              const SizedBox(width: 16),
              Expanded(child: _dateField(c, "To", false)),
            ],
          ),
          if (_fromDate != null && _toDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.cyan.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Days:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textMid)),
                  Text('${_toDate!.difference(_fromDate!).inDays + 1} days', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.cyan)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField(ThemeProvider c, String label, bool isFrom) {
    final selectedDate = isFrom ? _fromDate : _toDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMid)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
              builder: (context, child) => Theme(
                data: c.isDarkMode ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(primary: c.cyan, onPrimary: Colors.white, surface: c.surface),
                ) : ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: c.cyan)),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                if (isFrom) {
                  _fromDate = picked;
                  if (_toDate != null && _toDate!.isBefore(picked)) _toDate = null;
                } else {
                  _toDate = picked;
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8), color: c.surface),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: c.textMid),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null
                      ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
                      : 'Select date',
                  style: TextStyle(color: selectedDate != null ? c.textHigh : c.textLow, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField(ThemeProvider c) {
    return TextFormField(
      maxLines: 4,
      decoration: InputDecoration(
        hintText: "Provide a detailed reason...",
        hintStyle: TextStyle(color: c.textLow),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.cyan)),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: TextStyle(fontSize: 14, color: c.textHigh),
      validator: (value) => value == null || value.isEmpty ? 'Please provide a reason' : null,
      onChanged: (value) => setState(() => _reason = value),
    );
  }

  Widget _buildDocumentUploadSection(ThemeProvider c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Supporting Document *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12), color: c.bg),
          child: Column(
            children: [
              Icon(Icons.upload_file, size: 48, color: c.cyan),
              const SizedBox(height: 12),
              Text('Upload Supporting Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textHigh)),
              const SizedBox(height: 8),
              Text('Required for ${_selectedLeaveType == 'medical' ? 'Medical Leave' : 'Official Duty'}', style: TextStyle(fontSize: 12, color: c.textMid)),
              const SizedBox(height: 16),
              if (_selectedDocument != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.cyan.withOpacity(0.3))),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: c.cyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_selectedDocument!.path.split('/').last, style: TextStyle(color: c.textHigh, fontSize: 14))),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selectedDocument = null), color: c.textLow),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.surface,
                  foregroundColor: c.cyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c.cyan)),
                ),
                icon: _isUploading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.cyan)) : const Icon(Icons.upload, size: 18),
                label: Text(_isUploading ? 'Uploading...' : 'Choose File'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// MyApplicationsScreen (keep your existing code, just update the build method to remove its own app bar)
class MyApplicationsScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const MyApplicationsScreen({
    Key? key,
    required this.rollNo,
    required this.studentName,
  }) : super(key: key);

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<LeaveApplication> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Pending', 'Approved', 'Rejected', 'Medical', 'Casual', 'OD'];

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final applications = await LeaveService.getLeaveApplications(widget.rollNo);
      setState(() => _applications = applications);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load applications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getStatusText(Map<String, dynamic> approvals) {
    if (approvals['classTeacher']?['status'] == 'approved' &&
        approvals['deptHod']?['status'] == 'approved' &&
        approvals['vp']?['status'] == 'approved' &&
        approvals['clubCoordinator']?['status'] == 'approved') {
      return 'Approved';
    } else if (approvals['classTeacher']?['status'] == 'rejected' ||
        approvals['deptHod']?['status'] == 'rejected' ||
        approvals['vp']?['status'] == 'rejected' ||
        approvals['clubCoordinator']?['status'] == 'rejected') {
      return 'Rejected';
    }
    return 'Pending';
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final total = _applications.length;
    final pending = _applications.where((app) => _getStatusText(app.approvals) == 'Pending').length;
    final approved = _applications.where((app) => _getStatusText(app.approvals) == 'Approved').length;
    final rejected = _applications.where((app) => _getStatusText(app.approvals) == 'Rejected').length;

    return Column(
      children: [
        // Stats Header
        Container(
          padding: const EdgeInsets.all(16),
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leave Applications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textHigh)),
              const SizedBox(height: 8),
              Text('Review your leave application history', style: TextStyle(color: c.textMid)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(c, 'Total', total, c.violet),
                    _statItem(c, 'Pending', pending, Colors.orange),
                    _statItem(c, 'Approved', approved, c.cyan),
                    _statItem(c, 'Rejected', rejected, c.pink),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Search & Filter
        Container(
          padding: const EdgeInsets.all(16),
          color: c.surface,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
                child: Row(
                  children: [
                    Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.search, color: c.textLow)),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: c.textHigh),
                        decoration: InputDecoration(hintText: 'Search...', border: InputBorder.none, hintStyle: TextStyle(color: c.textLow)),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: c.cyan,
                        backgroundColor: c.bg,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : c.textMid, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: c.cyan))
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: TextStyle(color: c.textMid)))
                  : _applications.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.inbox_outlined, size: 64, color: c.textLow),
                          const SizedBox(height: 16),
                          Text('No applications found', style: TextStyle(color: c.textMid)),
                        ]))
                      : ListView.builder(
                          itemCount: _applications.length,
                          itemBuilder: (context, index) {
                            final app = _applications[index];
                            final status = _getStatusText(app.approvals);
                            final statusColor = status == 'Approved' ? c.green : status == 'Rejected' ? c.pink : Colors.orange;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.05),
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: app.leaveType == 'medical' ? c.pink : app.leaveType == 'od' ? c.violet : c.cyan, borderRadius: BorderRadius.circular(8)),
                                          child: Text(app.leaveType.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor)),
                                          child: Row(
                                            children: [
                                              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              Text(status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(app.reason, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh), maxLines: 2),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: c.textLow),
                                            const SizedBox(width: 4),
                                            Text('${_formatDate(app.fromDate)} - ${_formatDate(app.toDate)}', style: TextStyle(fontSize: 12, color: c.textMid)),
                                            const SizedBox(width: 12),
                                            Icon(Icons.schedule, size: 14, color: c.textLow),
                                            const SizedBox(width: 4),
                                            Text('${app.durationDays} days', style: TextStyle(fontSize: 12, color: c.textMid)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _statItem(ThemeProvider c, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c.textMid)),
      ],
    );
  }
}