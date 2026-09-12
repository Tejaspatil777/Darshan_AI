/// User roles supported by the app (mobile flow: STUDENT / FACULTY).
enum UserRole { student, faculty }

/// Maps the backend role code (STUDENT / FACULTY / ADMIN) to the app's
/// UserRole. The role always comes from the backend — never picked by the
/// user. ADMIN accounts use the faculty home flow.
UserRole userRoleFromApi(String? role) =>
    (role ?? '').trim().toUpperCase() == 'STUDENT'
        ? UserRole.student
        : UserRole.faculty;

/// Authenticated identity built from the backend AuthResponse / UserMeResponse.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    required this.forcePasswordChange,
  });

  final String id; // backend userId (UUID)
  final String username;
  final String? email;
  final UserRole role;

  /// Backend `passwordChangeRequired` flag.
  final bool forcePasswordChange;
}

/// Student profile (view data). Fields the backend does not provide
/// (date of birth, section, address) stay null and render as empty states.
class Student {
  const Student({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.department,
    this.semester,
    this.section,
    this.rollNo,
    this.address,
    required this.faceEnrolled,
  });

  final String id; // backend enrollmentNo / rollNo
  final String name;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? department;
  final String? semester; // e.g. Semester 5
  final String? section;
  final String? rollNo;
  final String? address;
  final bool faceEnrolled;

  Student copyWith({required bool faceEnrolled}) => Student(
        id: id,
        name: name,
        email: email,
        phone: phone,
        dateOfBirth: dateOfBirth,
        department: department,
        semester: semester,
        section: section,
        rollNo: rollNo,
        address: address,
        faceEnrolled: faceEnrolled,
      );
}

/// Faculty profile (view data).
class Faculty {
  const Faculty({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.department,
    this.branch,
  });

  final String id; // backend employeeId
  final String name;
  final String? email;
  final String? phone;
  final String? department;
  final String? branch;
}

