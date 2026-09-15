DarshanAI -- AI-Based Face Recognition Attendance System

DarshanAI (Meritendance) is an AI-powered attendance management
application designed to automate classroom attendance using face
detection and face recognition.

The system combines a Flutter mobile application, Spring Boot backend,
Python AI service, and PostgreSQL database.

🚀 Overview

The application provides:

Student face enrollment

Automatic face capture during enrollment

Base64 image transfer from Flutter to the backend

AI-based face quality validation

ArcFace face embeddings

Classroom attendance capture

Full-screen attendance camera

3×3 camera composition grid

AI-based face detection and student matching

Unknown-face review and manual resolution

Attendance review and confirmation

Role-based access for Admin, Faculty, and Student

JWT authentication with access and refresh tokens

🏗️ Architecture

                    ┌──────────────────────┐
                    │    Flutter App       │
                    │  Android / iOS / Web │
                    └──────────┬───────────┘
                               │
                               │ REST API
                               ▼
                    ┌──────────────────────┐
                    │   Spring Boot API    │
                    │ Business Logic/Auth  │
                    └───────┬────────┬─────┘
                            │        │
                   REST/AI  │        │ PostgreSQL
                            │        │
                            ▼        ▼
                 ┌──────────────┐  ┌──────────────┐
                 │ Python AI    │  │ PostgreSQL   │
                 │ SCRFD        │  │ Users        │
                 │ ArcFace      │  │ Enrollments  │
                 │ Recognition  │  │ Attendance   │
                 └──────────────┘  └──────────────┘

Main responsibilities

Component                           Responsibility

Flutter                             UI, authentication, camera, face
detection, image capture and API
communication

ML Kit                              Live face detection during
enrollment and capture assistance

Spring Boot                         Authentication, business logic,
enrollment, attendance sessions and
persistence

Python AI                           Face detection, quality validation,
ArcFace embeddings and face
matching

👤 Face Enrollment Flow

The enrollment process is intentionally simple:

Open Face Enrollment
        ↓
Live Camera Preview
        ↓
ML Kit detects a face
        ↓
Stable face detection
        ↓
Automatic photo capture
        ↓
Image → Base64
        ↓
Capture repeated until 7 images
        ↓
POST /api/students/me/enroll
        ↓
Spring Boot
        ↓
Python AI
        ↓
SCRFD + Quality Validation + ArcFace
        ↓
512-dimensional face embedding
        ↓
PostgreSQL

The mobile application does not generate the final ArcFace embedding. It
captures the image and sends the image data to the backend.

Enrollment capture

7 enrollment images are captured.

Capture is automatic after a face is detected.

The previous strict pose/yaw/oval guidance system has been removed.

ML Kit is used for live face detection.

The backend/Python AI service remains responsible for biometric
embedding generation.

📸 Attendance Flow

Faculty can capture multiple classroom photographs for attendance.

Faculty opens Attendance Camera
        ↓
Full-screen live camera
        ↓
3×3 composition grid
        ↓
Capture classroom photos
        ↓
5–10 photos
        ↓
Upload to Spring Boot
        ↓
Attendance Session = PROCESSING
        ↓
Background Attendance Worker
        ↓
Python AI
        ↓
SCRFD detects faces
        ↓
ArcFace generates embeddings
        ↓
Compare against enrolled students
        ↓
Matched Students / Unknown Faces
        ↓
REVIEW
        ↓
Faculty resolves unknown faces
        ↓
CONFIRM
        ↓
FINAL

The grid is only a visual composition guide and is not included in the
captured image.

🔐 Authentication

The backend uses JWT-based authentication.

Supported roles:

ADMIN

FACULTY

STUDENT

The application uses:

Access tokens

Refresh tokens

Role-based authorization

Automatic token refresh in the Flutter API client

🧠 AI Pipeline

The Python AI service is responsible for face processing.

Enrollment

Image
  ↓
SCRFD Face Detection
  ↓
Quality Checks
  ↓
Face Alignment
  ↓
ArcFace
  ↓
512-dimensional Embedding

Attendance

Classroom Image
  ↓
