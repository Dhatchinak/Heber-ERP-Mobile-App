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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveApplication {
  final String id, rollNo, leaveType, reason;
  final DateTime fromDate, toDate, appliedDate;
  final int durationDays;
  final List<dynamic> approvals;
  final String? supportingDocument;

  const LeaveApplication({
    required this.id,
    required this.rollNo,
    required this.leaveType,
    required this.reason,
    required this.fromDate,
    required this.toDate,
    required this.appliedDate,
    required this.durationDays,
    required this.approvals,
    this.supportingDocument,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> j) {
    final start = j['startDate'] ?? j['from_date'];
    final end = j['endDate'] ?? j['to_date'];
    final created = j['appliedAt'] ?? j['createdAt'];
    return LeaveApplication(
      id: j['_id'] ?? '',
      rollNo: j['roll_no']?.toString() ?? '',
      leaveType: j['leaveType'] ?? j['leave_type'] ?? '',
      reason: j['reason'] ?? '',
      fromDate: DateTime.tryParse(start ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(end ?? '') ?? DateTime.now(),
      appliedDate: DateTime.tryParse(created ?? '') ?? DateTime.now(),
      durationDays: j['durationDays'] ?? 0,
      approvals: j['approvals'] is List ? j['approvals'] : [],
      supportingDocument:
          j['supportingDocument'] is String ? j['supportingDocument'] : null,
    );
  }

  bool get canCancel => status == 'Pending';

  String get status {
    if (approvals.isEmpty) return 'Pending';
    if (approvals.any((a) => a['status'] == 'rejected')) return 'Rejected';
    if (approvals.every((a) => a['status'] == 'approved')) return 'Approved';
    return 'Pending';
  }
}

class Student {
  final String rollNo, name, deptName, section, shift, batch;
  const Student(
      {required this.rollNo,
      required this.name,
      required this.deptName,
      required this.section,
      required this.shift,
      required this.batch});

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        rollNo: j['roll_no']?.toString() ?? '',
        name: j['name'] ?? '',
        deptName:
            j['current_academic']?['degree_name'] ?? j['dept_name'] ?? 'N/A',
        section: j['current_academic']?['section'] ?? j['section'] ?? 'A',
        shift: j['current_academic']?['shift'] ?? 'Shift-1',
        batch: j['batch'] ?? '',
      );

  String get cyear {
    try {
      final y = int.tryParse(batch.split('-').first) ?? DateTime.now().year;
      final diff =
          DateTime.now().year - y + (DateTime.now().month >= 6 ? 1 : 0);
      return diff.clamp(1, 4).toString();
    } catch (_) {
      return '1';
    }
  }

  String get yearLabel {
    switch (cyear) {
      case '1':
        return '1st';
      case '2':
        return '2nd';
      case '3':
        return '3rd';
      default:
        return '${cyear}th';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEAVE TYPE CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveTypeConfig {
  final String value, label, description;
  final IconData icon;
  final bool requiresDocument;
  final List<String> signatures;
  final Color Function(ThemeProvider) colorFn;
  const LeaveTypeConfig(
      {required this.value,
      required this.label,
      required this.description,
      required this.icon,
      required this.requiresDocument,
      required this.signatures,
      required this.colorFn});
}

final _leaveTypes = [
  LeaveTypeConfig(
      value: 'casual',
      label: 'Casual Leave',
      description: 'Personal / family reasons',
      icon: Icons.beach_access_rounded,
      requiresDocument: false,
      signatures: ['Class Incharge', 'HOD'],
      colorFn: (c) => c.cyan),
  LeaveTypeConfig(
      value: 'medical',
      label: 'Medical Leave',
      description: 'Requires medical document',
      icon: Icons.local_hospital_rounded,
      requiresDocument: true,
      signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
      colorFn: (c) => c.pink),
  LeaveTypeConfig(
      value: 'on_duty',
      label: 'On Duty',
      description: 'Official duty / event',
      icon: Icons.work_rounded,
      requiresDocument: true,
      signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
      colorFn: (c) => c.violet),
  LeaveTypeConfig(
      value: 'emergency',
      label: 'Emergency Leave',
      description: 'Unexpected urgent situation',
      icon: Icons.warning_rounded,
      requiresDocument: false,
      signatures: ['Class Incharge', 'HOD'],
      colorFn: (c) => c.amber),
];

// ═══════════════════════════════════════════════════════════════════════════════
// ACADEMIC YEAR & SEMESTER HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

String _academicYear() {
  final now = DateTime.now();
  final year = now.month >= 6 ? now.year : now.year - 1;
  return '$year-${year + 1}';
}

String _semesterType() {
  final month = DateTime.now().month;
  return (month >= 6 && month <= 11) ? 'sem_odd' : 'sem_even';
}

LeaveTypeConfig _cfg(String v) =>
    _leaveTypes.firstWhere((t) => t.value == v, orElse: () => _leaveTypes[0]);

// ═══════════════════════════════════════════════════════════════════════════════
// API SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveService {
  static const _base = 'https://apierp.bhc.edu.in/api';
  static const _referer = 'http://117.232.64.75';

  static const _jsonHeaders = {
    'Referer': _referer,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  static const _baseHeaders = {
    'Referer': _referer,
    'Accept': 'application/json'
  };

  static String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static Map<String, dynamic> _parse(int code, String body) {
    if (body.isEmpty) return {'success': false, 'message': 'Empty response'};
    try {
      final d = json.decode(body);
      if (code == 200 || code == 201) {
        return {
          'success': true,
          'message': d['message'] ?? 'Leave applied successfully!'
        };
      }
      return {
        'success': false,
        'message': d['message'] ?? d['error'] ?? 'Error $code'
      };
    } catch (_) {
      return {'success': false, 'message': 'Unexpected response ($code)'};
    }
  }

  // ── Get student profile ───────────────────────────────────────────────────
  static Future<Student?> getStudentData(String rollNo) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/students/$rollNo'), headers: _baseHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        final data = j['data'] ?? j;
        return Student.fromJson(data);
      }
    } catch (e) {
      debugPrint('getStudent: $e');
    }
    return null;
  }

  // ── Apply leave ───────────────────────────────────────────────────────────
  // Casual / Emergency  → plain JSON (no file)
  // Medical / On Duty   → multipart (file as 'supportingDocument' field)
  static Future<Map<String, dynamic>> applyLeave({
    required String rollNo,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    File? documentFile,
  }) async {
    final uri = Uri.parse('$_base/students/leave/apply');
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    final rollInt = int.tryParse(rollNo) ?? rollNo;

    try {
      // ── No document → plain JSON ──────────────────────────────────────────
      if (documentFile == null) {
        final res = await http
            .post(
              uri,
              headers: _jsonHeaders,
              body: json.encode({
                'roll_no': rollInt,
                'leaveType': leaveType,
                'startDate': startStr,
                'endDate': endStr,
                'reason': reason,
              }),
            )
            .timeout(const Duration(seconds: 20));
        debugPrint('📡 JSON ${res.statusCode} | ${res.body}');
        return _parse(res.statusCode, res.body);
      }

      // ── Has document → multipart ──────────────────────────────────────────
      final req = http.MultipartRequest('POST', uri);
      req.headers['Referer'] = _referer;
      req.headers['Accept'] = 'application/json';
      req.headers['Origin'] = _referer;

      // roll_no sent as numeric string (server expects number)
      req.fields['roll_no'] = (int.tryParse(rollNo) ?? rollNo).toString();
      req.fields['leaveType'] = leaveType;
      req.fields['startDate'] = startStr;
      req.fields['endDate'] = endStr;
      req.fields['reason'] = reason;

      final ext =
          p.extension(documentFile.path).replaceFirst('.', '').toLowerCase();
      req.files.add(await http.MultipartFile.fromPath(
        'supportingDocument',
        documentFile.path,
        contentType: MediaType.parse(_mimeType(ext)),
      ));

      debugPrint(
          '🚀 MULTIPART | type=$leaveType fields=${req.fields} file=${documentFile.path}');

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      debugPrint('📡 ${streamed.statusCode} | $body');

      // Some servers return 500 but with success payload — check body first
      try {
        final decoded = json.decode(body);
        if (decoded['success'] == true ||
            decoded['message']?.toString().toLowerCase().contains('success') ==
                true) {
          return {
            'success': true,
            'message': decoded['message'] ?? 'Leave applied successfully!'
          };
        }
      } catch (_) {}

      return _parse(streamed.statusCode, body);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Check connection.'
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.'};
    } catch (e) {
      debugPrint('applyLeave error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Get leave history ─────────────────────────────────────────────────────
  static Future<List<LeaveApplication>> getLeaveApplications(
      String rollNo) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/students/leave/$rollNo'),
              headers: _baseHeaders)
          .timeout(const Duration(seconds: 12));
      debugPrint(
          '📡 GET leaves ${res.statusCode} | ${res.body.substring(0, res.body.length.clamp(0, 200))}');
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        List<dynamic> list = j is List ? j : (j['leaves'] ?? j['data'] ?? []);
        return list
            .map((e) {
              try {
                return LeaveApplication.fromJson(e);
              } catch (err) {
                debugPrint('parse err: $err');
                return null;
              }
            })
            .whereType<LeaveApplication>()
            .toList();
      }
    } catch (e) {
      debugPrint('getLeaves: $e');
    }
    return [];
  }

  // ── Cancel (delete) leave ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelLeave({
    required String rollNo,
    required String leaveId,
  }) async {
    try {
      final rollInt = int.tryParse(rollNo) ?? rollNo;
      final res = await http
          .post(
            Uri.parse('$_base/students/leave/cancel'),
            headers: _jsonHeaders,
            body: json.encode({
              'roll_no': rollInt,
              'leaveId': leaveId,
              'academicYear': _academicYear(),
              'semesterType': _semesterType(),
              'remarks': '',
            }),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('CANCEL ${res.statusCode} | ${res.body}');
      return _parse(res.statusCode, res.body);
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: \$e'};
    }
  }

  // ── Update leave ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateLeave({
    required String rollNo,
    required String leaveId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final rollInt = int.tryParse(rollNo) ?? rollNo;
      final res = await http
          .post(
            Uri.parse('$_base/attendance/leaves/update'),
            headers: _jsonHeaders,
            body: json.encode({
              'roll_no': rollInt,
              'leaveId': leaveId,
              'academicYear': _academicYear(),
              'semesterType': _semesterType(),
              'leaveType': leaveType,
              'startDate': DateFormat('yyyy-MM-dd').format(startDate),
              'endDate': DateFormat('yyyy-MM-dd').format(endDate),
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('UPDATE ${res.statusCode} | ${res.body}');
      return _parse(res.statusCode, res.body);
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: \$e'};
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PDF GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

// Replace your existing LeavePdfGenerator class with this completely redesigned version


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
    
    // Get leave type config
    final config = _getLeaveTypeConfig(leaveType);
    
    // Format dates
    final dateFormat = DateFormat('dd MMMM yyyy');
    final today = dateFormat.format(DateTime.now());
    final fromDateStr = dateFormat.format(fromDate);
    final toDateStr = dateFormat.format(toDate);
    final days = toDate.difference(fromDate).inDays + 1;
    
    // Colors
    final navyBlue = PdfColor.fromInt(0xFF1A2A4A);
    final gold = PdfColor.fromInt(0xFFC9A03D);
    final lightGray = PdfColor.fromInt(0xFFF5F5F5);
    final mediumGray = PdfColor.fromInt(0xFF666666);
    final borderGray = PdfColor.fromInt(0xFFE0E0E0);
    
    // Accent color based on leave type
    PdfColor accentColor;
    switch (leaveType) {
      case 'medical':
        accentColor = PdfColor.fromInt(0xFFE91E63);
        break;
      case 'on_duty':
        accentColor = PdfColor.fromInt(0xFF9C27B0);
        break;
      case 'emergency':
        accentColor = PdfColor.fromInt(0xFFFF9800);
        break;
      default:
        accentColor = PdfColor.fromInt(0xFF00A86B);
    }
    
    // Load fonts
    pw.Font? regularFont;
    pw.Font? boldFont;
    pw.Font? italicFont;
    
    try {
      regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      italicFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
    } catch (e) {
      // Fonts not found, will use default
      print('Fonts not loaded: $e');
    }
    
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 50,
        marginRight: 50,
        marginTop: 50,
        marginBottom: 50,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ========== HEADER ==========
            pw.Center(
              child: pw.Column(children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (logoBytes != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('BISHOP HEBER COLLEGE', 
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text('(Autonomous)', 
                            style: pw.TextStyle(font: regularFont, fontSize: 10, color: mediumGray)),
                        pw.Text('Reaccredited with A++ Grade by NAAC', 
                            style: pw.TextStyle(font: regularFont, fontSize: 9, color: mediumGray)),
                        pw.Text('Puthur, Tiruchirappalli – 620 017', 
                            style: pw.TextStyle(font: regularFont, fontSize: 9, color: mediumGray)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 2, color: gold),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFDF8E7),
                    border: pw.Border.all(color: gold, width: 0.5),
                  ),
                  child: pw.Text(
                    'APPLICATION FOR ${config.label.toUpperCase()} LEAVE',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: navyBlue,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(height: 1, color: gold),
              ]),
            ),
            
            pw.SizedBox(height: 30),
            
            // ========== DATE ==========
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: $today', 
                        style: pw.TextStyle(font: regularFont, fontSize: 10.5, color: mediumGray)),
                    pw.SizedBox(height: 4),
                    pw.Container(width: 100, height: 0.5, color: mediumGray),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // ========== RECIPIENT ==========
            pw.Text('To,', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text(config.recipientDesignation, 
                style: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(student.deptName, 
                style: pw.TextStyle(font: regularFont, fontSize: 11, color: mediumGray)),
            pw.Text('Bishop Heber College', 
                style: pw.TextStyle(font: regularFont, fontSize: 11, color: mediumGray)),
            pw.Text('Tiruchirappalli - 620 017', 
                style: pw.TextStyle(font: regularFont, fontSize: 11, color: mediumGray)),
            
            pw.SizedBox(height: 25),
            
            // ========== SUBJECT ==========
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF0F9F0),
              ),
              child: pw.Row(
                children: [
                  pw.Text('Subject:', 
                      style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      'Application for ${config.label} Leave – $fromDateStr to $toDateStr',
                      style: pw.TextStyle(font: regularFont, fontSize: 11, color: accentColor),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // ========== SALUTATION ==========
            pw.Text('Respected Sir / Madam,', 
                style: pw.TextStyle(font: italicFont, fontSize: 11.5)),
            
            pw.SizedBox(height: 12),
            
            // ========== BODY ==========
            pw.Text(
              'I, ${student.name}, a student of ${student.deptName}, '
              '${_getYearOrdinal(student.cyear)} Year, Section – ${student.section} '
              '(${student.shift}), bearing Roll Number ${student.rollNo}, '
              'most respectfully submit that I am unable to attend the college '
              'from $fromDateStr to $toDateStr ($days days) due to $reason.\n\n'
              'Therefore, I humbly request you to kindly grant me '
              '${config.label.toLowerCase()} leave for $days days and oblige. '
              'I assure you that I will compensate for any academic loss during this period.',
              style: pw.TextStyle(font: regularFont, fontSize: 11),
              textAlign: pw.TextAlign.justify,
            ),
            
            pw.SizedBox(height: 35),
            
            // ========== SIGNATURE ==========
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 160, child: pw.Divider(thickness: 0.8)),
                    pw.SizedBox(height: 4),
                    pw.Text(student.name, 
                        style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Roll No: ${student.rollNo}', 
                        style: pw.TextStyle(font: regularFont, fontSize: 10, color: mediumGray)),
                    pw.Text('${student.deptName}, ${_getYearOrdinal(student.cyear)} Year', 
                        style: pw.TextStyle(font: regularFont, fontSize: 10, color: mediumGray)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 20),
                    pw.Container(width: 150, child: pw.Divider(thickness: 0.8)),
                    pw.Text('(Student Signature)', 
                        style: pw.TextStyle(font: italicFont, fontSize: 9, color: mediumGray)),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 35),
            
            // ========== OFFICE USE ==========
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGray,
                border: pw.Border.all(color: borderGray, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FOR OFFICE USE ONLY', 
                      style: pw.TextStyle(font: boldFont, fontSize: 9, fontWeight: pw.FontWeight.bold, color: gold)),
                  pw.SizedBox(height: 12),
                  pw.Container(height: 0.5, color: borderGray),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      for (int i = 0; i < config.signatures.length; i++)
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                height: 60,
                                width: double.infinity,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: borderGray, width: 0.5),
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Container(width: double.infinity, height: 0.5, color: borderGray),
                              pw.SizedBox(height: 4),
                              pw.Text(config.signatures[i], 
                                  style: pw.TextStyle(font: boldFont, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Date: ___________', 
                                  style: pw.TextStyle(font: regularFont, fontSize: 8, color: mediumGray)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // ========== FOOTER ==========
            pw.Container(height: 0.5, color: mediumGray),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Bishop Heber College ERP System', 
                    style: pw.TextStyle(font: italicFont, fontSize: 7.5, color: mediumGray)),
                pw.Text('Page 1 of 1', 
                    style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: mediumGray)),
              ],
            ),
          ],
        );
      },
    ));
    
    return pdf.save();
  }
  
  static String _getYearOrdinal(String year) {
    switch (year) {
      case '1': return 'First';
      case '2': return 'Second';
      case '3': return 'Third';
      case '4': return 'Fourth';
      default: return '${year}th';
    }
  }
}

