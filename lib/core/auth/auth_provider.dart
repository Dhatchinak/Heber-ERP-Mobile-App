import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_type.dart';

// Keep UserRole as an alias so existing Staff code compiles without changes
enum UserRole { staff, hod, admin }

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userData;
  UserType _userType = UserType.unknown;

  // Student-specific fields
  String? _studentRollNo;
  String? _studentName;
  String? _studentDob;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get userData => _userData;
  UserType get userType => _userType;
  String? get studentRollNo => _studentRollNo;
  String? get studentName => _studentName;
  String? get studentDob => _studentDob;

  /// Convenience getter used by Staff screens
  UserRole get userRole {
    switch (_userType) {
      case UserType.hod:   return UserRole.hod;
      case UserType.admin: return UserRole.admin;
      default:             return UserRole.staff;
    }
  }

  // ── API config (used by Staff login) ─────────────────────────────────────
  static const List<String> _baseUrls = [
    'http://117.232.64.75/api',
    'http://117.232.64.75',
    'http://10.240.151.162/api',
    'http://10.240.151.162',
  ];

  static const Map<String, String> _apiHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'BHC-ERP-Mobile/1.0',
  };

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await _loadSavedAuth();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken    = prefs.getString('access_token');
      final savedUserData = prefs.getString('user_data');
      final savedType     = prefs.getString('user_type');
      _studentRollNo = prefs.getString('rollNo');
      _studentName   = prefs.getString('studentName');
      _studentDob    = prefs.getString('dob');

      _userType = UserTypeExtension.fromString(savedType ?? 'unknown');

      if (savedToken != null && savedToken.isNotEmpty && savedUserData != null) {
        try {
          _accessToken = savedToken;
          _userData = json.decode(savedUserData) as Map<String, dynamic>;
          _isAuthenticated = true;
        } catch (_) {
          await _clearPrefs();
        }
      } else if (_studentRollNo != null && _studentRollNo!.isNotEmpty) {
        _isAuthenticated = true;
      }
    } catch (_) {}
  }

  // ── Staff login (DOB) ─────────────────────────────────────────────────────
  Future<void> loginWithStaffIdAndDOB(String staffId, String dob) async {
    final cleanId  = staffId.trim().toUpperCase();
    final cleanDob = dob.trim();

    Map<String, dynamic>? staffData;
    String? foundUrl;

    for (final base in _baseUrls) {
      try {
        final res = await http
            .get(Uri.parse('$base/staff/$cleanId'), headers: _apiHeaders)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          staffData = json.decode(res.body) as Map<String, dynamic>;
          foundUrl = base;
          break;
        }
      } catch (_) {}
    }

    if (staffData == null) {
      throw Exception('Staff ID not found. Please check your Staff ID.');
    }

    final apiDob = staffData['dob']?.toString() ?? '';
    if (cleanDob != apiDob) {
      throw Exception('Incorrect Date of Birth.');
    }

    final email = staffData['college_email']?.toString() ??
        staffData['email']?.toString() ?? '';
    final type  = _detectUserType(staffData, email);
    final token = _generateToken(email, cleanId);

    final fullData = {
      'staff_id': cleanId,
      'api_url': foundUrl,
      ...staffData,
    };

    await _persistStaffSession(token: token, userData: fullData, userType: type);
    _accessToken = token;
    _userData    = fullData;
    _userType    = type;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── Staff OTP login ───────────────────────────────────────────────────────
  Future<void> loginWithOTP(Map<String, dynamic> userData) async {
    final staffId = userData['staff_id']?.toString() ?? '';
    if (staffId.isEmpty) throw Exception('Invalid staff data.');

    final email = userData['college_email']?.toString() ??
        userData['email']?.toString() ?? '';
    final type  = _detectUserType(userData, email);
    final token = _generateToken(email, staffId);

    final fullData = {
      'login_method': 'otp',
      'login_time': DateTime.now().toIso8601String(),
      ...userData,
    };

    await _persistStaffSession(token: token, userData: fullData, userType: type);
    _accessToken = token;
    _userData    = fullData;
    _userType    = type;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── saveStaffSession (called by OTPLoginScreen / other screens) ───────────
  Future<void> saveStaffSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> userData,
  }) async {
    final email = userData['college_email']?.toString() ??
        userData['email']?.toString() ?? '';
    final type = _detectUserType(userData, email);

    await _persistStaffSession(
        token: accessToken, userData: userData, userType: type);
    _accessToken  = accessToken;
    _refreshToken = refreshToken;
    _userData     = userData;
    _userType     = type;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── Student session ───────────────────────────────────────────────────────
  Future<void> saveStudentSession({
    required String rollNo,
    required String name,
    required String dob,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_type', UserType.student.stringValue);
    await prefs.setString('rollNo', rollNo);
    await prefs.setString('studentName', name);
    await prefs.setString('dob', dob);

    _studentRollNo   = rollNo;
    _studentName     = name;
    _studentDob      = dob;
    _userType        = UserType.student;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _clearPrefs();
    _isAuthenticated = false;
    _accessToken     = null;
    _refreshToken    = null;
    _userData        = null;
    _userType        = UserType.unknown;
    _studentRollNo   = null;
    _studentName     = null;
    _studentDob      = null;
    notifyListeners();
  }

  void setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  UserType _detectUserType(Map<String, dynamic> data, String email) {
    final id          = data['staff_id']?.toString() ?? '';
    final designation = (data['designation']?.toString() ?? '').toLowerCase();
    final lowerEmail  = email.toLowerCase();

    if (data['is_admin'] == true || id.contains('ADM') ||
        lowerEmail.contains('admin@')) return UserType.admin;

    if (data['is_hod'] == true || id.contains('HOD') ||
        lowerEmail.contains('hod.') ||
        designation.contains('head') || designation.contains('hod')) {
      return UserType.hod;
    }

    return UserType.staff;
  }

  String _generateToken(String email, String staffId) {
    final data = '$email:$staffId:${DateTime.now().millisecondsSinceEpoch}';
    return base64.encode(utf8.encode(data));
  }

  Future<void> _persistStaffSession({
    required String token,
    required Map<String, dynamic> userData,
    required UserType userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_data', json.encode(userData));
    await prefs.setString('user_type', userType.stringValue);
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}