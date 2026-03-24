import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:signal_noise/models/signal_task.dart';
import 'package:signal_noise/models/tag.dart';
import 'package:signal_noise/models/time_slot.dart';
import 'package:signal_noise/providers/signal_task_provider.dart';
import 'package:signal_noise/providers/tag_provider.dart';
import 'package:signal_noise/services/storage_service.dart';
import 'package:signal_noise/widgets/timer/task_timer_modal.dart';

class _FakeStorageService extends StorageService {
  _FakeStorageService(List<SignalTask> initialTasks)
    : _tasksById = {for (final task in initialTasks) task.id: task};

  final Map<String, SignalTask> _tasksById;

  @override
  List<SignalTask> getAllSignalTasks() => _tasksById.values.toList();

  @override
  List<SignalTask> getSignalTasksForDate(DateTime date) {
    bool isSameDay(DateTime a, DateTime b) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    return _tasksById.values
        .where((task) => isSameDay(task.scheduledDate, date))
        .toList();
  }

  @override
  SignalTask? getSignalTask(String id) => _tasksById[id];

  @override
  Future<void> addSignalTask(SignalTask task) async {
    _tasksById[task.id] = task;
  }

  @override
  Future<void> updateSignalTask(SignalTask task) async {
    _tasksById[task.id] = task;
  }

  @override
  Future<void> deleteSignalTask(String id) async {
    _tasksById.remove(id);
  }

  @override
  List<Tag> getAllTags() => const [];

  @override
  bool hasDefaultTags() => true;

  @override
  Future<void> initializeDefaultTags() async {}
}

class _TestSignalTaskProvider extends SignalTaskProvider {
  _TestSignalTaskProvider(this._storage) : super(_storage);

  final _FakeStorageService _storage;

  Future<void> applyExternalTaskUpdate(SignalTask task) async {
    await _storage.updateSignalTask(task);
    await loadTasks();
  }

  Future<void> removeTaskExternally(String taskId) async {
    await _storage.deleteSignalTask(taskId);
    await loadTasks();
  }
}

SignalTask _buildActiveTask({
  required String taskId,
  required String slotId,
  required String title,
}) {
  final now = DateTime.now();
  return SignalTask(
    id: taskId,
    title: title,
    estimatedMinutes: 60,
    scheduledDate: DateTime(now.year, now.month, now.day),
    timeSlots: [
      TimeSlot(
        id: slotId,
        plannedStartTime: now.subtract(const Duration(minutes: 30)),
        plannedEndTime: now.add(const Duration(minutes: 30)),
        actualStartTime: now.subtract(const Duration(minutes: 10)),
        sessionStartTime: now.subtract(const Duration(minutes: 10)),
        isActive: true,
      ),
    ],
    createdAt: now,
  );
}

Widget _buildTestApp({
  required SignalTask initialTask,
  required SignalTaskProvider taskProvider,
  required TagProvider tagProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SignalTaskProvider>.value(value: taskProvider),
      ChangeNotifierProvider<TagProvider>.value(value: tagProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => TaskTimerModal.show(context, initialTask),
                child: const Text('Open Timer Modal'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  group('TaskTimerModal provider updates', () {
    testWidgets('updates modal content when task changes externally', (
      tester,
    ) async {
      final task = _buildActiveTask(
        taskId: 'task-1',
        slotId: 'slot-1',
        title: 'Draft proposal',
      );
      final storage = _FakeStorageService([task]);
      final taskProvider = _TestSignalTaskProvider(storage);
      final tagProvider = TagProvider(storage);

      await tester.pumpWidget(
        _buildTestApp(
          initialTask: task,
          taskProvider: taskProvider,
          tagProvider: tagProvider,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Timer Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Draft proposal'), findsOneWidget);

      final updatedTask = task.copyWith(title: 'Draft proposal (updated)');
      await taskProvider.applyExternalTaskUpdate(updatedTask);
      await tester.pump();

      expect(find.text('Draft proposal'), findsNothing);
      expect(find.text('Draft proposal (updated)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      taskProvider.dispose();
      tagProvider.dispose();
    });

    testWidgets('dismisses when active slot becomes unavailable', (
      tester,
    ) async {
      final task = _buildActiveTask(
        taskId: 'task-2',
        slotId: 'slot-2',
        title: 'Write review',
      );
      final storage = _FakeStorageService([task]);
      final taskProvider = _TestSignalTaskProvider(storage);
      final tagProvider = TagProvider(storage);

      await tester.pumpWidget(
        _buildTestApp(
          initialTask: task,
          taskProvider: taskProvider,
          tagProvider: tagProvider,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Timer Modal'));
      await tester.pumpAndSettle();

      final endedSlot = task.timeSlots.first.copyWith(
        isActive: false,
        actualEndTime: DateTime.now(),
        accumulatedSeconds: 600,
      );
      final endedTask = task.copyWith(timeSlots: [endedSlot]);
      await taskProvider.applyExternalTaskUpdate(endedTask);
      await tester.pumpAndSettle();

      expect(
        find.text('This timer session ended or is no longer available.'),
        findsOneWidget,
      );
      expect(find.byType(TaskTimerModal), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      taskProvider.dispose();
      tagProvider.dispose();
    });

    testWidgets('dismisses when task is deleted externally', (tester) async {
      final task = _buildActiveTask(
        taskId: 'task-3',
        slotId: 'slot-3',
        title: 'Prepare slides',
      );
      final storage = _FakeStorageService([task]);
      final taskProvider = _TestSignalTaskProvider(storage);
      final tagProvider = TagProvider(storage);

      await tester.pumpWidget(
        _buildTestApp(
          initialTask: task,
          taskProvider: taskProvider,
          tagProvider: tagProvider,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Timer Modal'));
      await tester.pumpAndSettle();

      await taskProvider.removeTaskExternally(task.id);
      await tester.pumpAndSettle();

      expect(find.text('This timer task was removed.'), findsOneWidget);
      expect(find.byType(TaskTimerModal), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      taskProvider.dispose();
      tagProvider.dispose();
    });
  });
}