// Helper class
class _LeaveTypeConfig {
  final String label;
  final String recipientDesignation;
  final List<String> signatures;
  
  const _LeaveTypeConfig({
    required this.label,
    required this.recipientDesignation,
    required this.signatures,
  });
}

_LeaveTypeConfig _getLeaveTypeConfig(String leaveType) {
  switch (leaveType) {
    case 'medical':
      return _LeaveTypeConfig(
        label: 'Medical',
        recipientDesignation: 'The Vice Principal',
        signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
      );
    case 'on_duty':
      return _LeaveTypeConfig(
        label: 'On Duty',
        recipientDesignation: 'The Head of the Department',
        signatures: ['Class Incharge', 'HOD', 'Vice Principal'],
      );
    case 'emergency':
      return _LeaveTypeConfig(
        label: 'Emergency',
        recipientDesignation: 'The Class Incharge',
        signatures: ['Class Incharge', 'HOD'],
      );
    default: // casual
      return _LeaveTypeConfig(
        label: 'Casual',
        recipientDesignation: 'The Class Incharge',
        signatures: ['Class Incharge', 'HOD'],
      );
  }
}



// Helper to get font references (make these global or pass them properly)
pw.Font? regularFont;
pw.Font? boldFont;
pw.Font? italicFont;
pw.Font? lightFont;

