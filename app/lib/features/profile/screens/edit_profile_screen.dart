import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late UserProfile _draft;

  final _nameCtrl     = TextEditingController();
  final _heightCtrl   = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _targetCtrl   = TextEditingController();
  final _injuriesCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(profileProvider);
    _nameCtrl.text     = _draft.displayName    ?? '';
    _heightCtrl.text   = _draft.heightCm       != null ? _draft.heightCm!.round().toString() : '';
    _weightCtrl.text   = _draft.weightKg       != null ? _draft.weightKg!.round().toString() : '';
    _targetCtrl.text   = _draft.targetWeightKg != null ? _draft.targetWeightKg!.round().toString() : '';
    _injuriesCtrl.text = _draft.injuries       ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetCtrl.dispose();
    _injuriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _draft.copyWith(
      displayName:        _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      heightCm:           double.tryParse(_heightCtrl.text.trim()),
      weightKg:           double.tryParse(_weightCtrl.text.trim()),
      targetWeightKg:     double.tryParse(_targetCtrl.text.trim()),
      injuries:           _injuriesCtrl.text.trim().isEmpty ? null : _injuriesCtrl.text.trim(),
    );
    await ref.read(profileProvider.notifier).save(updated);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickDob() async {
    final now   = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _draft.dateOfBirth ?? DateTime(now.year - 25),
      firstDate:   DateTime(1920),
      lastDate:    DateTime(now.year - 5),
    );
    if (picked != null) setState(() => _draft = _draft.copyWith(dateOfBirth: picked));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Avatar preview ───────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                _AvatarCircle(profile: _draft, size: 80),
                const SizedBox(height: 8),
                Text(
                  _draft.displayName?.isNotEmpty == true
                      ? _draft.displayName!
                      : 'Your Name',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Personal Info ────────────────────────────────────────────────
          _SectionHeader('Personal Info'),
          _FormCard(children: [
            _Field(
              label: 'Full Name',
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Alex Johnson'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _Field(
              label: 'Date of Birth',
              child: InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _draft.dateOfBirth != null
                        ? DateFormat('dd MMM yyyy').format(_draft.dateOfBirth!)
                        : 'Select date',
                    style: _draft.dateOfBirth != null
                        ? Theme.of(context).textTheme.bodyLarge
                        : TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            _Field(
              label: 'Gender',
              child: _DropdownPicker<Gender>(
                value: _draft.gender,
                items: Gender.values,
                label: (g) => g.label,
                hint: 'Select gender',
                onChanged: (g) => setState(() => _draft = _draft.copyWith(gender: g)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Body Metrics ─────────────────────────────────────────────────
          _SectionHeader('Body Metrics'),
          _FormCard(children: [
            _Field(
              label: 'Unit System',
              child: _SegmentedRow<UnitSystem>(
                value: _draft.unitSystem,
                options: UnitSystem.values,
                label: (u) => u == UnitSystem.metric ? 'Metric (kg/cm)' : 'Imperial (lbs/ft)',
                onChanged: (u) => setState(() => _draft = _draft.copyWith(unitSystem: u)),
              ),
            ),
            _Field(
              label: _draft.unitSystem == UnitSystem.metric ? 'Height (cm)' : 'Height (cm, enter in cm)',
              child: TextField(
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: _draft.unitSystem == UnitSystem.metric ? 'e.g. 175' : 'e.g. 175',
                  suffixText: 'cm',
                ),
              ),
            ),
            _Field(
              label: 'Current Weight (kg)',
              child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. 75', suffixText: 'kg'),
              ),
            ),
            _Field(
              label: 'Target Weight (kg)',
              child: TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. 68', suffixText: 'kg'),
              ),
            ),
            if (_draft.bmi != null)
              _BmiRow(bmi: _draft.bmi!, category: _draft.bmiCategory),
          ]),
          const SizedBox(height: 16),

          // ── Fitness Profile ──────────────────────────────────────────────
          _SectionHeader('Fitness Profile'),
          _FormCard(children: [
            _Field(
              label: 'Fitness Level',
              child: _DropdownPicker<FitnessLevel>(
                value: _draft.fitnessLevel,
                items: FitnessLevel.values,
                label: (f) => f.label,
                hint: 'Select level',
                onChanged: (f) => setState(() => _draft = _draft.copyWith(fitnessLevel: f)),
              ),
            ),
            _Field(
              label: 'Primary Goal',
              child: _DropdownPicker<PrimaryGoal>(
                value: _draft.primaryGoal,
                items: PrimaryGoal.values,
                label: (g) => g.label,
                hint: 'Select goal',
                onChanged: (g) => setState(() => _draft = _draft.copyWith(primaryGoal: g)),
              ),
            ),
            _Field(
              label: 'Weekly Workout Target',
              child: _SliderField(
                value: (_draft.weeklyWorkoutTarget ?? 3).toDouble(),
                min: 1, max: 7, divisions: 6,
                label: (v) => '${v.round()} day${v.round() == 1 ? "" : "s"}/week',
                onChanged: (v) => setState(() =>
                    _draft = _draft.copyWith(weeklyWorkoutTarget: v.round())),
              ),
            ),
            _Field(
              label: 'Available Equipment',
              child: _DropdownPicker<EquipmentType>(
                value: _draft.equipment,
                items: EquipmentType.values,
                label: (e) => e.label,
                hint: 'Select equipment',
                onChanged: (e) => setState(() => _draft = _draft.copyWith(equipment: e)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Health ───────────────────────────────────────────────────────
          _SectionHeader('Health & Activity'),
          _FormCard(children: [
            _Field(
              label: 'Activity Level',
              child: _DropdownPicker<ActivityLevel>(
                value: _draft.activityLevel,
                items: ActivityLevel.values,
                label: (a) => a.label,
                hint: 'Select activity level',
                onChanged: (a) => setState(() => _draft = _draft.copyWith(activityLevel: a)),
              ),
            ),
            _Field(
              label: 'Injuries / Health Notes',
              child: TextField(
                controller: _injuriesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. mild lower back pain, right knee surgery 2023',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Profile'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2, top: 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DropdownPicker<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final String hint;
  final ValueChanged<T?> onChanged;
  const _DropdownPicker({
    required this.value, required this.items,
    required this.label, required this.hint, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      hint: Text(hint, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
      dropdownColor: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(label(item), style: const TextStyle(fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const _SegmentedRow({
    required this.value, required this.options,
    required this.label, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options.map((o) => ButtonSegment(value: o, label: Text(label(o)))).toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(
          BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final double value;
  final double min, max;
  final int divisions;
  final String Function(double) label;
  final ValueChanged<double> onChanged;
  const _SliderField({
    required this.value, required this.min, required this.max,
    required this.divisions, required this.label, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label(value),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: value,
          min: min, max: max,
          divisions: divisions,
          label: label(value),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BmiRow extends StatelessWidget {
  final double bmi;
  final String category;
  const _BmiRow({required this.bmi, required this.category});

  Color _color() {
    if (bmi < 18.5) return AppColors.info;
    if (bmi < 25)   return AppColors.health;
    if (bmi < 30)   return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_weight_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text('BMI: ${bmi.toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 6),
          Text('· $category',
              style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

/// Reusable avatar widget — shows initials in a coloured circle.
class _AvatarCircle extends StatelessWidget {
  final UserProfile profile;
  final double size;
  const _AvatarCircle({required this.profile, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        profile.initials,
        style: TextStyle(
          fontSize: size * 0.30,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Public widget so Settings screen can show the avatar.
class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final double size;
  const ProfileAvatar({required this.profile, this.size = 48, super.key});

  @override
  Widget build(BuildContext context) => _AvatarCircle(profile: profile, size: size);
}
