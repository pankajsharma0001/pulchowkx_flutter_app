/// Faculty model - represents academic departments
class Faculty {
  final int id;
  final String name;
  final String slug;
  final String? code;
  final int semestersCount;
  final int semesterDurationMonths;

  Faculty({
    required this.id,
    required this.name,
    required this.slug,
    this.code,
    this.semestersCount = 8,
    this.semesterDurationMonths = 6,
  });

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      code: json['code'] as String?,
      semestersCount: json['semestersCount'] as int? ?? 8,
      semesterDurationMonths: json['semesterDurationMonths'] as int? ?? 6,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'code': code,
    'semestersCount': semestersCount,
    'semesterDurationMonths': semesterDurationMonths,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Faculty && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Subject model - represents a course/subject
class Subject {
  final int id;
  final int facultyId;
  final int semesterNumber;
  final String? code;
  final String title;
  final bool isElective;
  final String? electiveGroup;
  final List<Assignment>? assignments;

  Subject({
    required this.id,
    required this.facultyId,
    required this.semesterNumber,
    this.code,
    required this.title,
    this.isElective = false,
    this.electiveGroup,
    this.assignments,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      facultyId: json['facultyId'] as int,
      semesterNumber: json['semesterNumber'] as int,
      code: json['code'] as String?,
      title: json['title'] as String,
      isElective: json['isElective'] as bool? ?? false,
      electiveGroup: json['electiveGroup'] as String?,
      assignments: json['assignments'] != null
          ? (json['assignments'] as List)
                .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'facultyId': facultyId,
    'semesterNumber': semesterNumber,
    'code': code,
    'title': title,
    'isElective': isElective,
    'electiveGroup': electiveGroup,
  };

  /// Get the number of pending assignments
  int get pendingCount =>
      assignments?.where((a) => a.submission == null).length ?? 0;

  /// Get the number of submitted assignments
  int get submittedCount =>
      assignments?.where((a) => a.submission != null).length ?? 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subject && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Student profile model
class StudentProfile {
  final String userId;
  final int facultyId;
  final int currentSemester;
  final DateTime semesterStartDate;
  final DateTime? semesterEndDate;
  final bool autoAdvance;
  final Faculty? faculty;

  StudentProfile({
    required this.userId,
    required this.facultyId,
    required this.currentSemester,
    required this.semesterStartDate,
    this.semesterEndDate,
    this.autoAdvance = true,
    this.faculty,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      userId: json['userId'] as String,
      facultyId: json['facultyId'] as int,
      currentSemester: json['currentSemester'] as int,
      semesterStartDate: DateTime.parse(json['semesterStartDate'] as String),
      semesterEndDate: json['semesterEndDate'] != null
          ? DateTime.parse(json['semesterEndDate'] as String)
          : null,
      autoAdvance: json['autoAdvance'] as bool? ?? true,
      faculty: json['faculty'] != null
          ? Faculty.fromJson(json['faculty'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Calculate semester progress percentage
  double get semesterProgress {
    if (semesterEndDate == null) return 0;
    final start = semesterStartDate.millisecondsSinceEpoch;
    final end = semesterEndDate!.millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (end <= start) return 0;
    final progress = ((now - start) / (end - start)) * 100;
    return progress.clamp(0, 100);
  }
}

/// Assignment type enum
enum AssignmentType {
  classwork('classwork', 'Classwork'),
  homework('homework', 'Homework');

  const AssignmentType(this.value, this.label);
  final String value;
  final String label;

  static AssignmentType fromString(String? value) {
    return AssignmentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssignmentType.classwork,
    );
  }
}

/// Submission status enum
enum SubmissionStatus {
  submitted('submitted', 'Submitted'),
  graded('graded', 'Graded'),
  returned('returned', 'Returned');

  const SubmissionStatus(this.value, this.label);
  final String value;
  final String label;

  static SubmissionStatus fromString(String? value) {
    return SubmissionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SubmissionStatus.submitted,
    );
  }
}

/// Student info for submission
class SubmissionStudent {
  final String id;
  final String name;
  final String email;
  final String? image;

  SubmissionStudent({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory SubmissionStudent.fromJson(Map<String, dynamic> json) {
    return SubmissionStudent(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      image: json['image'] as String?,
    );
  }
}

/// Assignment submission model
class AssignmentSubmission {
  final int id;
  final int assignmentId;
  final String studentId;
  final String? comment;
  final String fileUrl;
  final String? fileName;
  final String? fileMimeType;
  final int? fileSize;
  final SubmissionStatus status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final SubmissionStudent? student;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.comment,
    required this.fileUrl,
    this.fileName,
    this.fileMimeType,
    this.fileSize,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.student,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      id: json['id'] as int,
      assignmentId: json['assignmentId'] as int,
      studentId: json['studentId'] as String,
      comment: json['comment'] as String?,
      fileUrl: json['fileUrl'] as String,
      fileName: json['fileName'] as String?,
      fileMimeType: json['fileMimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      status: SubmissionStatus.fromString(json['status'] as String?),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      student: json['student'] != null
          ? SubmissionStudent.fromJson(json['student'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Assignment model
class Assignment {
  final int id;
  final int subjectId;
  final String teacherId;
  final String title;
  final String? description;
  final AssignmentType type;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AssignmentSubmission? submission;

  Assignment({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    this.description,
    required this.type,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.submission,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as int,
      subjectId: json['subjectId'] as int,
      teacherId: json['teacherId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: AssignmentType.fromString(json['type'] as String?),
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      submission: json['submission'] != null
          ? AssignmentSubmission.fromJson(
              json['submission'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Check if assignment is overdue
  bool get isOverdue =>
      dueAt != null && dueAt!.isBefore(DateTime.now()) && submission == null;

  /// Check if assignment is submitted
  bool get isSubmitted => submission != null;

  /// Check if assignment has a due date approaching (within 2 days)
  bool get isDueSoon {
    if (dueAt == null || isSubmitted) return false;
    final diff = dueAt!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 2;
  }
}

/// Student profile upsert request
class StudentProfileRequest {
  final int facultyId;
  final int? currentSemester;
  final String? semesterStartDate;
  final bool? autoAdvance;

  StudentProfileRequest({
    required this.facultyId,
    this.currentSemester,
    this.semesterStartDate,
    this.autoAdvance,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'facultyId': facultyId};
    if (currentSemester != null) json['currentSemester'] = currentSemester;
    if (semesterStartDate != null) {
      json['semesterStartDate'] = semesterStartDate;
    }
    if (autoAdvance != null) json['autoAdvance'] = autoAdvance;
    return json;
  }
}

/// Create assignment request
class CreateAssignmentRequest {
  final int subjectId;
  final String title;
  final String? description;
  final String? type; // 'classwork' or 'homework'
  final String? dueAt; // ISO 8601 date string

  CreateAssignmentRequest({
    required this.subjectId,
    required this.title,
    this.description,
    this.type,
    this.dueAt,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'subjectId': subjectId, 'title': title};
    if (description != null) json['description'] = description;
    if (type != null) json['type'] = type;
    if (dueAt != null) json['dueAt'] = dueAt;
    return json;
  }
}