// Make sure to load fonts asynchronously - add this initialization
Future<void> initializePdfFonts() async {
  try {
    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final italicData = await rootBundle.load('assets/fonts/Roboto-Italic.ttf');
    final lightData = await rootBundle.load('assets/fonts/Roboto-Light.ttf');
    
    regularFont = pw.Font.ttf(regularData);
    boldFont = pw.Font.ttf(boldData);
    italicFont = pw.Font.ttf(italicData);
    lightFont = pw.Font.ttf(lightData);
  } catch (e) {
    debugPrint('Font loading failed: $e');
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveManagementScreen extends StatefulWidget {
  final String rollNo, studentName;
  const LeaveManagementScreen(
      {super.key, required this.rollNo, required this.studentName});
  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  Student? _student;
  bool _loadingStudent = true;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    LeaveService.getStudentData(widget.rollNo).then((s) {
      if (mounted)
        setState(() {
          _student = s;
          _loadingStudent = false;
        });
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
          rollNo: widget.rollNo,
          studentName: widget.studentName,
          currentRoute: '/leave'),
      appBar: _appBar(c),
      body: Column(children: [
        _tabBar(c),
        Expanded(
            child: IndexedStack(index: _tab, children: [
          ApplyLeaveScreen(
            rollNo: widget.rollNo,
            studentName: widget.studentName,
            studentData: _student,
            isLoadingStudent: _loadingStudent,
          ),
          MyApplicationsScreen(
              rollNo: widget.rollNo,
              studentName: widget.studentName,
              student: _student),
        ])),
      ]),
    );
  }

  PreferredSizeWidget _appBar(ThemeProvider c) => PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                  bottom: BorderSide(
                      color: c.cyan.withOpacity(0.13 + _glowCtrl.value * 0.1))),
              boxShadow: [
                BoxShadow(color: c.cyan.withOpacity(0.04), blurRadius: 20)
              ],
            ),
            child: SafeArea(
                bottom: false,
                child: SizedBox(
                    height: kToolbarHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(children: [
                        Builder(
                            builder: (ctx) => IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                        color: c.elevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: c.border)),
                                    child: Icon(Icons.menu_rounded,
                                        color: c.textHigh, size: 18),
                                  ),
                                  onPressed: () =>
                                      Scaffold.of(ctx).openDrawer(),
                                )),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Leave Management',
                                  style: TextStyle(
                                      color: c.textHigh,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  'STUDENT LEAVE PORTAL  •  ${_academicYear()}',
                                  style: TextStyle(
                                      color: c.cyan.withOpacity(0.75),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8)),
                            ])),
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                              color: c.cyan.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: c.cyan.withOpacity(0.25))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.cyan,
                                    boxShadow: [
                                      BoxShadow(
                                          color: c.cyan.withOpacity(0.6),
                                          blurRadius: 4)
                                    ])),
                            const SizedBox(width: 5),
                            Text('LEAVE',
                                style: TextStyle(
                                    color: c.cyan,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1)),
                          ]),
                        ),
                      ]),
                    ))),
          ),
        ),
      );

  Widget _tabBar(ThemeProvider c) => Container(
        color: c.surface,
        child: Row(children: [
          _tabBtn(c, 0, 'Apply Leave', Icons.edit_calendar_rounded),
          _tabBtn(c, 1, 'My Applications', Icons.history_rounded),
        ]),
      );

  Widget _tabBtn(ThemeProvider c, int i, String label, IconData icon) {
    final sel = _tab == i;
    return Expanded(
        child: GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? c.cyan.withOpacity(0.08) : Colors.transparent,
          border: Border(
              bottom: BorderSide(
                  color: sel ? c.cyan : c.border, width: sel ? 2.5 : 1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: sel ? c.cyan : c.textMid),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? c.cyan : c.textMid)),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APPLY LEAVE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class ApplyLeaveScreen extends StatefulWidget {
  final String rollNo, studentName;
  final Student? studentData;
  final bool isLoadingStudent;
  const ApplyLeaveScreen(
      {super.key,
      required this.rollNo,
      required this.studentName,
      this.studentData,
      this.isLoadingStudent = false});
  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  String _leaveType = 'casual';
  DateTime? _fromDate, _toDate;
  File? _docFile;
  bool _loading = false;

  LeaveTypeConfig get _config => _cfg(_leaveType);
  int get _days => (_fromDate != null && _toDate != null)
      ? _toDate!.difference(_fromDate!).inDays + 1
      : 0;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, ThemeProvider c, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: err ? c.pink : c.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));

  Future<void> _pickDoc() async {
    final xf = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (xf != null && mounted) {
      final size = await File(xf.path).length();
      if (size > 5 * 1024 * 1024) {
        final c = Provider.of<ThemeProvider>(context, listen: false);
        _snack('File exceeds 5 MB limit', c, err: true);
      } else {
        setState(() => _docFile = File(xf.path));
      }
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _reasonCtrl.clear();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _docFile = null;
      _leaveType = 'casual';
    });
  }

  Future<void> _submit() async {
    final c = Provider.of<ThemeProvider>(context, listen: false);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fromDate == null || _toDate == null) {
      _snack('Select start & end dates', c, err: true);
      return;
    }
    if (_config.requiresDocument && _docFile == null) {
      _snack('Upload supporting document for ${_config.label}', c, err: true);
      return;
    }

    setState(() => _loading = true);
    final res = await LeaveService.applyLeave(
      rollNo: widget.rollNo,
      leaveType: _leaveType,
      startDate: _fromDate!,
      endDate: _toDate!,
      reason: _reasonCtrl.text.trim(),
      documentFile: _docFile,
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (res['success'] == true) {
      // Capture before reset
      final ft = _fromDate!,
          tt = _toDate!,
          rs = _reasonCtrl.text.trim(),
          lt = _leaveType;
      _reset();
      _snack(res['message'] ?? 'Applied successfully!', c);
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted && widget.studentData != null) {
        showDialog(
            context: context,
            builder: (_) => _SuccessDialog(
                  student: widget.studentData!,
                  leaveType: lt,
                  fromDate: ft,
                  toDate: tt,
                  reason: rs,
                ));
      }
    } else {
      _snack(res['message'] ?? 'Failed to apply leave', c, err: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Student card
          _studentCard(c),
          const SizedBox(height: 20),
          _label(c, 'Leave Type'),
          const SizedBox(height: 10),
          ..._leaveTypes.map((t) => _typeCard(t, c)),
          const SizedBox(height: 20),
          _label(c, 'Leave Period'),
          const SizedBox(height: 10),
          _dateRow(c),
          const SizedBox(height: 20),
          _label(c, 'Reason'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 4,
            style: TextStyle(color: c.textHigh, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe your reason clearly…',
              hintStyle: TextStyle(color: c.textLow, fontSize: 13),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.cyan, width: 1.5)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter reason' : null,
          ),
          if (_config.requiresDocument) ...[
            const SizedBox(height: 20),
            _label(c, 'Supporting Document *'),
            const SizedBox(height: 4),
            Text('JPG, PNG, PDF, DOC, DOCX — max 5 MB',
                style: TextStyle(color: c.textLow, fontSize: 11)),
            const SizedBox(height: 10),
            _docArea(c),
          ],
          const SizedBox(height: 28),
          Row(children: [
            OutlinedButton(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Clear',
                  style:
                      TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.cyan, c.violet]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: c.cyan.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.send_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Submit Application',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ]),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _label(ThemeProvider c, String t) => Row(children: [
        Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.cyan, c.violet]),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(t,
            style: TextStyle(
                color: c.textHigh, fontSize: 13, fontWeight: FontWeight.w700)),
      ]);

  Widget _studentCard(ThemeProvider c) {
    if (widget.isLoadingStudent)
      return Container(
          height: 88,
          decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border)),
          child: Center(
              child: CircularProgressIndicator(color: c.cyan, strokeWidth: 2)));

    final s = widget.studentData;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.cyan, c.violet]),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.studentName,
              style: TextStyle(
                  color: c.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text('${widget.rollNo}  ·  ${s?.deptName ?? ''}',
              style: TextStyle(color: c.textMid, fontSize: 11)),
        ])),
        if (s != null)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.cyan.withOpacity(0.3))),
              child: Text('Yr ${s.cyear} · ${s.section}',
                  style: TextStyle(
                      color: c.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _typeCard(LeaveTypeConfig t, ThemeProvider c) {
    final sel = _leaveType == t.value;
    final color = t.colorFn(c);
    return GestureDetector(
      onTap: () => setState(() => _leaveType = t.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.07) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: sel ? color : c.border, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(sel ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(t.icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.label,
                    style: TextStyle(
                        color: c.textHigh,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Row(children: [
                  Text(t.description,
                      style: TextStyle(color: c.textMid, fontSize: 11)),
                  if (t.requiresDocument) ...[
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('Doc required',
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w700))),
                  ],
                ]),
              ])),
          AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: sel ? color : c.border, width: 2),
                  color: sel ? color : Colors.transparent),
              child: sel
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null),
        ]),
      ),
    );
  }

  Widget _dateRow(ThemeProvider c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border)),
        child: Column(children: [
          Row(children: [
            Expanded(child: _datePicker(c, 'Start Date', true)),
            const SizedBox(width: 12),
            Expanded(child: _datePicker(c, 'End Date', false)),
          ]),
          if (_days > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 14, color: c.cyan),
                      const SizedBox(width: 6),
                      Text('Duration:',
                          style: TextStyle(color: c.textMid, fontSize: 12))
                    ]),
                    Text('$_days day${_days > 1 ? "s" : ""}',
                        style: TextStyle(
                            color: c.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
            ),
          ],
        ]),
      );

  Widget _datePicker(ThemeProvider c, String label, bool isFrom) {
    final d = isFrom ? _fromDate : _toDate;
    return GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: d ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(data: c.themeData, child: child!),
        );
        if (p != null && mounted)
          setState(() {
            if (isFrom) {
              _fromDate = p;
              if (_toDate?.isBefore(p) == true) _toDate = null;
            } else
              _toDate = p;
          });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: d != null ? c.cyan.withOpacity(0.4) : c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: c.textMid, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 14, color: d != null ? c.cyan : c.textLow),
            const SizedBox(width: 6),
            Text(d != null ? DateFormat('dd/MM/yyyy').format(d) : 'Select',
                style: TextStyle(
                    color: d != null ? c.textHigh : c.textLow,
                    fontSize: 12,
                    fontWeight:
                        d != null ? FontWeight.w700 : FontWeight.normal)),
          ]),
        ]),
      ),
    );
  }

  Widget _docArea(ThemeProvider c) => GestureDetector(
        onTap: _pickDoc,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _docFile != null ? c.green.withOpacity(0.05) : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      _docFile != null ? c.green.withOpacity(0.4) : c.border)),
          child: _docFile == null
              ? Column(children: [
                  Icon(Icons.cloud_upload_rounded,
                      size: 38, color: c.cyan.withOpacity(0.7)),
                  const SizedBox(height: 8),
                  Text('Tap to upload',
                      style: TextStyle(
                          color: c.textHigh,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('Required for ${_config.label}',
                      style: TextStyle(color: c.textLow, fontSize: 11)),
                ])
              : Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: c.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.check_circle_rounded,
                          color: c.green, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p.basename(_docFile!.path),
                            style: TextStyle(
                                color: c.textHigh,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('Tap to change',
                            style: TextStyle(color: c.textLow, fontSize: 10)),
                      ])),
                  GestureDetector(
                      onTap: () => setState(() => _docFile = null),
                      child: Icon(Icons.close_rounded,
                          color: c.textLow, size: 18)),
                ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS DIALOG (shown after leave is applied)
