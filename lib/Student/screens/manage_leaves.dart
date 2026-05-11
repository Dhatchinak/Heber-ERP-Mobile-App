// leave_management_system.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

// ─── MODELS ──────────────────────────────────────────────────────────────────

class LeaveApplication {
  final String id;
  final String rollNo;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String? supportingDocument;
  final int durationDays;
  final List<dynamic> approvals; // ← List not Map
  final DateTime appliedDate;

  LeaveApplication({
    required this.id,
    required this.rollNo,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.supportingDocument,
    required this.durationDays,
    required this.approvals,
    required this.appliedDate,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    final start = json['startDate'] ?? json['from_date'];
    final end = json['endDate'] ?? json['to_date'];
    final created = json['appliedAt'] ?? json['createdAt'];
    return LeaveApplication(
      id: json['_id'] ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      leaveType: json['leaveType'] ?? json['leave_type'] ?? '',
      fromDate: DateTime.tryParse(start ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(end ?? '') ?? DateTime.now(),
      reason: json['reason'] ?? '',
      supportingDocument: json['supportingDocument'] is String
          ? json['supportingDocument'] : null,
      durationDays: json['durationDays'] ?? 0,
      approvals: json['approvals'] is List ? json['approvals'] : [],
      appliedDate: DateTime.tryParse(created ?? '') ?? DateTime.now(),
    );
  }
}

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
      debugPrint('Error calculating cyear: $e');
    }
    return '1';
  }
}

// ─── LEAVE TYPES ─────────────────────────────────────────────────────────────

class LeaveTypeConfig {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool requiresDocument;
  final List<String> signatures;
  final Color Function(ThemeProvider) colorFn;

  const LeaveTypeConfig({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.requiresDocument,
    required this.signatures,
    required this.colorFn,
  });
}

final leaveTypes = [
  LeaveTypeConfig(
    value: 'casual',
    label: 'Casual Leave',
    description: 'Personal reasons',
    icon: Icons.beach_access_rounded,
    requiresDocument: false,
    signatures: ['Class Incharge', 'HOD'],
    colorFn: (c) => c.cyan,
  ),
  LeaveTypeConfig(
    value: 'medical',
    label: 'Medical Leave',
    description: 'Requires documentation',
    icon: Icons.local_hospital_rounded,
    requiresDocument: true,
    signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
    colorFn: (c) => c.pink,
  ),
  LeaveTypeConfig(
    value: 'on_duty',
    label: 'On Duty',
    description: 'Requires documentation',
    icon: Icons.work_rounded,
    requiresDocument: true,
    signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
    colorFn: (c) => c.violet,
  ),
  LeaveTypeConfig(
    value: 'emergency',
    label: 'Emergency Leave',
    description: 'Document if available',
    icon: Icons.warning_rounded,
    requiresDocument: false,
    signatures: ['Class Incharge', 'HOD'],
    colorFn: (c) => c.amber,
  ),
];

LeaveTypeConfig? getLeaveConfig(String value) =>
    leaveTypes.firstWhere((t) => t.value == value, orElse: () => leaveTypes[0]);

// ─── API SERVICE ──────────────────────────────────────────────────────────────

class LeaveService {
  static const String baseUrl = 'https://apierp.bhc.edu.in/api/students/leave';
  static const String studentUrl = 'https://apierp.bhc.edu.in/api/students';

  static final Map<String, String> _headers = {
    'Referer': 'http://117.232.64.75',
    'Accept': 'application/json',
  };

