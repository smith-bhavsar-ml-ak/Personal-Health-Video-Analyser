import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Static exercise data ──────────────────────────────────────────────────────

class _ExerciseInfo {
  final String id, name, category, difficulty;
  final String description;
  final List<String> cues;
  final List<String> mistakes;
  final String muscles;
  final IconData icon;

  const _ExerciseInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.description,
    required this.cues,
    required this.mistakes,
    required this.muscles,
    required this.icon,
  });
}

const _exercises = [
  _ExerciseInfo(
    id: 'squat',
    name: 'Squat',
    category: 'Legs',
    difficulty: 'Beginner',
    description: 'The squat is a fundamental compound movement that trains '
        'the lower body and core. It mimics the natural sitting motion and is '
        'the basis of functional strength.',
    muscles: 'Quads · Glutes · Hamstrings · Core',
    cues: [
      'Feet shoulder-width apart, toes slightly out',
      'Keep chest up and spine neutral throughout',
      'Drive knees out over toes — don\'t let them cave in',
      'Descend until thighs are at least parallel to the floor',
      'Drive through heels to stand, squeezing glutes at the top',
    ],
    mistakes: [
      'Knees caving inward (valgus collapse)',
      'Heels rising off the floor',
      'Excessive forward lean of the torso',
      'Not reaching parallel depth',
    ],
    icon: Icons.fitness_center,
  ),
  _ExerciseInfo(
    id: 'lunge',
    name: 'Lunge',
    category: 'Legs',
    difficulty: 'Beginner',
    description: 'A unilateral lower-body exercise that builds leg strength, '
        'balance, and hip flexibility. Great for identifying and correcting '
        'left–right imbalances.',
    muscles: 'Quads · Glutes · Hamstrings · Hip flexors',
    cues: [
      'Stand tall with feet hip-width apart',
      'Step forward with one leg, lowering the back knee toward the floor',
      'Front shin should stay vertical — knee does not travel past toes',
      'Lower until back knee is 2–3 cm from the floor',
      'Drive through the front heel to return to start',
    ],
    mistakes: [
      'Front knee tracking inward',
      'Torso leaning too far forward',
      'Taking too short or too long a step',
      'Pushing off the back foot instead of front heel',
    ],
    icon: Icons.directions_walk,
  ),
  _ExerciseInfo(
    id: 'bicep_curl',
    name: 'Bicep Curl',
    category: 'Arms',
    difficulty: 'Beginner',
    description: 'An isolation exercise for the biceps brachii. '
        'Builds arm size and elbow flexor strength.',
    muscles: 'Biceps brachii · Brachialis · Brachioradialis',
    cues: [
      'Stand tall, core braced, elbows pinned to your sides',
      'Grip dumbbells with palms facing forward (supinated)',
      'Curl the weight up by flexing the elbow — not swinging the torso',
      'Squeeze the bicep hard at the top for 1 second',
      'Lower slowly under control — 2–3 seconds on the way down',
    ],
    mistakes: [
      'Swinging the torso to generate momentum',
      'Elbows drifting forward off the body',
      'Incomplete range of motion (not fully extending)',
      'Rushing the eccentric (lowering) phase',
    ],
    icon: Icons.sports_gymnastics,
  ),
  _ExerciseInfo(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    category: 'Cardio',
    difficulty: 'Beginner',
    description: 'A full-body cardiovascular exercise that elevates heart rate '
        'quickly. Excellent as a warm-up, conditioning drill, or active rest.',
    muscles: 'Full body · Deltoids · Hip abductors · Calves',
    cues: [
      'Start with feet together, arms at your sides',
      'Jump feet out wide while simultaneously raising arms overhead',
      'Land softly on the balls of your feet — cushion the impact',
      'Arms should be fully extended overhead at the top',
      'Immediately jump back to starting position in a controlled rhythm',
    ],
    mistakes: [
      'Landing heavily on heels (increases impact stress)',
      'Arms not fully extending overhead',
      'Losing rhythm and coordination over time',
      'Holding breath — maintain steady breathing throughout',
    ],
    icon: Icons.directions_run,
  ),
  _ExerciseInfo(
    id: 'plank',
    name: 'Plank',
    category: 'Core',
    difficulty: 'Beginner',
    description: 'An isometric core exercise that builds endurance in the '
        'abdominals, back, and shoulders. The foundation of core stability training.',
    muscles: 'Transverse abdominis · Rectus abdominis · Obliques · Glutes · Shoulders',
    cues: [
      'Position forearms on the floor, elbows under shoulders',
      'Body forms a straight line from head to heels — no sagging or piking',
      'Engage abs by drawing navel toward spine',
      'Squeeze glutes and quads to support the position',
      'Keep gaze at the floor, neck neutral — don\'t crane up',
    ],
    mistakes: [
      'Hips sagging down (most common — strains the lower back)',
      'Hips raised too high (piking)',
      'Holding breath — breathe steadily',
      'Elbows too far forward of the shoulders',
    ],
    icon: Icons.accessibility_new,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'All';
  final _categories = ['All', 'Legs', 'Arms', 'Cardio', 'Core'];

  List<_ExerciseInfo> get _filtered => _filter == 'All'
      ? _exercises
      : _exercises.where((e) => e.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat      = _categories[i];
                final selected = cat == _filter;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : cs.outline,
                  ),
                );
              },
            ),
          ),

          // Exercise list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ExerciseCard(info: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatefulWidget {
  final _ExerciseInfo info;
  const _ExerciseCard({required this.info});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final info = widget.info;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: _expanded
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(info.icon, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(info.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _Tag(info.category, AppColors.info),
                      const SizedBox(width: 6),
                      _Tag(info.difficulty, AppColors.health),
                    ]),
                  ]),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: cs.onSurfaceVariant,
                ),
              ]),
            ),
          ),

          // Expandable content
          if (_expanded) ...[
            Divider(height: 1, color: cs.outline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.description,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 12),
                  _InfoRow(Icons.accessibility_new_outlined, 'Muscles', info.muscles),
                  const SizedBox(height: 14),
                  _SubSection('Form Cues', Icons.check_circle_outline, AppColors.health, info.cues),
                  const SizedBox(height: 14),
                  _SubSection('Common Mistakes', Icons.warning_amber_outlined, AppColors.error, info.mistakes),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
    ]);
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _SubSection(this.title, this.icon, this.color, this.items);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 6),
          ...items.map((cue) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ', style: TextStyle(color: color)),
                  Expanded(child: Text(cue, style: const TextStyle(fontSize: 12, height: 1.4))),
                ]),
              )),
        ],
      );
}