// ═══════════════════════════════════════════════════════════════════════════════

class _SuccessDialog extends StatefulWidget {
  final Student student;
  final String leaveType, reason;
  final DateTime fromDate, toDate;
  const _SuccessDialog(
      {required this.student,
      required this.leaveType,
      required this.fromDate,
      required this.toDate,
      required this.reason});
  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;
  bool _generating = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf(ThemeProvider c) async {
    setState(() => _generating = true);
    try {
      Uint8List? logo;
      try {
        final d = await rootBundle.load('assets/bhclogo.png');
        logo = d.buffer.asUint8List();
      } catch (_) {}
      final bytes = await LeavePdfGenerator.generate(
        student: widget.student,
        leaveType: widget.leaveType,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        reason: widget.reason,
        logoBytes: logo,
      );
      final filename =
          'BHC_Leave_${widget.student.rollNo}_${DateFormat('yyyyMMdd').format(widget.fromDate)}.pdf';
      if (mounted) {
        await _showSaveOptions(context, bytes, filename, c);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e'), backgroundColor: c.pink));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showSaveOptions(BuildContext ctx, Uint8List bytes,
      String filename, ThemeProvider c) async {
    await showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Save PDF As',
                style: TextStyle(
                    color: c.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(filename,
                style: TextStyle(color: c.textLow, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            _saveOption(
              ctx,
              c,
              icon: Icons.download_rounded,
              color: c.cyan,
              title: 'Save to Downloads',
              subtitle: 'Internal storage / Downloads folder',
              onTap: () async {
                Navigator.pop(ctx);
                await _saveToDownloads(bytes, filename, c);
              },
            ),
            const SizedBox(height: 10),
            _saveOption(
              ctx,
              c,
              icon: Icons.folder_open_rounded,
              color: c.violet,
              title: 'Save to Documents',
              subtitle: 'App documents folder',
              onTap: () async {
                Navigator.pop(ctx);
                await _saveToDocuments(bytes, filename, c);
              },
            ),
            const SizedBox(height: 10),
            _saveOption(
              ctx,
              c,
              icon: Icons.share_rounded,
              color: c.amber,
              title: 'Share / Open With',
              subtitle: 'Share via WhatsApp, email, etc.',
              onTap: () async {
                Navigator.pop(ctx);
                await _sharePdf(bytes, filename, c);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveOption(
    BuildContext ctx,
    ThemeProvider c, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: c.textHigh,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(color: c.textLow, fontSize: 11)),
                ])),
            Icon(Icons.chevron_right_rounded, color: c.textLow, size: 18),
          ]),
        ),
      ),
    );
  }

  Future<void> _saveToDownloads(
      Uint8List bytes, String filename, ThemeProvider c) async {
    try {
      Directory dir = Directory('/storage/emulated/0/Download');
      if (!Platform.isAndroid || !await dir.exists()) {
        dir = await getApplicationDocumentsDirectory();
      }
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() => _savedPath = file.path);
        _showDownloadComplete(file.path, filename, c);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Save failed: $e'), backgroundColor: c.pink));
    }
  }

  Future<void> _saveToDocuments(
      Uint8List bytes, String filename, ThemeProvider c) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() => _savedPath = file.path);
        _showDownloadComplete(file.path, filename, c);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Save failed: $e'), backgroundColor: c.pink));
    }
  }

  Future<void> _sharePdf(
      Uint8List bytes, String filename, ThemeProvider c) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Share failed: $e'), backgroundColor: c.pink));
    }
  }

  void _showDownloadComplete(String path, String filename, ThemeProvider c) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _DownloadNotification(
              filename: filename,
              path: path,
              onOpen: () {
                entry.remove();
                OpenFile.open(path);
              },
              onDismiss: () => entry.remove(),
              c: c,
            ));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context, listen: false);
    final config = _cfg(widget.leaveType);
    final color = config.colorFn(c);
    final days = widget.toDate.difference(widget.fromDate).inDays + 1;
    final fmt = DateFormat('dd MMM yyyy');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.green.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: c.green.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 2)
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // ── Success icon ──────────────────────────────────────────
                  Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.green.withOpacity(0.1),
                        border: Border.all(
                            color: c.green.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: c.green.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 4)
                        ],
                      ),
                      child: Icon(Icons.check_circle_rounded,
                          color: c.green, size: 42)),
                  const SizedBox(height: 14),
                  Text('Leave Applied!',
                      style: TextStyle(
                          color: c.textHigh,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Your ${config.label} has been submitted for approval.',
                      style: TextStyle(color: c.textMid, fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  // ── Summary card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.2))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(config.icon,
                                          size: 12, color: Colors.white),
                                      const SizedBox(width: 5),
                                      Text(config.label,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    ])),
                            const Spacer(),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: c.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: c.green.withOpacity(0.35))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                              color: c.green,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: c.green
                                                        .withOpacity(0.6),
                                                    blurRadius: 4)
                                              ])),
                                      const SizedBox(width: 5),
                                      Text('SUBMITTED',
                                          style: TextStyle(
                                              color: c.green,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5)),
                                    ])),
                          ]),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: c.border),
                          const SizedBox(height: 10),
                          _infoRow(c, Icons.person_rounded, 'Student',
                              widget.student.name),
                          _infoRow(c, Icons.badge_rounded, 'Roll No',
                              widget.student.rollNo),
                          _infoRow(c, Icons.school_rounded, 'Dept',
                              widget.student.deptName),
                          _infoRow(c, Icons.date_range_rounded, 'Period',
                              '${fmt.format(widget.fromDate)} → ${fmt.format(widget.toDate)}'),
                          _infoRow(c, Icons.timelapse_rounded, 'Duration',
                              '$days day${days > 1 ? "s" : ""}'),
                          _infoRow(
                              c,
                              Icons.notes_rounded,
                              'Reason',
                              widget.reason.length > 60
                                  ? '${widget.reason.substring(0, 60)}…'
                                  : widget.reason,
                              isLast: true),
                        ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Signatures required ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Approval required from:',
                              style: TextStyle(
                                  color: c.textMid,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: config.signatures
                                  .map((s) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: color.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: color.withOpacity(0.3))),
                                        child: Text(s,
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ))
                                  .toList()),
                        ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Buttons ───────────────────────────────────────────────
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Close',
                          style: TextStyle(
                              color: c.textMid, fontWeight: FontWeight.w600)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: SizedBox(
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: _generating ? color.withOpacity(0.6) : color,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]),
                        child: ElevatedButton(
                          onPressed: _generating
                              ? null
                              : () {
                                  if (_savedPath != null) {
                                    OpenFile.open(_savedPath!);
                                  } else {
                                    _downloadPdf(c);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: _generating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Icon(
                                          _savedPath != null
                                              ? Icons.folder_open_rounded
                                              : Icons.download_rounded,
                                          size: 16,
                                          color: Colors.white),
                                      const SizedBox(width: 6),
                                      Flexible(
                                          child: Text(
                                              _savedPath != null
                                                  ? 'Open PDF'
                                                  : 'Download PDF',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ]),
                        ),
                      ),
                    )),
                  ]),
                ]),
              ),
            ),
          )),
    );
  }

  Widget _infoRow(ThemeProvider c, IconData icon, String label, String val,
          {bool isLast = false}) =>
      Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 13, color: c.textLow),
            const SizedBox(width: 7),
            SizedBox(
                width: 70,
                child: Text(label,
                    style: TextStyle(color: c.textLow, fontSize: 11))),
            Expanded(
                child: Text(val,
                    style: TextStyle(
                        color: c.textHigh,
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
          ]));
}

