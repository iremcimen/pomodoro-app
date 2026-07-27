import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../application/task_providers.dart';
import '../../domain/entities/task_item.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Görevler'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Açık görevler'),
              Tab(text: 'Tamamlananlar'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showTaskForm(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Görev ekle'),
        ),
        body: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _TaskError(
            message: error is AppException
                ? error.message
                : 'Görevler yüklenemedi.',
            onRetry: () => ref.read(taskControllerProvider.notifier).refresh(),
          ),
          data: (tasks) => TabBarView(
            children: [
              _TaskList(
                tasks: tasks.where((task) => !task.isCompleted).toList(),
                emptyMessage: 'Henüz açık görevin yok.',
              ),
              _TaskList(
                tasks: tasks.where((task) => task.isCompleted).toList(),
                emptyMessage: 'Henüz tamamlanan görevin yok.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.emptyMessage});
  final List<TaskItem> tasks;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt_rounded, size: 56),
              const SizedBox(height: 12),
              Text(emptyMessage),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(taskControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (value) => ref
                  .read(taskControllerProvider.notifier)
                  .edit(id: task.id, isCompleted: value),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.description != null) ...[
                    const SizedBox(height: 4),
                    Text(task.description!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${task.completedPomodoros}/'
                        '${task.estimatedPomodoros} Pomodoro',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  await _showTaskForm(context, ref, task: task);
                } else if (action == 'delete') {
                  await _confirmDelete(context, ref, task);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFormDialog extends ConsumerStatefulWidget {
  const _TaskFormDialog({this.task});
  final TaskItem? task;

  @override
  ConsumerState<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late int _estimatedPomodoros;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title);
    _description = TextEditingController(text: widget.task?.description);
    _estimatedPomodoros = widget.task?.estimatedPomodoros ?? 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'Yeni görev' : 'Görevi düzenle'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Başlık'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Başlık gerekli.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (isteğe bağlı)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Tahmini Pomodoro')),
                  IconButton(
                    onPressed: _estimatedPomodoros > 0
                        ? () => setState(() => _estimatedPomodoros--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '$_estimatedPomodoros',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _estimatedPomodoros++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final controller = ref.read(taskControllerProvider.notifier);
    final success = widget.task == null
        ? await controller.create(
            title: _title.text,
            description: _description.text,
            estimatedPomodoros: _estimatedPomodoros,
          )
        : await controller.edit(
            id: widget.task!.id,
            title: _title.text,
            description: _description.text,
            estimatedPomodoros: _estimatedPomodoros,
          );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Görev kaydedilemedi.')));
    }
  }
}

class _TaskError extends StatelessWidget {
  const _TaskError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

Future<void> _showTaskForm(
  BuildContext context,
  WidgetRef ref, {
  TaskItem? task,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TaskFormDialog(task: task),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TaskItem task,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Görev silinsin mi?'),
      content: Text('"${task.title}" kalıcı olarak silinecek.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(taskControllerProvider.notifier).delete(task.id);
  }
}
