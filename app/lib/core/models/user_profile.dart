import 'dart:convert';

enum Gender { male, female, other, preferNotToSay }
enum FitnessLevel { beginner, intermediate, advanced }
enum PrimaryGoal { weightLoss, muscleGain, endurance, flexibility, generalFitness }
enum EquipmentType { none, home, gym }
enum ActivityLevel { sedentary, light, moderate, active, veryActive }
enum UnitSystem { metric, imperial }

extension GenderLabel on Gender {
  String get label => switch (this) {
    Gender.male             => 'Male',
    Gender.female           => 'Female',
    Gender.other            => 'Other',
    Gender.preferNotToSay   => 'Prefer not to say',
  };
}

extension FitnessLevelLabel on FitnessLevel {
  String get label => switch (this) {
    FitnessLevel.beginner     => 'Beginner',
    FitnessLevel.intermediate => 'Intermediate',
    FitnessLevel.advanced     => 'Advanced',
  };
}

extension PrimaryGoalLabel on PrimaryGoal {
  String get label => switch (this) {
    PrimaryGoal.weightLoss      => 'Weight Loss',
    PrimaryGoal.muscleGain      => 'Muscle Gain',
    PrimaryGoal.endurance       => 'Endurance',
    PrimaryGoal.flexibility     => 'Flexibility',
    PrimaryGoal.generalFitness  => 'General Fitness',
  };
}

extension EquipmentLabel on EquipmentType {
  String get label => switch (this) {
    EquipmentType.none => 'No Equipment',
    EquipmentType.home => 'Home Gym',
    EquipmentType.gym  => 'Full Gym',
  };
}

extension ActivityLevelLabel on ActivityLevel {
  String get label => switch (this) {
    ActivityLevel.sedentary  => 'Sedentary',
    ActivityLevel.light      => 'Lightly Active',
    ActivityLevel.moderate   => 'Moderately Active',
    ActivityLevel.active     => 'Active',
    ActivityLevel.veryActive => 'Very Active',
  };
}

class UserProfile {
  final String? displayName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final FitnessLevel? fitnessLevel;
  final PrimaryGoal? primaryGoal;
  final int? weeklyWorkoutTarget; // 1–7 days/week
  final EquipmentType? equipment;
  final ActivityLevel? activityLevel;
  final String? injuries;
  final UnitSystem unitSystem;

  const UserProfile({
    this.displayName,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.fitnessLevel,
    this.primaryGoal,
    this.weeklyWorkoutTarget,
    this.equipment,
    this.activityLevel,
    this.injuries,
    this.unitSystem = UnitSystem.metric,
  });

  // ── Derived ──────────────────────────────────────────────────────────────

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final hm = heightCm! / 100;
    return weightKg! / (hm * hm);
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return 'Underweight';
    if (b < 25)   return 'Normal';
    if (b < 30)   return 'Overweight';
    return 'Obese';
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  String get displayHeight {
    if (heightCm == null) return '—';
    if (unitSystem == UnitSystem.imperial) {
      final totalInches = heightCm! / 2.54;
      final ft = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return "${ft}′${inches}″";
    }
    return '${heightCm!.round()} cm';
  }

  String get displayWeight {
    if (weightKg == null) return '—';
    if (unitSystem == UnitSystem.imperial) {
      return '${(weightKg! * 2.20462).round()} lbs';
    }
    return '${weightKg!.round()} kg';
  }

  String get displayTargetWeight {
    if (targetWeightKg == null) return '—';
    if (unitSystem == UnitSystem.imperial) {
      return '${(targetWeightKg! * 2.20462).round()} lbs';
    }
    return '${targetWeightKg!.round()} kg';
  }

  String get initials {
    if (displayName == null || displayName!.isEmpty) return '?';
    final parts = displayName!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName!.substring(0, displayName!.length.clamp(1, 2)).toUpperCase();
  }

