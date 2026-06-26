enum TaskStatus { open, inProgress, inReview, reviewCompleted }

extension TaskStatusX on TaskStatus {
  String get apiName => switch (this) {
    TaskStatus.open => 'OPEN',
    TaskStatus.inProgress => 'IN_PROGRESS',
    TaskStatus.inReview => 'IN_REVIEW',
    TaskStatus.reviewCompleted => 'REVIEW_COMPLETED',
  };

  String get label => switch (this) {
    TaskStatus.open => 'Open',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.inReview => 'In review',
    TaskStatus.reviewCompleted => 'Review completed',
  };

  static TaskStatus fromApi(String? value) {
    return switch (value) {
      'IN_PROGRESS' => TaskStatus.inProgress,
      'IN_REVIEW' => TaskStatus.inReview,
      'REVIEW_COMPLETED' => TaskStatus.reviewCompleted,
      _ => TaskStatus.open,
    };
  }
}

class CleaningTask {
  const CleaningTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.assignedBy,
    this.location,
    this.priority,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final TaskStatus status;
  final int assignedTo;
  final int assignedBy;
  final String? location;
  final String? priority;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CleaningTask.fromJson(Map<String, dynamic> json) {
    return CleaningTask(
      id: json['taskId'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled task',
      description: json['description'] as String? ?? '',
      status: TaskStatusX.fromApi(json['status'] as String?),
      assignedTo: json['assignedTo'] as int? ?? 0,
      assignedBy: json['assignedBy'] as int? ?? 0,
      location: json['location'] as String?,
      priority: json['priority'] as String?,
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'taskId': id == 0 ? null : id,
    'title': title,
    'description': description,
    'status': status.apiName,
    'assignedTo': assignedTo,
    'assignedBy': assignedBy,
    if (location != null) 'location': location,
    if (priority != null) 'priority': priority,
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
  };
}
