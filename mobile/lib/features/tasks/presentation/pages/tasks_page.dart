import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/presentation/widgets/app_state_view.dart';
import '../../../../shared/presentation/widgets/responsive_content.dart';
import '../../application/task_providers.dart';
import '../../domain/entities/task_item.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskControllerProvider);

    return DefaultTabController(
      length: 2,
      child: ResponsiveContent(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showTaskForm(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Görev ekle'),
          ),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: TabBar(
                  tabs: [
                    Tab(text: 'Açık görevler'),
                    Tab(text: 'Tamamlananlar'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: AppAsyncValueView<List<TaskItem>>(
                  value: state,
                  loadingLabel: 'Görevler yükleniyor…',
                  errorMessage: (error) => error is AppException
                      ? error.message
                      : 'Görevler yüklenemedi.',
                  onRetry: () =>
                      ref.read(taskControllerProvider.notifier).refresh(),
                  data: (tasks) => TabBarView(
                    children: [
                      _TaskList(
                        tasks: tasks
                            .where((task) => !task.isCompleted)
                            .toList(),
                        emptyTitle: 'Açık görevin yok',
                        emptyDescription:
                            'Yeni bir görev ekleyip odağını somut bir hedefe bağla.',
                      ),
                      _TaskList(
                        tasks: tasks.where((task) => task.isCompleted).toList(),
                        emptyTitle: 'Tamamlanan görev yok',
                        emptyDescription:
                            'Bitirdiğin görevler burada birikmeye başlayacak.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.tasks,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final List<TaskItem> tasks;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return AppStateMessage(
        icon: Icons.task_alt_rounded,
        title: emptyTitle,
        description: emptyDescription,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(taskControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          104,
        ),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: task.isCompleted
                  ? '${task.title} görevini yeniden aç'
                  : '${task.title} görevini tamamla',
              child: Checkbox(
                value: task.isCompleted,
                onChanged: (value) => ref
                    .read(taskControllerProvider.notifier)
                    .edit(id: task.id, isCompleted: value),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: task.isCompleted
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      task.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label:
                              '${task.title}: '
                              '${task.completedPomodoros} odak tamamlandı, '
                              '${task.estimatedPomodoros} odak tahmin edildi',
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${task.completedPomodoros} odak · '
                        '${task.estimatedPomodoros} tahmin',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '${task.title} için işlemler',
              onSelected: (action) async {
                if (action == 'edit') {
                  await _showTaskForm(context, ref, task: task);
                } else if (action == 'delete') {
                  await _confirmDelete(context, ref, task);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Düzenle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Sil'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
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
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (isteğe bağlı)',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Text('Tahmini Pomodoro')),
                  IconButton(
                    tooltip: 'Tahmini Pomodoro sayısını azalt',
                    onPressed: _estimatedPomodoros > 1
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
                    tooltip: 'Tahmini Pomodoro sayısını artır',
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
