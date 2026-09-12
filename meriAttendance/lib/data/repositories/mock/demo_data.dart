import '../../models/attendance.dart';
import '../../models/user.dart';

/// Demo/mock data used while the backend is not connected.
/// Replacing this file with real API responses is all that backend
/// integration should require.
class DemoData {
  DemoData._();

  // --- Demo accounts -------------------------------------------------------
  static const String demoStudentEmail = 'student@darshan.edu';
  static const String demoStudentPassword = 'Student@123';
  static const String demoFacultyEmail = 'faculty@darshan.edu';
  static const String demoFacultyPassword = 'Faculty@123';

  // --- Demo student --------------------------------------------------------
  static final Student demoStudent = Student(
    id: '21BCS001',
    name: 'Aarav Sharma',
    email: demoStudentEmail,
    phone: '9999999999',
    dateOfBirth: DateTime(2003, 1, 1),
    department: 'Computer Science',
    semester: 'Semester 5',
    section: 'Section A',
    rollNo: '05',
    address: 'Hostel B, University Campus',
    faceEnrolled: false,
  );

  // --- Demo faculty --------------------------------------------------------
  static final Faculty demoFaculty = Faculty(
    id: 'FAC-CS-012',
    name: 'Dr. Meera Iyer',
    email: demoFacultyEmail,
    phone: '9876543210',
    department: 'Computer Science',
    branch: 'Computer Science',
  );

  // --- Attendance setup options -------------------------------------------
  static const String branch = 'Computer Science';
  static const List<String> subjects = <String>[
    'Data Structures',
    'Operating Systems',
    'Database Management Systems',
    'Computer Networks',
    'Software Engineering',
  ];
  static const List<String> classes = <String>[
    'Semester 5 - Section A',
    'Semester 5 - Section B',
  ];
  static const List<String> modes = <String>['Lecture', 'Lab'];
  static const List<String> rooms = <String>[
    'Room 101',
    'Room 102',
    'Lab 201',
    'Lab 202',
  ];

  // --- Real catalog options used by attendance setup ------------------------
  static const List<String> subjectIds = <String>[
    'demo-subject-ds',
    'demo-subject-os',
    'demo-subject-dbms',
    'demo-subject-cn',
    'demo-subject-se',
  ];
  static const List<String> classIds = <String>[
    'demo-cls-a',
    'demo-cls-b',
  ];
  static const List<String> roomIds = <String>[
    'demo-room-101',
    'demo-room-102',
    'demo-room-lab-201',
    'demo-room-lab-202',
  ];
  static final List<Lecture> demoLectures = <Lecture>[
    Lecture(
      assignmentId: 'demo-assignment-1',
      clsId: 'demo-cls-a',
      className: 'Semester 5 - Section A',
      subjectId: 'demo-subject-ds',
      subjectName: 'Data Structures',
      roomId: 'demo-room-101',
      roomName: 'Room 101',
      lectureSlot: 1,
    ),
    Lecture(
      assignmentId: 'demo-assignment-2',
      clsId: 'demo-cls-a',
      className: 'Semester 5 - Section A',
      subjectId: 'demo-subject-os',
      subjectName: 'Operating Systems',
      roomId: 'demo-room-102',
      roomName: 'Room 102',
      lectureSlot: 2,
    ),
  ];

  // --- Class roster (Semester 5 - Section A) -------------------------------
  static const List<String> _rosterNames = <String>[
    'Aarav Sharma',
    'Ananya Singh',
    'Rohan Patel',
    'Priya Verma',
    'Karan Mehta',
    'Ishita Nair',
    'Vivek Joshi',
    'Sneha Kulkarni',
    'Arjun Reddy',
    'Meera Kapoor',
    'Rahul Gupta',
    'Pooja Desai',
    'Aditya Rao',
    'Nisha Iyer',
    'Siddharth Malhotra',
    'Kavya Menon',
    'Nikhil Bhatt',
    'Ritu Chauhan',
    'Aman Khan',
    'Divya Pillai',
    'Yash Agarwal',
    'Shreya Bose',
    'Manav Shah',
    'Tanvi Saxena',
    'Harsh Vardhan',
    'Neha Mishra',
    'Rohit Choudhary',
    'Ayesha Siddiqui',
    'Varun Pandey',
    'Lakshmi Prasad',
    'Gaurav Tiwari',
    'Sakshi Jain',
  ];

  /// The full class roster for the demo session (32 students):
  /// 25 present + 7 not seen, matching the reference review counts.
  static List<Student> get roster => List<Student>.generate(
        _rosterNames.length,
        (int i) => Student(
          id: '21BCS${(i + 1).toString().padLeft(3, '0')}',
          name: _rosterNames[i],
          email: '${_rosterNames[i].split(' ').first.toLowerCase()}'
              '@darshan.edu',
          phone: '9${(900000000 + i * 111111).toString().substring(0, 9)}',
          dateOfBirth: DateTime(2003, (i % 12) + 1, (i % 27) + 1),
          department: 'Computer Science',
          semester: 'Semester 5',
          section: 'Section A',
          rollNo: '${(i % 30) + 1}'.padLeft(2, '0'),
          address: 'Hostel ${String.fromCharCode(65 + (i % 4))}, Campus',
          faceEnrolled: true,
        ),
      );
}
