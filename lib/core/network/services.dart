import '../../models/task.dart';
import '../../models/task_image.dart';
import '../../models/user.dart';
import '../../models/chat_message.dart';
import 'api_client.dart';

class TasksApi {
  const TasksApi(this._client);
  final ApiClient _client;

  Future<List<CleaningTask>> myTasks() async {
    final data = await _client.get('/api/tasks/my') as List<dynamic>;
    return data
        .map((item) => CleaningTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CleaningTask>> allTasks() async {
    final data = await _client.get('/api/tasks') as List<dynamic>;
    return data
        .map((item) => CleaningTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CleaningTask> task(int id) async => CleaningTask.fromJson(
    await _client.get('/api/tasks/$id') as Map<String, dynamic>,
  );
  Future<void> submitReview(int id) => _workflowAction(
    '/api/tasks/$id/submit-review',
    'submit a task for review',
  );
  Future<void> completeReview(int id) => _workflowAction(
    '/api/tasks/$id/complete-review',
    'complete an admin review',
  );
  Future<void> create(CleaningTask task) =>
      _client.post('/api/tasks', task.toJson());
  Future<void> assign({
    required int taskId,
    required int assignedTo,
    required int assignedBy,
  }) {
    return _client.put('/api/tasks/$taskId/assign', {
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
    });
  }

  Future<void> _workflowAction(String path, String action) async {
    try {
      await _client.put(path);
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        throw ApiException(
          'Backend endpoint missing: $path is required to $action.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }
}

class TaskImagesApi {
  const TaskImagesApi(this._client);
  final ApiClient _client;

  Future<List<TaskImage>> forTask(int taskId) async {
    final data =
        await _client.get('/api/tasks/$taskId/images') as List<dynamic>;
    return data
        .map((item) => TaskImage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> upload(int taskId, TaskImage image) =>
      _client.post('/api/tasks/$taskId/images', image.toJson());

  Future<void> delete(int taskId, int imageId) =>
      _client.delete('/api/tasks/$taskId/images/$imageId');
}

class UsersApi {
  const UsersApi(this._client);
  final ApiClient _client;

  Future<AppUser> me() async => AppUser.fromJson(
    await _client.get('/api/users/me') as Map<String, dynamic>,
  );

  Future<List<AppUser>> all({UserRole? role}) async {
    final suffix = role == null ? '' : '?role=${role.apiName}';
    final data = await _client.get('/api/users$suffix') as List<dynamic>;
    return data
        .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(Map<String, dynamic> body) =>
      _client.post('/api/users', body);
  Future<void> update(AppUser user) =>
      _client.put('/api/users/${user.id}', user.toUpdateJson());
  Future<void> resetPassword({
    required int id,
    required String temporaryPassword,
  }) {
    return _client.put('/api/users/$id/password', {
      'temporaryPassword': temporaryPassword,
      'forcePasswordChange': true,
    });
  }

  Future<void> delete(int id) => _client.delete('/api/users/$id');
}

class ChatApi {
  const ChatApi(this._client);
  final ApiClient _client;

  Future<ChatAnswer> ask(String query) async {
    final data = await _client.post('/api/chat', {'query': query});
    return ChatAnswer.fromJson(data as Map<String, dynamic>);
  }

  Future<String> context() async {
    final data = await _client.get('/api/chat/context') as Map<String, dynamic>;
    return data['context'] as String? ?? '';
  }

  Future<void> resetContext() => _client.delete('/api/chat/context');
}