  static Future<Student?> getStudentData(String rollNo) async {
    try {
      final response = await http
          .get(Uri.parse('$studentUrl/$rollNo'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['data'] != null) {
          return Student.fromJson(result['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching student: $e');
      return null;
    }
  }

  /// Submits leave as multipart/form-data so document file is uploaded properly.
static Future<Map<String, dynamic>> applyLeave({
  required String rollNo,
  required String leaveType,
  required DateTime startDate,
  required DateTime endDate,
  required String reason,
  File? documentFile,
}) async {
  try {
    final uri = Uri.parse('$baseUrl/apply');
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    final rollNoInt = int.tryParse(rollNo) ?? rollNo;

    // ── No file → plain JSON (confirmed working) ──────────────────────
    if (documentFile == null) {
      final response = await http.post(
        uri,
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'roll_no': rollNoInt,
          'leaveType': leaveType,
          'startDate': startStr,
          'endDate': endStr,
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📡 ${response.statusCode} | ${response.body}');
      return _parseResponse(response.statusCode, response.body);
    }

    // ── Has file → multipart ───────────────────────────────────────────
    final request = http.MultipartRequest('POST', uri);
    request.headers['Referer'] = 'http://117.232.64.75';
    request.headers['Accept'] = 'application/json';

    // roll_no as integer string (no quotes in form field isn't possible,
    // but backend should parseInt — send clean digits only)
    request.fields['roll_no'] = rollNo;
    request.fields['leaveType'] = leaveType;
    request.fields['startDate'] = startStr;
    request.fields['endDate'] = endStr;
    request.fields['reason'] = reason;

    final ext = p.extension(documentFile.path).toLowerCase().replaceFirst('.', '');
    request.files.add(await http.MultipartFile.fromPath(
      'supportingDocument',
      documentFile.path,
      contentType: MediaType.parse(_mimeType(ext)),
    ));

    debugPrint('🚀 Multipart POST | fields: ${request.fields} | file: ${documentFile.path}');

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    debugPrint('📡 ${streamed.statusCode} | $body');

    return _parseResponse(streamed.statusCode, body);

  } on TimeoutException {
    return {'success': false, 'message': 'Request timed out'};
  } on SocketException {
    return {'success': false, 'message': 'No internet connection'};
  } catch (e) {
    debugPrint('❌ $e');
    return {'success': false, 'message': 'Error: $e'};
  }
}
  // static String _mimeType(String ext) {
  //   switch (ext) {
  //     case 'pdf': return 'application/pdf';
  //     case 'png': return 'image/png';
  //     case 'jpg': case 'jpeg': return 'image/jpeg';
  //     case 'doc': return 'application/msword';
  //     case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  //     default: return 'application/octet-stream';
  //   }
  // }

static Future<List<LeaveApplication>> getLeaveApplications(String rollNo) async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/$rollNo'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    debugPrint('📡 GET leaves ${response.statusCode} | ${response.body}');
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      List<dynamic> list = [];
      if (result is List) {
        list = result;
      } else if (result['leaves'] is List) {
        list = result['leaves'];
      } else if (result['data'] is List) {
        list = result['data'];
      }
      return list.map((e) {
        try { return LeaveApplication.fromJson(e); }
        catch (err) { debugPrint('Parse error: $err | $e'); return null; }
      }).whereType<LeaveApplication>().toList();
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching applications: $e');
    return [];
  }
}
  
static Map<String, dynamic> _parseResponse(int statusCode, String body) {
  if (body.isEmpty) return {'success': false, 'message': 'Empty response'};
  try {
    final decoded = json.decode(body);
    if (statusCode == 200 || statusCode == 201) {
      return {
        'success': true,
        'message': decoded['message'] ?? 'Leave applied successfully!',
        'data': decoded,
      };
    }
    return {
      'success': false,
      'message': decoded['message'] ?? decoded['error'] ?? 'Error $statusCode',
    };
  } catch (_) {
    return {'success': false, 'message': 'Unexpected response ($statusCode)'};
  }
}

static String _mimeType(String ext) {
  switch (ext) {
    case 'pdf': return 'application/pdf';
    case 'png': return 'image/png';
    case 'jpg':
    case 'jpeg': return 'image/jpeg';
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default: return 'application/octet-stream';
  }
}}

// ─── PDF GENERATOR ───────────────────────────────────────────────────────────

class LeavePdfGenerator {
  static Future<Uint8List> generate({
    required Student student,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final config = getLeaveConfig(leaveType)!;
    final fmt = DateFormat('dd MMMM yyyy');
    final shortFmt = DateFormat('dd/MM/yyyy');
    final days = toDate.difference(fromDate).inDays + 1;

    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {}

    final baseStyle = pw.TextStyle(font: regularFont, fontSize: 11);
    final boldStyle = pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold);

    pw.ImageProvider? logo;
    if (logoBytes != null) {
      logo = pw.MemoryImage(logoBytes);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null) ...[
                    pw.Container(width: 70, height: 70, child: pw.Image(logo)),
                    pw.SizedBox(width: 16),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('BISHOP HEBER COLLEGE',
                          style: pw.TextStyle(font: boldFont, fontSize: 16,
                            color: PdfColor.fromHex('#1a237e'))),
                        pw.Text('(Autonomous) | Reaccredited with A++ by NAAC',
                          style: baseStyle.copyWith(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Puthur, Tiruchirappalli – 620 017',
                          style: baseStyle.copyWith(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#e8eaf6'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('LEAVE APPLICATION – ${config.label.toUpperCase()}',
                            style: pw.TextStyle(font: boldFont, fontSize: 10,
                              color: PdfColor.fromHex('#1a237e'))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Date & To ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: ${fmt.format(DateTime.now())}', style: baseStyle),
                pw.Text('Ref No: ___________', style: baseStyle.copyWith(color: PdfColors.grey500)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('To,', style: baseStyle),
            pw.SizedBox(height: 4),
            _toAddressBlock(boldStyle, baseStyle, config),
            pw.SizedBox(height: 16),

            // ── Subject ──
            pw.Row(children: [
              pw.Text('Sub: ', style: boldStyle),
              pw.Expanded(child: pw.Text(
                'Application for ${config.label} – ${shortFmt.format(fromDate)} to ${shortFmt.format(toDate)} ($days ${days == 1 ? "day" : "days"})',
                style: baseStyle,
              )),
            ]),
            pw.SizedBox(height: 16),

            // ── Salutation ──
            pw.Text('Respected Sir/Madam,', style: baseStyle),
            pw.SizedBox(height: 10),
            pw.Text(
              '        I, ${student.name}, Roll No. ${student.rollNo}, studying in ${student.deptName}, '
              '${_yearLabel(student.cyear)} Year, Section ${student.section}, ${student.shift}, '
              'respectfully request you to grant me ${config.label} for $days ${days == 1 ? "day" : "days"} '
              'from ${fmt.format(fromDate)} to ${fmt.format(toDate)}.',
              style: baseStyle,
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 10),
            pw.Text('        Reason: $reason', style: baseStyle, textAlign: pw.TextAlign.justify),
            pw.SizedBox(height: 10),
            pw.Text('        I kindly request you to consider my application and grant the leave accordingly.',
              style: baseStyle, textAlign: pw.TextAlign.justify),
            pw.SizedBox(height: 24),
            pw.Text('Thanking you,', style: baseStyle),
            pw.SizedBox(height: 4),
            pw.Text('Yours obediently,', style: baseStyle),
            pw.SizedBox(height: 24),

            // ── Applicant Sign ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(student.name, style: boldStyle),
                  pw.Text('Roll No: ${student.rollNo}', style: baseStyle.copyWith(fontSize: 10)),
                  pw.Text('Dept: ${student.deptName}', style: baseStyle.copyWith(fontSize: 10)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Signature:', style: baseStyle),
                  pw.SizedBox(height: 28),
                  pw.Container(width: 110, child: pw.Divider(color: PdfColors.grey600)),
                  pw.Text('(Student)', style: baseStyle.copyWith(fontSize: 9, color: PdfColors.grey600)),
                ]),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 12),

            // ── Approval Section ──
            pw.Text('FOR OFFICE USE ONLY', style: boldStyle.copyWith(
              color: PdfColors.grey700, fontSize: 9, letterSpacing: 1.2)),
            pw.SizedBox(height: 14),
            _buildSignatureRow(config.signatures, boldStyle, baseStyle),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _toAddressBlock(pw.TextStyle boldStyle, pw.TextStyle baseStyle, LeaveTypeConfig config) {
    String recipient;
    switch (config.value) {
      case 'medical': recipient = 'The Vice Principal'; break;
      case 'on_duty': recipient = 'The Head of the Department'; break;
      default: recipient = 'The Class Incharge';
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(recipient, style: boldStyle),
      pw.Text('Bishop Heber College', style: baseStyle),
      pw.Text('Puthur, Tiruchirappalli – 620 017', style: baseStyle),
    ]);
  }

  static pw.Widget _buildSignatureRow(
    List<String> signatures,
    pw.TextStyle boldStyle,
    pw.TextStyle baseStyle,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: signatures.map((sig) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(height: 48),
          pw.Container(width: 120, child: pw.Divider(color: PdfColors.grey700)),
          pw.Text(sig, style: boldStyle.copyWith(fontSize: 10)),
          pw.Text('Signature & Seal', style: baseStyle.copyWith(fontSize: 9, color: PdfColors.grey500)),
          pw.SizedBox(height: 4),
          pw.Text('Date: ____________', style: baseStyle.copyWith(fontSize: 9, color: PdfColors.grey500)),
        ],
      )).toList(),
    );
  }

  static String _yearLabel(String cyear) {
    switch (cyear) {
      case '1': return '1st'; case '2': return '2nd';
      case '3': return '3rd'; default: return '${cyear}th';
    }
  }
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class LeaveManagementScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const LeaveManagementScreen({Key? key, required this.rollNo, required this.studentName}) : super(key: key);

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  Student? _studentData;
  bool _isLoadingStudent = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _loadStudentData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    final student = await LeaveService.getStudentData(widget.rollNo);
    if (mounted) setState(() { _studentData = student; _isLoadingStudent = false; });
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(rollNo: widget.rollNo, studentName: widget.studentName, currentRoute: '/leave'),
      appBar: _buildAppBar(c),
      body: Column(
        children: [
          _buildTabBar(c),
          Divider(height: 1, color: c.border),
          Expanded(
            child: _selectedIndex == 0
                ? ApplyLeaveScreen(
                    rollNo: widget.rollNo,
                    studentName: widget.studentName,
                    studentData: _studentData,
                    isLoadingStudent: _isLoadingStudent,
                  )
                : MyApplicationsScreen(rollNo: widget.rollNo, studentName: widget.studentName),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: c.surface,
      child: Row(
        children: [
          Expanded(child: _tab(c, 0, 'Apply Leave', Icons.edit_calendar_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _tab(c, 1, 'My Applications', Icons.history_rounded)),
        ],
      ),
    );
  }

  Widget _tab(ThemeProvider c, int index, String title, IconData icon) {
    final sel = _selectedIndex == index;
    final color = sel ? c.cyan : c.textMid;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? c.cyan.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? c.cyan : c.border, width: sel ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeProvider c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(bottom: BorderSide(color: c.pink.withOpacity(0.15))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Builder(builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: c.textHigh, size: 22),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              )),
              const SizedBox(width: 4),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Leave Management', style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Student Leave Portal', style: TextStyle(color: c.pink.withOpacity(0.7), fontSize: 10, letterSpacing: 0.8)),
              ]),
              const Spacer(),
              _statusPill(c),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.pink.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.pink.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.pink)),
        const SizedBox(width: 5),
        Text('LEAVE', style: TextStyle(color: c.pink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
    );
  }
}

