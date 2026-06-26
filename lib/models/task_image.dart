class TaskImage {
  const TaskImage({
    required this.id,
    required this.order,
    required this.imageData,
    this.uploadedAt,
    this.taskId,
    this.uploadedBy,
  });

  final int id;
  final int order;
  final String imageData;
  final DateTime? uploadedAt;
  final int? taskId;
  final int? uploadedBy;

  factory TaskImage.fromJson(Map<String, dynamic> json) {
    return TaskImage(
      id: json['imageId'] as int? ?? 0,
      order: json['imageOrder'] as int? ?? 0,
      imageData: json['imageData'] as String? ?? '',
      uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? ''),
      taskId: json['task'] as int?,
      uploadedBy: json['uploadedBy'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageOrder': order,
    'imageData': imageData,
  };
}
