class ApiConstants {
  static const String baseUrl = 'https://apierp.bhc.edu.in';
  static const String refererUrl = 'http://117.232.64.75';

  // Student APIs
  static const String studentBase = '$baseUrl/api/students';
  static const String studentAttendance = '$studentBase/attendance';
  static const String studentExams = '$studentBase/exams/ese';
  static const String studentSeating = '$studentBase/exams/seating';
  static const String studentProfile = '$studentBase';

  // Staff APIs
  static const String staffBase = '$baseUrl/api';
  static const String staffLogin = '$staffBase/auth/login';
  static const String staffSendOtp = '$staffBase/auth/send-otp';
  static const String staffVerifyOtp = '$staffBase/auth/verify-otp';
  static const String staffProfile = '$staffBase/staff/profile';
  static const String staffMentorship = '$staffBase/staff/mentorship';

  // Common
  static const String academicCalendar = '$baseUrl/api/academic_calendar';
  static const String photoUrl = '$baseUrl/photo/student';

  static Map<String, String> get headers => {
        'Referer': refererUrl,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
}