// ─── APPLY LEAVE SCREEN ───────────────────────────────────────────────────────

class ApplyLeaveScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;
  final Student? studentData;
  final bool isLoadingStudent;

  const ApplyLeaveScreen({
    Key? key, required this.rollNo, required this.studentName,
    this.studentData, this.isLoadingStudent = false,
  }) : super(key: key);

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedLeaveType = 'casual';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _reason = '';
  bool _isLoading = false;
  File? _selectedDocument;
  bool _isUploading = false;

  LeaveTypeConfig get _config => getLeaveConfig(_selectedLeaveType)!;
  Student? get _student => widget.studentData;

Future<void> _submitApplication() async {
  if (!_formKey.currentState!.validate()) return;
  if (_fromDate == null || _toDate == null) {
    _snack('Please select both start and end dates', error: true); return;
  }
  if (_fromDate!.isAfter(_toDate!)) {
    _snack('End date cannot be before start date', error: true); return;
  }
  if (_config.requiresDocument && _selectedDocument == null) {
    _snack('Please upload a supporting document', error: true); return;
  }

  setState(() => _isLoading = true);

  final result = await LeaveService.applyLeave(
    rollNo: widget.rollNo,
    leaveType: _selectedLeaveType,
    startDate: _fromDate!,
    endDate: _toDate!,
    reason: _reason,
    documentFile: _selectedDocument,
  );

  setState(() => _isLoading = false);

  if (result['success'] == true) {
    _snack(result['message'] ?? 'Leave applied successfully!', error: false);
    
    // ── capture values before resetForm clears them ──
    final capturedFrom = _fromDate;
    final capturedTo = _toDate;
    final capturedReason = _reason;
    final capturedType = _selectedLeaveType;
    
    _resetForm(); // clears _fromDate, _toDate etc.

    if (mounted && _student != null && capturedFrom != null && capturedTo != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => _PrintSuccessDialog(
            student: _student!,
            leaveType: capturedType,
            fromDate: capturedFrom,
            toDate: capturedTo,
            reason: capturedReason,
          ),
        );
      }
    }
  } else {
    _snack(result['message'] ?? 'Failed to apply leave', error: true);
  }
}

  void _showPrintSuccess() {
    showDialog(
      context: context,
      builder: (_) => _PrintSuccessDialog(
        student: _student!,
        leaveType: _selectedLeaveType,
        fromDate: _fromDate!,
        toDate: _toDate!,
        reason: _reason,
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      setState(() => _isUploading = true);
      final picker = ImagePicker();
      // Allow any file type via file_picker for doc/pdf support
      // Using image_picker as fallback for images only
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80,
      );
      if (file != null) {
        final size = await File(file.path).length();
        if (size > 5 * 1024 * 1024) {
          _snack('File size exceeds 5MB limit', error: true);
        } else {
          setState(() => _selectedDocument = File(file.path));
          _snack('Document selected', error: false);
        }
      }
    } catch (e) {
      _snack('Failed to pick document: $e', error: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _fromDate = null; _toDate = null;
      _reason = ''; _selectedLeaveType = 'casual';
      _selectedDocument = null;
    });
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentCard(c),
            const SizedBox(height: 24),
            _sectionLabel(c, 'Leave Type'),
            const SizedBox(height: 12),
            ...leaveTypes.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _leaveTypeCard(c, t),
            )),
            const SizedBox(height: 24),
            _sectionLabel(c, 'Leave Period'),
            const SizedBox(height: 12),
            _buildDateRow(c),
            const SizedBox(height: 24),
            _sectionLabel(c, 'Reason for Leave'),
            const SizedBox(height: 12),
            _buildReasonField(c),
            if (_config.requiresDocument) ...[
              const SizedBox(height: 24),
              _buildDocumentSection(c),
            ],
            const SizedBox(height: 32),
            _buildActionButtons(c),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(ThemeProvider c) {
    if (widget.isLoadingStudent) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Center(child: CircularProgressIndicator(color: c.cyan, strokeWidth: 2)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cyan.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.person_rounded, color: c.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.studentName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textHigh)),
            Text('Roll No: ${widget.rollNo}', style: TextStyle(fontSize: 12, color: c.textMid)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
            ),
            child: Text('BHC', style: TextStyle(color: c.cyan, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        Divider(height: 20, color: c.border),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _chip(c, 'Dept', _student?.deptName ?? '—'),
          _chip(c, 'Section', _student?.section ?? '—'),
          _chip(c, 'Shift', _student?.shift ?? '—'),
          _chip(c, 'Year', _student?.cyear ?? '—'),
        ]),
      ]),
    );
  }

  Widget _chip(ThemeProvider c, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: c.textLow, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, color: c.textHigh, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _sectionLabel(ThemeProvider c, String label) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: c.cyan, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textHigh)),
    ]);
  }

  Widget _leaveTypeCard(ThemeProvider c, LeaveTypeConfig t) {
    final isSelected = _selectedLeaveType == t.value;
    final color = t.colorFn(c);
    return GestureDetector(
      onTap: () => setState(() => _selectedLeaveType = t.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(t.icon, size: 20, color: isSelected ? Colors.white : color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHigh)),
            const SizedBox(height: 2),
            Row(children: [
              Text(t.description, style: TextStyle(fontSize: 12, color: c.textMid)),
              if (t.requiresDocument) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('Doc Required', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ])),
          // Signatures preview
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ...t.signatures.map((s) => Text('· $s', style: TextStyle(fontSize: 9, color: c.textLow))),
          ]),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? color : c.border, width: 2),
              color: isSelected ? color : Colors.transparent,
            ),
            child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }

  Widget _buildDateRow(ThemeProvider c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(children: [
        Row(children: [
          Expanded(child: _datePicker(c, 'From Date', true)),
          const SizedBox(width: 12),
          Expanded(child: _datePicker(c, 'To Date', false)),
        ]),
        if (_fromDate != null && _toDate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: c.cyan.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: c.cyan),
                const SizedBox(width: 6),
                Text('Duration:', style: TextStyle(fontSize: 13, color: c.textMid)),
              ]),
              Text(
                '${_toDate!.difference(_fromDate!).inDays + 1} ${_toDate!.difference(_fromDate!).inDays == 0 ? "day" : "days"}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.cyan),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _datePicker(ThemeProvider c, String label, bool isFrom) {
    final date = isFrom ? _fromDate : _toDate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: c.textMid, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: c.isDarkMode
                  ? ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: c.cyan))
                  : ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: c.cyan)),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: c.bg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: date != null ? c.cyan.withOpacity(0.5) : c.border),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: date != null ? c.cyan : c.textLow),
            const SizedBox(width: 8),
            Text(
              date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select',
              style: TextStyle(fontSize: 13, color: date != null ? c.textHigh : c.textLow, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildReasonField(ThemeProvider c) {
    return TextFormField(
      maxLines: 4,
      style: TextStyle(fontSize: 14, color: c.textHigh),
      decoration: InputDecoration(
        hintText: 'Describe the reason in detail…',
        hintStyle: TextStyle(color: c.textLow, fontSize: 13),
        filled: true, fillColor: c.surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.cyan, width: 2)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a reason' : null,
      onChanged: (v) => _reason = v,
    );
  }

  Widget _buildDocumentSection(ThemeProvider c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(c, 'Supporting Document'),
      const SizedBox(height: 4),
      Text('Allowed: PDF, JPG, JPEG, PNG, DOC, DOCX (max 5MB)',
        style: TextStyle(fontSize: 11, color: c.textLow)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _isUploading ? null : _pickDocument,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _selectedDocument != null ? c.cyan.withOpacity(0.05) : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedDocument != null ? c.cyan.withOpacity(0.4) : c.border,
              style: _selectedDocument == null ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: _selectedDocument == null
              ? Column(children: [
                  Icon(Icons.upload_file_rounded, size: 40, color: c.cyan.withOpacity(0.6)),
                  const SizedBox(height: 8),
                  Text('Tap to upload document', style: TextStyle(fontSize: 14, color: c.textMid, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Required for ${_config.label}', style: TextStyle(fontSize: 12, color: c.textLow)),
                ])
              : Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: c.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.insert_drive_file_rounded, color: c.cyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedDocument!.path.split('/').last,
                      style: TextStyle(fontSize: 13, color: c.textHigh, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Tap to change', style: TextStyle(fontSize: 11, color: c.textLow)),
                  ])),
                  Icon(Icons.check_circle_rounded, color: c.cyan, size: 22),
                ]),
        ),
      ),
    ]);
  }

  Widget _buildActionButtons(ThemeProvider c) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _resetForm,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Clear', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.cyan,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Submit Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
        ),
      ),
    ]);
  }
}