SCRFD
  ↓
Detect Multiple Faces
  ↓
Face Embedding
  ↓
Compare with Enrolled Embeddings
  ↓
Student ID / Unknown

📊 Attendance Session Lifecycle

PROCESSING
    ↓
  REVIEW
    ↓
  FINAL

If processing fails:

PROCESSING
    ↓
  FAILED

Unknown faces can be reviewed and associated with the correct student
before final confirmation.

🗂️ Project Structure

A simplified structure:

DarshanAI/
│
├── meriAttendance/                 # Flutter application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── mlkit/
│   │   │   ├── network/
│   │   │   └── widgets/
│   │   ├── screens/
│   │   ├── state/
│   │   └── ...
│   ├── android/
│   ├── ios/
│   ├── test/
│   ├── pubspec.yaml
│   └── ...
│
└── darshan-backend/               # Spring Boot backend
    └── ...

The Python AI service is deployed/run separately from the Flutter and
Spring Boot projects.

🛠️ Technology Stack

Frontend

Flutter

Dart

Camera

Google ML Kit

REST APIs

Backend

Java

Spring Boot

Spring Security

JWT

REST APIs

Background attendance processing

AI

Python

SCRFD

ArcFace

Face embeddings

Database

PostgreSQL

⚙️ Getting Started

1. Clone the repository

git clone https://github.com/Tejaspatil777/Darshan_AI.git
cd Darshan_AI

2. Flutter application

Go to the Flutter project:

cd meriAttendance

Install dependencies:

flutter pub get

Check the project:

flutter analyze

Run tests:

flutter test

Run on a connected device:

flutter run

Build a debug APK:

flutter build apk --debug

The generated APK is normally available at:

build/app/outputs/flutter-apk/app-debug.apk

3. Backend

Open the Spring Boot backend project and configure:

PostgreSQL connection

JWT configuration

AI service URL

application-specific environment variables

Start the Spring Boot application using the project's configured
Gradle/Maven command.

4. Python AI service

The Python AI service must be running and reachable by the Spring Boot
backend.

The backend sends AI requests for:

/api/enroll/validate
/api/attendance/process

The exact AI service startup command depends on the Python AI project
configuration.

🔌 Important API Flow

Student Enrollment

POST /api/students/me/enroll

The Flutter application sends the captured enrollment images using the
existing Base64 payload.

The backend forwards enrollment validation to the AI service.

Attendance

POST /api/attendance/sessions

The backend creates an attendance session and processes the classroom
images asynchronously.

AI processing uses:

/ai/enroll/validate
/ai/attendance/process

🧪 Testing

The Flutter project includes automated tests for application flows.

Run:

flutter test

Before a release, also verify the application on a physical Android
device because camera behavior cannot be fully validated through unit
tests alone.

Recommended device checks:

Camera permission

Live camera preview

Enrollment face detection

Automatic enrollment capture

7 enrollment images

Base64 request generation

Attendance camera preview

3×3 grid

5--10 classroom photos

Attendance processing

Unknown-face review

Final attendance confirmation

🔒 Privacy & Security

Face data is biometric information and should be handled carefully.

Recommended practices:

Do not commit captured face images to Git.

Do not commit Base64 face data.

Do not commit database credentials.

Do not commit JWT secrets.

Keep environment-specific configuration outside source control.

Restrict access to enrollment and attendance data.

Use HTTPS in production.

Store production secrets securely.

🚧 Current Development Notes

The project is actively being developed.

The current camera/enrollment implementation focuses on:

Reliable live face detection

Automatic face capture

Simple enrollment UX

Full-screen attendance camera

3×3 classroom framing grid

The AI service must be running and reachable by the backend for
enrollment validation and attendance recognition to complete
successfully.

📌 Roadmap

Production deployment

Production AI service configuration

Improved camera lifecycle handling

Attendance analytics

Attendance reports/export

Admin management improvements

Production security hardening

Improved AI monitoring and error reporting

👨‍💻 Author

Tejas Patil

GitHub: Tejaspatil777

📄 License

Add the project's applicable license here before publishing the
repository publicly.