// ═══════════════════════════════════════════════════════════════════════════════
// MY APPLICATIONS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class MyApplicationsScreen extends StatefulWidget {
  final String rollNo, studentName;
  final Student? student;
  const MyApplicationsScreen(
      {super.key,
      required this.rollNo,
      required this.studentName,
      this.student});
  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<LeaveApplication> _all = [];
  bool _loading = true;
  String _filter = 'All', _search = '';
  static const _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    _all = await LeaveService.getLeaveApplications(widget.rollNo);
    if (mounted) setState(() => _loading = false);
  }

  List<LeaveApplication> get _filtered => _all.where((a) {
        final matchFilter = _filter == 'All' || a.status == _filter;
        final matchSearch = _search.isEmpty ||
            a.reason.toLowerCase().contains(_search.toLowerCase()) ||
            a.leaveType.toLowerCase().contains(_search.toLowerCase());
        return matchFilter && matchSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final pending = _all.where((a) => a.status == 'Pending').length;
    final approved = _all.where((a) => a.status == 'Approved').length;
    final rejected = _all.where((a) => a.status == 'Rejected').length;

    return Column(children: [
      // Stats bar
      Container(
          color: c.surface,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(children: [
            _stat(c, '${_all.length}', 'Total', c.cyan),
            _stat(c, '$pending', 'Pending', c.amber),
            _stat(c, '$approved', 'Approved', c.green),
            _stat(c, '$rejected', 'Rejected', c.pink),
          ])),

      // Filter chips
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: sel ? c.cyan : c.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? c.cyan : c.border)),
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : c.textMid)),
                    ));
              })),

      // Search
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            style: TextStyle(color: c.textHigh, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by reason or type…',
              hintStyle: TextStyle(color: c.textLow, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: c.textLow, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 18),
                  onPressed: _fetch),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.cyan)),
            ),
            onChanged: (v) => setState(() => _search = v),
          )),

      Expanded(
          child: _loading
              ? Center(
                  child:
                      CircularProgressIndicator(color: c.cyan, strokeWidth: 2))
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.inbox_rounded, size: 52, color: c.textLow),
                          const SizedBox(height: 12),
                          Text('No applications found',
                              style: TextStyle(color: c.textMid, fontSize: 13)),
                          const SizedBox(height: 14),
                          GestureDetector(
                              onTap: _fetch,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: c.cyan.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: c.cyan.withOpacity(0.3))),
                                  child: Text('Refresh',
                                      style: TextStyle(
                                          color: c.cyan,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)))),
                        ]))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: c.cyan,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _card(_filtered[i], c),
                      ))),
    ]);
  }

  Widget _stat(ThemeProvider c, String val, String label, Color color) =>
      Expanded(
          child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2))),
              child: Column(children: [
                Text(val,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: c.textMid, fontSize: 10)),
              ])));

  Widget _card(LeaveApplication app, ThemeProvider c) {
    final statusColor = app.status == 'Approved'
        ? c.green
        : app.status == 'Rejected'
            ? c.pink
            : c.amber;
    final config = _cfg(app.leaveType);
    final typeColor = config.colorFn(c);
    final fmt = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(color: typeColor.withOpacity(0.04), blurRadius: 10)
          ]),
      child: Column(children: [
        // Header
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: typeColor.withOpacity(0.05),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: typeColor.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(config.icon, size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text(config.label.toUpperCase(),
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ])),
              const Spacer(),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: statusColor.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: statusColor.withOpacity(0.5),
                                  blurRadius: 3)
                            ])),
                    const SizedBox(width: 5),
                    Text(app.status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ])),
            ])),

        // Body
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.reason.isEmpty ? '—' : app.reason,
                  style: TextStyle(
                      color: c.textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.date_range_rounded, size: 12, color: c.textLow),
                const SizedBox(width: 4),
                Text('${fmt.format(app.fromDate)} – ${fmt.format(app.toDate)}',
                    style: TextStyle(color: c.textMid, fontSize: 11)),
                const SizedBox(width: 8),
                Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: c.textLow)),
                const SizedBox(width: 8),
                Text(
                    '${app.durationDays} day${app.durationDays > 1 ? "s" : ""}',
                    style: TextStyle(
                        color: c.textMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ])),

        // Print button
        // Actions Row
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                      onTap: () => _printLeave(app, c),
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: c.elevated,
                              borderRadius: BorderRadius.circular(11),
                              border:
                                  Border.all(color: c.cyan.withOpacity(0.3))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 14, color: c.cyan),
                                const SizedBox(width: 6),
                                Text('Download PDF',
                                    style: TextStyle(
                                        color: c.cyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ])))),
              if (app.canCancel) ...[
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: () => _showEditDialog(app, c),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                            color: c.cyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: c.cyan.withOpacity(0.3))),
                        child:
                            Icon(Icons.edit_rounded, size: 16, color: c.cyan))),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: () => _confirmCancel(app, c),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                            color: c.pink.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: c.pink.withOpacity(0.3))),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 16, color: c.pink))),
              ],
            ])),
      ]),
    );
  }

  // ── Confirm cancel dialog ─────────────────────────────────────────────────
  Future<void> _confirmCancel(LeaveApplication app, ThemeProvider c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.pink.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: c.pink.withOpacity(0.1), blurRadius: 24)
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.pink.withOpacity(0.1),
                    border: Border.all(color: c.pink.withOpacity(0.3))),
                child: Icon(Icons.delete_forever_rounded,
                    color: c.pink, size: 30)),
            const SizedBox(height: 14),
            Text('Cancel Leave Application',
                style: TextStyle(
                    color: c.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                'This will permanently cancel your ${_cfg(app.leaveType).label} application. This cannot be undone.',
                style: TextStyle(color: c.textMid, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Keep it',
                          style: TextStyle(
                              color: c.textMid, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 15),
                            SizedBox(width: 5),
                            Text('Cancel Leave',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13))
                          ]))),
            ]),
          ]),
        ),
      ),
    );
    if (confirm != true || !mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: c.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: c.pink, strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text('Cancelling leave…',
                      style: TextStyle(color: c.textMid, fontSize: 13))
                ]))));
    final res =
        await LeaveService.cancelLeave(rollNo: widget.rollNo, leaveId: app.id);
    if (mounted) Navigator.pop(context);
    if (res['success'] == true) {
      _snack(res['message'] ?? 'Leave cancelled successfully', c);
      await _fetch();
    } else {
      _snack(res['message'] ?? 'Failed to cancel leave', c, err: true);
    }
  }

  void _snack(String msg, ThemeProvider c, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(
                err
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
          ]),
          backgroundColor: err ? c.pink : c.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4)));

  // ── Edit dialog ───────────────────────────────────────────────────────────
  Future<void> _showEditDialog(LeaveApplication app, ThemeProvider c) async {
    DateTime? from = app.fromDate;
    DateTime? to = app.toDate;
    String leaveType = app.leaveType;
    final reasonCtrl = TextEditingController(text: app.reason);
    bool updating = false;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => Container(
                margin: const EdgeInsets.only(top: 60),
                decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: c.border)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                      child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: c.border,
                              borderRadius: BorderRadius.circular(2)))),
                  Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.edit_rounded, color: c.cyan, size: 20),
                              const SizedBox(width: 8),
                              Text('Edit Leave Application',
                                  style: TextStyle(
                                      color: c.textHigh,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900))
                            ]),
                            const SizedBox(height: 20),
                            Text('Leave Type',
                                style: TextStyle(
                                    color: c.textMid,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _leaveTypes.map((t) {
                                  final sel = leaveType == t.value;
                                  final col = t.colorFn(c);
                                  return GestureDetector(
                                      onTap: () =>
                                          setS(() => leaveType = t.value),
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                              color: sel
                                                  ? col.withOpacity(0.12)
                                                  : c.elevated,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: sel ? col : c.border,
                                                  width: sel ? 1.5 : 1)),
                                          child: Text(t.label,
                                              style: TextStyle(
                                                  color: sel ? col : c.textMid,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w700))));
                                }).toList()),
                            const SizedBox(height: 16),
                            Text('Leave Period',
                                style: TextStyle(
                                    color: c.textMid,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _editDatePicker(ctx, c, 'From', from,
                                      (d) => setS(() => from = d))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _editDatePicker(ctx, c, 'To', to,
                                      (d) => setS(() => to = d))),
                            ]),
                            const SizedBox(height: 16),
                            Text('Reason',
                                style: TextStyle(
                                    color: c.textMid,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: reasonCtrl,
                                maxLines: 3,
                                style:
                                    TextStyle(color: c.textHigh, fontSize: 13),
                                decoration: InputDecoration(
                                    hintText: 'Enter reason…',
                                    hintStyle: TextStyle(color: c.textLow),
                                    filled: true,
                                    fillColor: c.elevated,
                                    contentPadding: const EdgeInsets.all(12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: c.border)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: c.border)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: c.cyan, width: 1.5)))),
                            const SizedBox(height: 20),
                            SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [c.cyan, c.violet]),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: ElevatedButton(
                                        onPressed: updating
                                            ? null
                                            : () async {
                                                if (from == null ||
                                                    to == null ||
                                                    reasonCtrl.text
                                                        .trim()
                                                        .isEmpty) return;
                                                setS(() => updating = true);
                                                final res = await LeaveService
                                                    .updateLeave(
                                                        rollNo: widget.rollNo,
                                                        leaveId: app.id,
                                                        leaveType: leaveType,
                                                        startDate: from!,
                                                        endDate: to!,
                                                        reason: reasonCtrl.text
                                                            .trim());
                                                if (ctx.mounted)
                                                  Navigator.pop(ctx);
                                                if (res['success'] == true) {
                                                  _snack(
                                                      res['message'] ??
                                                          'Updated successfully',
                                                      c);
                                                  await _fetch();
                                                } else {
                                                  _snack(
                                                      res['message'] ??
                                                          'Update failed',
                                                      c,
                                                      err: true);
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14))),
                                        child: updating
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                    Icon(Icons.save_rounded,
                                                        size: 17,
                                                        color: Colors.white),
                                                    SizedBox(width: 8),
                                                    Text('Save Changes',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800))
                                                  ])))),
                          ])),
                ]))));
    reasonCtrl.dispose();
  }

  Widget _editDatePicker(BuildContext ctx, ThemeProvider c, String label,
          DateTime? val, Function(DateTime) onPick) =>
      GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
                context: ctx,
                initialDate: val ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime(2030),
                builder: (c2, child) =>
                    Theme(data: c.themeData, child: child!));
            if (picked != null) onPick(picked);
          },
          child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: val != null ? c.cyan.withOpacity(0.4) : c.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: c.textLow,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.event_rounded,
                          size: 13, color: val != null ? c.cyan : c.textLow),
                      const SizedBox(width: 5),
                      Text(
                          val != null
                              ? DateFormat('dd/MM/yyyy').format(val)
                              : 'Pick date',
                          style: TextStyle(
                              color: val != null ? c.textHigh : c.textLow,
                              fontSize: 12,
                              fontWeight: val != null
                                  ? FontWeight.w700
                                  : FontWeight.w400))
                    ])
                  ])));

  Future<void> _printLeave(LeaveApplication app, ThemeProvider c) async {
    final student =
        widget.student ?? await LeaveService.getStudentData(widget.rollNo);
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not load student data'),
          backgroundColor: c.pink));
      return;
    }
    try {
      Uint8List? logo;
      try {
        final d = await rootBundle.load('assets/bhclogo.png');
        logo = d.buffer.asUint8List();
      } catch (_) {}
      final bytes = await LeavePdfGenerator.generate(
        student: student,
        leaveType: app.leaveType,
        fromDate: app.fromDate,
        toDate: app.toDate,
        reason: app.reason,
        logoBytes: logo,
      );
      final fname =
          'BHC_Leave_${app.rollNo}_${DateFormat('yyyyMMdd').format(app.fromDate)}.pdf';
      if (mounted) {
        await _showSaveOptionsStandalone(context, bytes, fname, c);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e'), backgroundColor: c.pink));
    }
  }

  Widget _saveOption(
    BuildContext ctx,
    ThemeProvider c, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: c.textHigh,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(color: c.textLow, fontSize: 11)),
                ])),
            Icon(Icons.chevron_right_rounded, color: c.textLow, size: 18),
          ]),
        ),
      ),
    );
  }

  void _showDownloadComplete(String path, String filename, ThemeProvider c) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _DownloadNotification(
              filename: filename,
              path: path,
              onOpen: () {
                entry.remove();
                OpenFile.open(path);
              },
              onDismiss: () => entry.remove(),
              c: c,
            ));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _showSaveOptionsStandalone(BuildContext ctx, Uint8List bytes,
      String filename, ThemeProvider c) async {
    await showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Save PDF As',
                style: TextStyle(
                    color: c.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(filename,
                style: TextStyle(color: c.textLow, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            _saveOption(ctx, c,
                icon: Icons.download_rounded,
                color: c.cyan,
                title: 'Save to Downloads',
                subtitle: 'Internal storage / Downloads folder',
                onTap: () async {
              Navigator.pop(ctx);
              try {
                Directory dir = Directory('/storage/emulated/0/Download');
                if (!Platform.isAndroid || !await dir.exists())
                  dir = await getApplicationDocumentsDirectory();
                final file = File('${dir.path}/$filename');
                await file.writeAsBytes(bytes);
                if (mounted) _showDownloadComplete(file.path, filename, c);
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Save failed: $e'),
                      backgroundColor: c.pink));
              }
            }),
            const SizedBox(height: 10),
            _saveOption(ctx, c,
                icon: Icons.share_rounded,
                color: c.amber,
                title: 'Share / Open With',
                subtitle: 'Share via WhatsApp, email, etc.', onTap: () async {
              Navigator.pop(ctx);
              try {
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/$filename');
                await file.writeAsBytes(bytes);
                await OpenFile.open(file.path);
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Share failed: $e'),
                      backgroundColor: c.pink));
              }
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOWNLOAD COMPLETE NOTIFICATION OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════

class _DownloadNotification extends StatefulWidget {
  final String filename, path;
  final VoidCallback onOpen, onDismiss;
  final ThemeProvider c;
  const _DownloadNotification({
    required this.filename,
    required this.path,
    required this.onOpen,
    required this.onDismiss,
    required this.c,
  });
  @override
  State<_DownloadNotification> createState() => _DownloadNotificationState();
}

class _DownloadNotificationState extends State<_DownloadNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.elevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.cyan.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.cyan.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.download_done_rounded,
                      color: c.cyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Download Complete',
                          style: TextStyle(
                              color: c.textHigh,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(widget.filename,
                          style: TextStyle(color: c.textLow, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ])),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onOpen,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.cyan,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Open',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Icon(Icons.close_rounded, color: c.textLow, size: 18),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
     