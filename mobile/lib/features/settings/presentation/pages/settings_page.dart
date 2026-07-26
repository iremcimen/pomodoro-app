import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../application/settings_controller.dart';
import '../../domain/entities/user_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SettingsError(
          message: error is AppException ? error.message : error.toString(),
          onRetry: () =>
              ref.read(settingsControllerProvider.notifier).refresh(),
        ),
        data: (settings) => _SettingsForm(settings: settings),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});
  final UserSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late UserSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  @override
  void didUpdateWidget(covariant _SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) _draft = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(settingsControllerProvider).isLoading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Zamanlayıcı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _NumberSetting(
          title: 'Odak süresi',
          value: _draft.focusDurationMinutes,
          min: 1,
          max: 180,
          suffix: 'dk',
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(focusDurationMinutes: value),
          ),
        ),
        _NumberSetting(
          title: 'Kısa mola',
          value: _draft.shortBreakMinutes,
          min: 1,
          max: 60,
          suffix: 'dk',
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(shortBreakMinutes: value),
          ),
        ),
        _NumberSetting(
          title: 'Uzun mola',
          value: _draft.longBreakMinutes,
          min: 1,
          max: 120,
          suffix: 'dk',
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(longBreakMinutes: value)),
        ),
        _NumberSetting(
          title: 'Uzun mola aralığı',
          value: _draft.longBreakInterval,
          min: 1,
          max: 12,
          suffix: 'odak',
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(longBreakInterval: value),
          ),
        ),
        const SizedBox(height: 20),
        Text('Otomasyon', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Molaları otomatik başlat'),
          subtitle: const Text('Odak süresi bitince molayı başlatır.'),
          value: _draft.autoStartBreak,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(autoStartBreak: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Odağı otomatik başlat'),
          subtitle: const Text('Mola bitince yeni odak oturumunu başlatır.'),
          value: _draft.autoStartFocus,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(autoStartFocus: value)),
        ),
        const SizedBox(height: 20),
        Text(
          'Bildirim ve geri bildirim',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ses'),
          subtitle: const Text('Oturum tamamlandığında uyarı sesi çalar.'),
          value: _draft.soundEnabled,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(soundEnabled: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Titreşim'),
          subtitle: const Text('Desteklenen cihazlarda titreşim kullanır.'),
          value: _draft.vibrationEnabled,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(vibrationEnabled: value)),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isSaving ? null : _save,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Ayarları kaydet'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final success = await ref
        .read(settingsControllerProvider.notifier)
        .save(_draft);
    if (!mounted) return;
    final error = ref.read(settingsControllerProvider).error;
    final message = success
        ? 'Ayarlar kaydedildi.'
        : error is AppException
        ? error.message
        : 'Ayarlar kaydedilemedi.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });
  final String title;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text('$min–$max $suffix'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    ),
  );
}
