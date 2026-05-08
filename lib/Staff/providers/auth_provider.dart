import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

enum UserRole { staff, hod, admin }

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  UserRole? _userRole;
  String? _accessToken;
  String? _refreshToken;

  // API Configuration - Correct endpoints
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

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get userData => _userData;
  UserRole? get userRole => _userRole;
  String? get accessToken => _accessToken;

  // Initialize method to load saved auth data
  Future<void> init() async {
    print('🚀 AuthProvider initializing...');
    await _loadSavedAuth();
  }

  // Load saved authentication data from SharedPreferences
  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('access_token');
      final savedUserData = prefs.getString('user_data');
      final savedRole = prefs.getString('user_role');

      print('📂 Loading saved auth data:');
      print('  - Token: ${savedToken != null ? "Present" : "Missing"}');
      print('  - User Data: ${savedUserData != null ? "Present" : "Missing"}');
      print('  - Role: $savedRole');

      if (savedToken != null && savedUserData != null && savedRole != null) {
        try {
          _accessToken = savedToken;
          _userData = json.decode(savedUserData);
          _userRole = _parseUserRole(savedRole);
          _isAuthenticated = true;

          print('✅ Restored saved session');
          print('  - User: ${_userData?['name']}');
          print('  - Role: $_userRole');
          print('  - Staff ID: ${_userData?['staff_id']}');
        } catch (e) {
          print('❌ Error parsing saved data: $e');
          await _clearSavedAuth();
          _isAuthenticated = false;
        }
      } else {
        print('ℹ️ No saved session found');
        _isAuthenticated = false;
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error loading saved auth: $e');
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  UserRole _parseUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'hod':
        return UserRole.hod;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }

  // 🔑 Login with Staff ID and DOB
  Future<void> loginWithStaffIdAndDOB(String staffId, String dob) async {
    try {
      final cleanStaffId = staffId.trim().toUpperCase();
      final cleanDOB = dob.trim();

      print('🔐 Attempting login with Staff ID: $cleanStaffId, DOB: $cleanDOB');

      // Try all base URLs
      Map<String, dynamic>? staffData;
      String? foundUrl;

      for (final baseUrl in _baseUrls) {
        try {
          final response = await http
              .get(
                Uri.parse('$baseUrl/staff/$cleanStaffId'),
                headers: _apiHeaders,
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('✅ Found staff data at: $baseUrl');
            staffData = data;
            foundUrl = baseUrl;
            break;
          }
        } catch (e) {
          print('❌ Failed at $baseUrl: $e');
          continue;
        }
      }

      if (staffData == null) {
        throw Exception(
            'Staff ID not found in system. Please check your Staff ID.');
      }

      // Extract real data from API response
      final apiStaffId = staffData['staff_id']?.toString() ?? '';
      final apiDOB = staffData['dob']?.toString() ?? '';
      final apiName = staffData['name']?.toString() ?? 'Staff Member';
      final apiEmail = staffData['college_email']?.toString() ??
          staffData['email']?.toString() ??
          'staff@bhc.edu.in';

      // Validate DOB
      if (cleanDOB != apiDOB) {
        print('❌ DOB mismatch');
        print('  Entered: $cleanDOB');
        print('  Actual: $apiDOB');
        throw Exception('Incorrect Date of Birth. Please check your DOB.');
      }

      // Determine role
      final role = _determineUserRole(staffData, apiEmail);

      // Generate token
      final token = _generateToken(apiEmail, cleanStaffId);

      // Save data
      await _saveAuthData(
        token: token,
        userData: {
          'staff_id': cleanStaffId,
          'name': apiName,
          'college_email': apiEmail,
          'dob': apiDOB,
          'designation': staffData['designation']?.toString() ?? '',
          'department': staffData['department']?.toString() ?? '',
          'phone': staffData['phone']?.toString() ?? '',
          'api_url': foundUrl,
          ...staffData,
        },
        role: role,
      );

      _accessToken = token;
      _userData = staffData;
      _userRole = role;
      _isAuthenticated = true;

      print('✅ Login successful!');
      print('  - Name: $apiName');
      print('  - Staff ID: $cleanStaffId');
      print('  - Role: $role');
      print('  - Email: $apiEmail');

      notifyListeners();
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  UserRole _determineUserRole(Map<String, dynamic> staffData, String email) {
    final cleanEmail = email.trim().toLowerCase();
    final staffId = staffData['staff_id']?.toString() ?? '';

    // Check from API data
    if (staffData['is_admin'] == true ||
        staffId.contains('ADM') ||
        cleanEmail.contains('admin@')) {
      return UserRole.admin;
    }

    if (staffData['is_hod'] == true ||
        staffId.contains('HOD') ||
        cleanEmail.contains('hod.')) {
      return UserRole.hod;
    }

    final designation =
        (staffData['designation']?.toString() ?? '').toLowerCase();
    if (designation.contains('head') || designation.contains('hod')) {
      return UserRole.hod;
    }

    return UserRole.staff; // Default
  }

  String _generateToken(String email, String staffId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data =
        '$email:$staffId:$timestamp:${DateTime.now().toIso8601String()}';
    return base64.encode(utf8.encode(data));
  }

  // Save auth data to persistent storage
  Future<void> _saveAuthData({
    required String token,
    required Map<String, dynamic> userData,
    required UserRole role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('user_data', json.encode(userData));

      final roleString = role.toString().split('.').last;
      await prefs.setString('user_role', roleString);

      print('💾 Saved auth data to storage');
      print('  - Role: $roleString');
    } catch (e) {
      print('❌ Error saving auth data: $e');
    }
  }

  // OTP Login Method
  Future<void> loginWithOTP(Map<String, dynamic> userData) async {
    try {
      print('✅ OTP Login attempt');
      print('  - Data received: $userData');

      // Extract data
      final staffId = userData['staff_id']?.toString() ?? '';
      final name = userData['name']?.toString() ?? 'Staff Member';
      final email = userData['email']?.toString() ??
          userData['college_email']?.toString() ??
          'staff@bhc.edu.in';

      if (staffId.isEmpty) {
        throw Exception('Invalid staff data received');
      }

      // Determine role
      final role = _determineUserRole(userData, email);

      // Generate token
      final token = _generateToken(email, staffId);

      // Prepare complete user data
      final completeUserData = {
        'staff_id': staffId,
        'name': name,
        'college_email': email,
        'email': email,
        'login_method': 'otp',
        'login_time': DateTime.now().toIso8601String(),
        ...userData,
      };

      // Save auth data
      await _saveAuthData(
        token: token,
        userData: completeUserData,
        role: role,
      );

      _accessToken = token;
      _userData = completeUserData;
      _userRole = role;
      _isAuthenticated = true;

      print('✅ OTP Login successful!');
      print('  - Staff ID: $staffId');
      print('  - Name: $name');
      print('  - Role: $role');

      notifyListeners();
    } catch (e) {
      print('❌ Error in loginWithOTP: $e');
      rethrow;
    }
  }

  // Logout method
  Future<void> logout() async {
    await _clearSavedAuth();

    _isAuthenticated = false;
    _userData = null;
    _userRole = null;
    _accessToken = null;
    _refreshToken = null;

    notifyListeners();
    print('✅ Logged out successfully');
  }

  // Clear saved auth data
  Future<void> _clearSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_data');
      await prefs.remove('user_role');
      print('🗑️ Cleared saved auth data');
    } catch (e) {
      print('❌ Error clearing auth data: $e');
    }
  }

  // Check token validity
  Future<bool> checkAuthValidity() async {
    try {
      if (!_isAuthenticated || _accessToken == null || _userData == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('access_token');

      if (savedToken == null || savedToken != _accessToken) {
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking auth validity: $e');
      await logout();
      return false;
    }
  }
}