  /// Short summary line for LLM context.
  String toLlmContext() {
    final parts = <String>[];
    if (displayName != null) parts.add('Name: $displayName');
    if (age != null) parts.add('Age: $age');
    if (gender != null) parts.add('Gender: ${gender!.label}');
    if (heightCm != null) parts.add('Height: ${heightCm!.round()}cm');
    if (weightKg != null) parts.add('Weight: ${weightKg!.round()}kg');
    if (targetWeightKg != null) parts.add('Target weight: ${targetWeightKg!.round()}kg');
    if (fitnessLevel != null) parts.add('Fitness level: ${fitnessLevel!.label}');
    if (primaryGoal != null) parts.add('Goal: ${primaryGoal!.label}');
    if (weeklyWorkoutTarget != null) parts.add('Weekly target: $weeklyWorkoutTarget days/week');
    if (activityLevel != null) parts.add('Activity: ${activityLevel!.label}');
    if (equipment != null) parts.add('Equipment: ${equipment!.label}');
    if (injuries != null && injuries!.isNotEmpty) parts.add('Health notes: $injuries');
    if (parts.isEmpty) return '';
    return 'User profile — ${parts.join(', ')}.';
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  UserProfile copyWith({
    String?        displayName,
    DateTime?      dateOfBirth,
    Gender?        gender,
    double?        heightCm,
    double?        weightKg,
    double?        targetWeightKg,
    FitnessLevel?  fitnessLevel,
    PrimaryGoal?   primaryGoal,
    int?           weeklyWorkoutTarget,
    EquipmentType? equipment,
    ActivityLevel? activityLevel,
    String?        injuries,
    UnitSystem?    unitSystem,
    bool clearDob         = false,
    bool clearGender      = false,
    bool clearHeight      = false,
    bool clearWeight      = false,
    bool clearTargetWeight= false,
    bool clearFitnessLevel= false,
    bool clearPrimaryGoal = false,
    bool clearWeeklyTarget= false,
    bool clearEquipment   = false,
    bool clearActivity    = false,
    bool clearInjuries    = false,
  }) => UserProfile(
    displayName:        displayName        ?? this.displayName,
    dateOfBirth:        clearDob           ? null : (dateOfBirth      ?? this.dateOfBirth),
    gender:             clearGender        ? null : (gender           ?? this.gender),
    heightCm:           clearHeight        ? null : (heightCm         ?? this.heightCm),
    weightKg:           clearWeight        ? null : (weightKg         ?? this.weightKg),
    targetWeightKg:     clearTargetWeight  ? null : (targetWeightKg   ?? this.targetWeightKg),
    fitnessLevel:       clearFitnessLevel  ? null : (fitnessLevel     ?? this.fitnessLevel),
    primaryGoal:        clearPrimaryGoal   ? null : (primaryGoal      ?? this.primaryGoal),
    weeklyWorkoutTarget:clearWeeklyTarget  ? null : (weeklyWorkoutTarget ?? this.weeklyWorkoutTarget),
    equipment:          clearEquipment     ? null : (equipment        ?? this.equipment),
    activityLevel:      clearActivity      ? null : (activityLevel    ?? this.activityLevel),
    injuries:           clearInjuries      ? null : (injuries         ?? this.injuries),
    unitSystem:         unitSystem         ?? this.unitSystem,
  );

  Map<String, dynamic> toJson() => {
    if (displayName != null)         'display_name':          displayName,
    if (dateOfBirth != null)         'date_of_birth':         dateOfBirth!.toIso8601String(),
    if (gender != null)              'gender':                gender!.name,
    if (heightCm != null)            'height_cm':             heightCm,
    if (weightKg != null)            'weight_kg':             weightKg,
    if (targetWeightKg != null)      'target_weight_kg':      targetWeightKg,
    if (fitnessLevel != null)        'fitness_level':         fitnessLevel!.name,
    if (primaryGoal != null)         'primary_goal':          primaryGoal!.name,
    if (weeklyWorkoutTarget != null) 'weekly_workout_target': weeklyWorkoutTarget,
    if (equipment != null)           'equipment':             equipment!.name,
    if (activityLevel != null)       'activity_level':        activityLevel!.name,
    if (injuries != null)            'injuries':              injuries,
    'unit_system':                   unitSystem.name,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    displayName:         j['display_name']          as String?,
    dateOfBirth:         j['date_of_birth'] != null
        ? DateTime.tryParse(j['date_of_birth'] as String)
        : null,
    gender:              _enumFromName(Gender.values,        j['gender']         as String?),
    heightCm:            (j['height_cm']          as num?)?.toDouble(),
    weightKg:            (j['weight_kg']          as num?)?.toDouble(),
    targetWeightKg:      (j['target_weight_kg']   as num?)?.toDouble(),
    fitnessLevel:        _enumFromName(FitnessLevel.values,  j['fitness_level']  as String?),
    primaryGoal:         _enumFromName(PrimaryGoal.values,   j['primary_goal']   as String?),
    weeklyWorkoutTarget: j['weekly_workout_target'] as int?,
    equipment:           _enumFromName(EquipmentType.values, j['equipment']      as String?),
    activityLevel:       _enumFromName(ActivityLevel.values, j['activity_level'] as String?),
    injuries:            j['injuries']             as String?,
    unitSystem:          _enumFromName(UnitSystem.values,    j['unit_system']    as String?) ??
                         UnitSystem.metric,
  );

  static T? _enumFromName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
