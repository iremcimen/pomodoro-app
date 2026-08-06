import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/presentation/widgets/app_state_view.dart';
import '../../../../shared/presentation/widgets/responsive_content.dart';
import '../../application/settings_controller.dart';
import '../../domain/entities/user_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return AppAsyncValueView<UserSettings>(
      value: state,
      loadingLabel: 'Ayarlar yükleniyor…',
      errorMessage: (error) =>
          error is AppException ? error.message : error.toString(),
      onRetry: () => ref.read(settingsControllerProvider.notifier).refresh(),
      data: (settings) => _SettingsForm(settings: settings),
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

    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _SettingsSection(
            title: 'Zamanlayıcı',
            description: 'Odak ve mola ritmini çalışma biçimine göre ayarla.',
            children: [
              _NumberSetting(
                fieldKey: const Key('setting-focus-duration'),
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
                fieldKey: const Key('setting-short-break'),
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
                fieldKey: const Key('setting-long-break'),
                title: 'Uzun mola',
                value: _draft.longBreakMinutes,
                min: 1,
                max: 120,
                suffix: 'dk',
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(longBreakMinutes: value),
                ),
              ),
              _NumberSetting(
                fieldKey: const Key('setting-long-break-interval'),
                title: 'Uzun mola aralığı',
                value: _draft.longBreakInterval,
                min: 1,
                max: 12,
                suffix: 'odak',
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(longBreakInterval: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'Otomasyon',
            description: 'Oturum geçişlerinde ne kadar kontrol istediğini seç.',
            children: [
              SwitchListTile(
                title: const Text('Molaları otomatik başlat'),
                subtitle: const Text(
                  'Odak bitince molayı beklemeden başlatır.',
                ),
                value: _draft.autoStartBreak,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(autoStartBreak: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Odağı otomatik başlat'),
                subtitle: const Text('Mola bitince yeni odağı başlatır.'),
                value: _draft.autoStartFocus,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(autoStartFocus: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'Geri bildirim',
            description: 'Oturum tamamlandığında nasıl haberdar olacağını seç.',
            children: [
              SwitchListTile(
                title: const Text('Ses'),
                subtitle: const Text(
                  'Oturum tamamlandığında uyarı sesi çalar.',
                ),
                value: _draft.soundEnabled,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(soundEnabled: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Titreşim'),
                subtitle: const Text(
                  'Desteklenen cihazlarda dokunsal geri bildirim verir.',
                ),
                value: _draft.vibrationEnabled,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(vibrationEnabled: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('settings-save-button'),
            onPressed: isSaving ? null : _save,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Kaydediliyor…' : 'Ayarları kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Divider(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    required this.fieldKey,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final Key fieldKey;
  final String title;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasInvalidInput = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _NumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _setText(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commitInput();
  }

  void _handleChanged(String input) {
    final value = int.tryParse(input);
    final isValid =
        value != null && value >= widget.min && value <= widget.max;

    if (_hasInvalidInput == isValid) {
      setState(() => _hasInvalidInput = !isValid);
    }
    if (isValid && value != widget.value) widget.onChanged(value);
  }

  void _commitInput() {
    final parsed = int.tryParse(_controller.text);
    final normalized = parsed == null
        ? widget.value
        : parsed.clamp(widget.min, widget.max);
    _setText(normalized);
    if (_hasInvalidInput) setState(() => _hasInvalidInput = false);
    if (normalized != widget.value) widget.onChanged(normalized);
  }

  void _step(int amount) {
    final parsed = int.tryParse(_controller.text);
    final base = parsed != null &&
            parsed >= widget.min &&
            parsed <= widget.max
        ? parsed
        : widget.value;
    final next = (base + amount).clamp(widget.min, widget.max);
    _setText(next);
    if (_hasInvalidInput) setState(() => _hasInvalidInput = false);
    if (next != widget.value) widget.onChanged(next);
  }

  void _setText(int value) {
    final text = value.toString();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;

    return ListTile(
      title: Text(title),
      subtitle: Text('${widget.min}–${widget.max} ${widget.suffix}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '$title değerini azalt',
            onPressed: widget.value > widget.min ? () => _step(-1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 96,
            child: Semantics(
              label:
                  '$title değeri, ${widget.min} ile ${widget.max} '
                  '${widget.suffix} arasında',
              child: TextField(
                key: widget.fieldKey,
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    widget.max.toString().length,
                  ),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: widget.suffix,
                  errorText: _hasInvalidInput
                      ? '${widget.min}–${widget.max}'
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onChanged: _handleChanged,
                onSubmitted: (_) {
                  _commitInput();
                  _focusNode.unfocus();
                },
              ),
            ),
          ),
          IconButton(
            tooltip: '$title değerini artır',
            onPressed: widget.value < widget.max ? () => _step(1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
