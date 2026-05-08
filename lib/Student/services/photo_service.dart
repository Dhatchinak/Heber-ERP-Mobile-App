import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PhotoService {
  static const String baseUrl = 'https://apierp.bhc.edu.in/photo/student/';
  static const String referer = 'http://117.232.64.75';

  static const Map<String, String> headers = {
    'Referer': 'http://117.232.64.75',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
    'Accept': 'image/*,*/*',
  };

  static String? _currentRollNo;

  // Cache for in-memory storage
  static final Map<String, String> _memoryCache = {};
  static const Duration timeout = Duration(seconds: 10);

  static void setCurrentStudent(String rollNo) {
    if (rollNo.trim().isNotEmpty) _currentRollNo = rollNo.trim();
  }

  static String? get currentRollNo => _currentRollNo;

  static String buildApiUrl(String rollNo) => '$baseUrl${rollNo.trim()}';

  /// Get the actual image URL from the API
  static Future<String?> getStudentPhotoUrl([String? rollNo]) async {
    final r = (rollNo ?? _currentRollNo)?.trim();
    if (r == null || r.isEmpty) return null;

    // Check memory cache first
    if (_memoryCache.containsKey(r)) {
      return _memoryCache[r];
    }

    try {
      final apiUrl = buildApiUrl(r);

      // Make the API request
      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {
              'Referer': referer,
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
              'Accept': 'application/json', // Important: Accept JSON, not image
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        // Parse the JSON response
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['view_url'] != null) {
          final imageUrl = data['view_url'] as String;
          _memoryCache[r] = imageUrl;
          return imageUrl;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching photo URL for $r: $e');
      return null;
    }
  }

  /// Cache the photo URL for offline use
  static Future<void> cacheStudentPhoto([String? rollNo]) async {
    final r = (rollNo ?? _currentRollNo)?.trim();
    if (r == null || r.isEmpty) return;

    try {
      final photoUrl = await getStudentPhotoUrl(r);
      final prefs = await SharedPreferences.getInstance();

      if (photoUrl != null) {
        await prefs.setString('student_photo_url_$r', photoUrl);
        _memoryCache[r] = photoUrl;
      } else {
        await prefs.remove('student_photo_url_$r');
        _memoryCache.remove(r);
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Get cached photo URL
  static Future<String?> getCachedPhotoUrl([String? rollNo]) async {
    final r = (rollNo ?? _currentRollNo)?.trim();
    if (r == null || r.isEmpty) return null;

    // Check memory cache first
    if (_memoryCache.containsKey(r)) {
      return _memoryCache[r];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('student_photo_url_$r');
      if (cached != null) {
        _memoryCache[r] = cached;
      }
      return cached;
    } catch (e) {
      return null;
    }
  }

  /// Sync version for immediate access (uses memory cache only)
  static String? getCachedPhotoUrlSync([String? rollNo]) {
    final r = (rollNo ?? _currentRollNo)?.trim();
    if (r == null || r.isEmpty) return null;
    return _memoryCache[r];
  }

  static Future<void> clearCachedPhoto([String? rollNo]) async {
    final r = (rollNo ?? _currentRollNo)?.trim();
    if (r == null || r.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('student_photo_url_$r');
      _memoryCache.remove(r);
    } catch (_) {}
  }

  static Future<void> clearAllCachedPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('student_photo_url_'),
      );
      for (final key in keys) await prefs.remove(key);
      _memoryCache.clear();
    } catch (_) {}
  }
}
