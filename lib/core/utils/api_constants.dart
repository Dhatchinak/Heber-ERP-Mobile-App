class ApiConstants {
  // ── Base URLs ─────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://apierp.bhc.edu.in';
  static const String _frontendOrigin = 'http://117.232.64.75';
  static const String _staffPortal = 'https://stafferp.bhc.edu.in/';

  // ── Student APIs ──────────────────────────────────────────────────────────
  static const String studentBase = '$baseUrl/api/students';
  static const String studentAttendance = '$studentBase/attendance';
  static const String studentExams = '$studentBase/exams/ese';
  static const String studentSeating = '$studentBase/exams/seating';
  static const String studentVerifyDob = '$studentBase/verify-dob';

  // ── Staff APIs ────────────────────────────────────────────────────────────
  static const String staffBase = '$baseUrl/api';
  static const String staffLogin = '$staffBase/auth/login';
  static const String staffSendOtp = '$baseUrl/staff/login'; // GET /<staffId>
  static const String staffVerifyOtp = '$staffBase/staff/login/otp'; // POST
  static const String staffProfile = '$staffBase/staff/profile';
  static const String staffMentorship = '$staffBase/staff/mentorship';

  // ── Common ────────────────────────────────────────────────────────────────
  static const String academicCalendar = '$baseUrl/api/academic_calendar';
  static const String photoUrl = '$baseUrl/photo/student';

  // ── Headers ───────────────────────────────────────────────────────────────

  /// For /staff/login/<id> and /api/staff/* lookups (portal origin)
  static Map<String, String> get headers => {
        'Referer': _staffPortal,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// For /api/staff/login/otp (OTP verify) — requires frontend IP as Referer
  static Map<String, String> get otpHeaders => {
        'Referer': _frontendOrigin,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...headers,
        'Authorization': 'Bearer $token',
      };
}
