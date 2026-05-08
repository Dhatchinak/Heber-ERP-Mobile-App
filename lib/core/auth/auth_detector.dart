import 'user_type.dart';

class AuthDetector {
  static const List<String> staffDomains = ['bhc.edu.in', 'bhc.ac.in'];
  static const List<String> staffEmailPatterns = [
    'staff',
    'faculty',
    'teacher',
    'professor',
  ];

  static UserType detect(String email) {
    email = email.trim().toLowerCase();

    // Check for staff domain
    for (final domain in staffDomains) {
      if (email.endsWith('@$domain')) {
        return UserType.staff;
      }
    }

    // Check for staff patterns in email
    for (final pattern in staffEmailPatterns) {
      if (email.contains(pattern)) {
        return UserType.staff;
      }
    }

    // Check if email looks like a roll number (e.g., 22MCS001@...)
    final localPart = email.split('@').first;
    if (localPart.contains(RegExp(r'^\d{2}[A-Z]{3}\d{3}$'))) {
      return UserType.student;
    }

    // Default to student
    return UserType.student;
  }

  static String? extractRollNo(String email) {
    final localPart = email.split('@').first;
    if (localPart.contains(RegExp(r'^\d{2}[A-Z]{3}\d{3}$'))) {
      return localPart.toUpperCase();
    }
    return null;
  }

  static bool isValidStudentEmail(String email) {
    final rollNo = extractRollNo(email);
    return rollNo != null && rollNo.length >= 8;
  }
}