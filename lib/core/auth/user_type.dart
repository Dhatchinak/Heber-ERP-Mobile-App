enum UserType { student, staff, hod, admin, unknown }

extension UserTypeExtension on UserType {
  String get stringValue {
    switch (this) {
      case UserType.student: return 'student';
      case UserType.staff:   return 'staff';
      case UserType.hod:     return 'hod';
      case UserType.admin:   return 'admin';
      case UserType.unknown: return 'unknown';
    }
  }

  static UserType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'student': return UserType.student;
      case 'staff':   return UserType.staff;
      case 'hod':     return UserType.hod;
      case 'admin':   return UserType.admin;
      default:        return UserType.unknown;
    }
  }

  bool get isStaffLike =>
      this == UserType.staff || this == UserType.hod || this == UserType.admin;
}