// ─── PRINT SUCCESS DIALOG ────────────────────────────────────────────────────

class _PrintSuccessDialog extends StatefulWidget {
  final Student student;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;

  const _PrintSuccessDialog({
    required this.student, required this.leaveType,
    required this.fromDate, required this.toDate, required this.reason,
  });

  @override
  State<_PrintSuccessDialog> createState() => _PrintSuccessDialogState();
}

class _PrintSuccessDialogState extends State<_PrintSuccessDialog> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context, listen: false);
    final config = getLeaveConfig(widget.leaveType)!;
    final color = config.colorFn(c);
    final fmt = DateFormat('dd/MM/yyyy');
    final days = widget.toDate.difference(widget.fromDate).inDays + 1;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 14),
          Text('Leave Applied!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textHigh)),
          const SizedBox(height: 6),
          Text('Your ${config.label} has been submitted for approval.',
            style: TextStyle(fontSize: 13, color: c.textMid), textAlign: TextAlign.center),
          const SizedBox(height: 20),

          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(config.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(config.label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Submitted', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 12),
              _row(c, Icons.person_rounded,       'Student',    widget.student.name),
              _row(c, Icons.badge_rounded,         'Roll No',    widget.student.rollNo),
              _row(c, Icons.school_rounded,        'Department', widget.student.deptName),
              _row(c, Icons.date_range_rounded,    'Period',
                '${fmt.format(widget.fromDate)} → ${fmt.format(widget.toDate)}'),
              _row(c, Icons.timelapse_rounded,     'Duration',   '$days day${days > 1 ? "s" : ""}'),
              _row(c, Icons.notes_rounded,         'Reason',
                widget.reason.length > 50 ? '${widget.reason.substring(0, 50)}…' : widget.reason),
            ]),
          ),
          const SizedBox(height: 14),

          // Signatures
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.approval_rounded, size: 14, color: c.textLow),
                const SizedBox(width: 6),
                Text('Requires signatures from:',
                  style: TextStyle(fontSize: 11, color: c.textLow, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6,
                children: config.signatures.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                )).toList()),
            ]),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Close', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isGenerating ? null : () => _downloadPdf(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isGenerating
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Download PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _row(ThemeProvider c, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: c.textLow),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: Text(label, style: TextStyle(fontSize: 12, color: c.textLow))),
        Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, color: c.textHigh, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    setState(() => _isGenerating = true);
    try {
      Uint8List? logoBytes;
      try {
        final data = await rootBundle.load('assets/images/bhc_logo.png');
        logoBytes = data.buffer.asUint8List();
      } catch (_) {}

      final pdfBytes = await LeavePdfGenerator.generate(
        student: widget.student,
        leaveType: widget.leaveType,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        reason: widget.reason,
        logoBytes: logoBytes,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'leave_${widget.student.rollNo}_${DateFormat('yyyyMMdd').format(widget.fromDate)}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

// ─── MY APPLICATIONS SCREEN ───────────────────────────────────────────────────

class MyApplicationsScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const MyApplicationsScreen({Key? key, required this.rollNo, required this.studentName}) : super(key: key);

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}
class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<LeaveApplication> _all = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'All';
  String _search = '';

  final _filters = ['All', 'Pending', 'Approved', 'Rejected', 'casual', 'medical', 'on_duty', 'emergency'];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      _all = await LeaveService.getLeaveApplications(widget.rollNo);
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ← Fixed: List<dynamic> instead of Map
  String _status(List<dynamic> approvals) {
    if (approvals.isEmpty) return 'Pending';
    if (approvals.any((a) => a['status'] == 'rejected')) return 'Rejected';
    if (approvals.every((a) => a['status'] == 'approved')) return 'Approved';
    return 'Pending';
  }

  List<LeaveApplication> get _filtered {
    return _all.where((app) {
      final status = _status(app.approvals);
      final matchFilter = _filter == 'All' || status == _filter || app.leaveType == _filter;
      final matchSearch = _search.isEmpty ||
          app.reason.toLowerCase().contains(_search.toLowerCase()) ||
          app.leaveType.toLowerCase().contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final total    = _all.length;
    final pending  = _all.where((a) => _status(a.approvals) == 'Pending').length;
    final approved = _all.where((a) => _status(a.approvals) == 'Approved').length;
    final rejected = _all.where((a) => _status(a.approvals) == 'Rejected').length;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        color: c.surface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('My Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textHigh)),
            IconButton(icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20), onPressed: _fetch),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _stat(c, 'Total',    total,    c.violet),
            _stat(c, 'Pending',  pending,  c.amber),
            _stat(c, 'Approved', approved, c.cyan),
            _stat(c, 'Rejected', rejected, c.pink),
          ]),
        ]),
      ),
      Container(
        height: 44,
        color: c.surface,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: _filters.length,
          itemBuilder: (_, i) {
            final f = _filters[i];
            final sel = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? c.cyan : c.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? c.cyan : c.border),
                ),
                child: Text(_filterLabel(f),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : c.textMid)),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: TextField(
          style: TextStyle(color: c.textHigh, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by reason or type…',
            hintStyle: TextStyle(color: c.textLow, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: c.textLow, size: 20),
            filled: true, fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.cyan)),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      Expanded(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.cyan))
            : _error != null
                ? _emptyState(c, Icons.error_outline_rounded, _error!, c.pink)
                : _filtered.isEmpty
                    ? _emptyState(c, Icons.inbox_outlined, 'No applications found', c.textLow)
                    : RefreshIndicator(
                        color: c.cyan,
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _appCard(c, _filtered[i]),
                        ),
                      ),
      ),
    ]);
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'on_duty':    return 'On Duty';
      case 'emergency':  return 'Emergency';
      default:           return f;
    }
  }

  Widget _stat(ThemeProvider c, String label, int count, Color color) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: c.textMid)),
      ]),
    ));
  }

  Widget _emptyState(ThemeProvider c, IconData icon, String msg, Color color) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 56, color: color.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: c.textMid, fontSize: 14)),
    ]));
  }

  Widget _appCard(ThemeProvider c, LeaveApplication app) {
    final status      = _status(app.approvals);
    final statusColor = status == 'Approved' ? c.green : status == 'Rejected' ? c.pink : c.amber;
    final config      = getLeaveConfig(app.leaveType)!;
    final typeColor   = config.colorFn(c);
    final fmt         = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(config.icon, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(config.label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.reason,
              style: TextStyle(fontSize: 13, color: c.textHigh, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.date_range_rounded, size: 13, color: c.textLow),
              const SizedBox(width: 4),
              Text('${fmt.format(app.fromDate)} – ${fmt.format(app.toDate)}',
                style: TextStyle(fontSize: 12, color: c.textMid)),
              const SizedBox(width: 12),
              Icon(Icons.timelapse_rounded, size: 13, color: c.textLow),
              const SizedBox(width: 4),
              Text('${app.durationDays} day(s)',
                style: TextStyle(fontSize: 12, color: c.textMid)),
            ]),
          ]),
        ),
      ]),
    );
  }
}