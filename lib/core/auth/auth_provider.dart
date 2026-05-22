import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_type.dart';
import '../utils/api_constants.dart';

// UserRole alias kept for backward compatibility with existing Staff screens
enum UserRole { staff, hod, admin }

// Keys stored in SharedPreferences — only these are touched on logout
class _PrefKeys {
  static const accessToken  = 'auth_access_token';
  static const userData     = 'auth_user_data';
  static const userType     = 'auth_user_type';
  static const rollNo       = 'auth_roll_no';
  static const studentName  = 'auth_student_name';
  static const studentDob   = 'auth_student_dob';
}

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading       = false;
  String? _accessToken;
  Map<String, dynamic>? _userData;
  UserType _userType = UserType.unknown;

  // Student fields
  String? _studentRollNo;
  String? _studentName;
  String? _studentDob;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading       => _isLoading;
  String? get accessToken  => _accessToken;
  Map<String, dynamic>? get userData => _userData;
  UserType get userType    => _userType;
  String? get studentRollNo => _studentRollNo;
  String? get studentName   => _studentName;
  String? get studentDob    => _studentDob;

  /// Convenience getter used by Staff screens
  UserRole get userRole {
    switch (_userType) {
      case UserType.hod:   return UserRole.hod;
      case UserType.admin: return UserRole.admin;
      default:             return UserRole.staff;
    }
  }

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
      final savedToken    = prefs.getString(_PrefKeys.accessToken);
      final savedUserData = prefs.getString(_PrefKeys.userData);
      final savedType     = prefs.getString(_PrefKeys.userType);

      _studentRollNo = prefs.getString(_PrefKeys.rollNo);
      _studentName   = prefs.getString(_PrefKeys.studentName);
      _studentDob    = prefs.getString(_PrefKeys.studentDob);
      _userType      = UserTypeExtension.fromString(savedType ?? 'unknown');

      if (savedToken != null && savedToken.isNotEmpty && savedUserData != null) {
        try {
          _accessToken     = savedToken;
          _userData        = json.decode(savedUserData) as Map<String, dynamic>;
          _isAuthenticated = true;
        } catch (e) {
          debugPrint('AuthProvider: failed to parse saved session — $e');
          await _clearAuthPrefs();
        }
      } else if (_studentRollNo != null && _studentRollNo!.isNotEmpty) {
        _isAuthenticated = true;
      }
    } catch (e) {
      debugPrint('AuthProvider: init error — $e');
    }
  }

  // ── Staff DOB login ───────────────────────────────────────────────────────
  // NOTE: DOB comparison is performed server-side via a POST to staffLogin.
  // If your backend doesn't have a dedicated auth endpoint yet, use staffLogin
  // and pass credentials in the body — never fetch the full profile and compare client-side.
  Future<void> loginWithStaffIdAndDOB(String staffId, String dob) async {
    final cleanId  = staffId.trim().toUpperCase();
    final cleanDob = dob.trim();

    final res = await http
        .post(
          Uri.parse(ApiConstants.staffLogin),
          headers: ApiConstants.headers,
          body: json.encode({'staff_id': cleanId, 'dob': cleanDob}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final msg = _parseError(res.body) ?? 'Login failed (${res.statusCode})';
      throw Exception(msg);
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    // Backend should return { token, user: {...} }
    final token    = body['token']?.toString() ?? body['access_token']?.toString() ?? '';
    final userData = (body['user'] ?? body['data'] ?? body) as Map<String, dynamic>;

    if (token.isEmpty) throw Exception('Server did not return a token.');

    final type = _detectUserType(userData, userData['college_email']?.toString() ?? '');
    await _persistStaffSession(token: token, userData: userData, userType: type);
    _accessToken     = token;
    _userData        = userData;
    _userType        = type;
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

    // Token should come from the server OTP verification response.
    // If it's already in userData (from verify-otp response), use it.
    final token = userData['token']?.toString() ??
        userData['access_token']?.toString() ?? '';
    if (token.isEmpty) throw Exception('No token in OTP response.');

    final fullData = {
      'login_method': 'otp',
      'login_time': DateTime.now().toIso8601String(),
      ...userData,
    };

    await _persistStaffSession(token: token, userData: fullData, userType: type);
    _accessToken     = token;
    _userData        = fullData;
    _userType        = type;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── saveStaffSession (called by OTPLoginScreen) ───────────────────────────
  Future<void> saveStaffSession({
    required String accessToken,
    required String refreshToken, // stored for future use
    required Map<String, dynamic> userData,
  }) async {
    final email = userData['college_email']?.toString() ??
        userData['email']?.toString() ?? '';
    final type  = _detectUserType(userData, email);

    await _persistStaffSession(token: accessToken, userData: userData, userType: type);
    _accessToken     = accessToken;
    _userData        = userData;
    _userType        = type;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── Student session ───────────────────────────────────────────────────────
  // Call this ONLY after server-side DOB verification has succeeded.
  Future<void> saveStudentSession({
    required String rollNo,
    required String name,
    required String dob,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.userType,     UserType.student.stringValue);
    await prefs.setString(_PrefKeys.rollNo,       rollNo);
    await prefs.setString(_PrefKeys.studentName,  name);
    await prefs.setString(_PrefKeys.studentDob,   dob);

    _studentRollNo   = rollNo;
    _studentName     = name;
    _studentDob      = dob;
    _userType        = UserType.student;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _clearAuthPrefs(); // only removes auth keys, not all prefs
    _isAuthenticated = false;
    _accessToken     = null;
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

  String? _parseError(String body) {
    try {
      final decoded = json.decode(body) as Map<String, dynamic>;
      return decoded['message']?.toString() ??
             decoded['error']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistStaffSession({
    required String token,
    required Map<String, dynamic> userData,
    required UserType userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.accessToken, token);
    await prefs.setString(_PrefKeys.userData,    json.encode(userData));
    await prefs.setString(_PrefKeys.userType,    userType.stringValue);
  }

  /// Removes only authentication-related keys — never wipes all prefs.
  Future<void> _clearAuthPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefKeys.accessToken);
    await prefs.remove(_PrefKeys.userData);
    await prefs.remove(_PrefKeys.userType);
    await prefs.remove(_PrefKeys.rollNo);
    await prefs.remove(_PrefKeys.studentName);
    await prefs.remove(_PrefKeys.studentDob);
  }
}
