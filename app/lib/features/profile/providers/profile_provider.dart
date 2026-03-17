import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/storage/secure_storage.dart';

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier() : super(const UserProfile()) {
    _load();
  }

  Future<void> _load() async {
    // 1. Show cached local profile immediately (fast)
    final cached = await SecureStorage.instance.readProfile();
    if (cached != null) {
      try {
        state = UserProfile.fromJsonString(cached);
      } catch (_) {}
    }

    // 2. Fetch from backend and update
    try {
      final data = await ApiService.instance.getProfile();
      final profile = _fromApiMap(data);
      state = profile;
      await SecureStorage.instance.writeProfile(profile.toJsonString());
    } catch (_) {
      // Network unavailable — keep local cache
    }
  }

  Future<void> save(UserProfile profile) async {
    state = profile;
    // Persist locally immediately (optimistic)
    await SecureStorage.instance.writeProfile(profile.toJsonString());
    // Sync to backend
    try {
      await ApiService.instance.saveProfile(_toApiMap(profile));
    } catch (e, st) {
      // ignore: avoid_print
      print('[ProfileProvider] saveProfile error: $e\n$st');
      rethrow;
    }
  }

  static UserProfile _fromApiMap(Map<String, dynamic> m) {
    DateTime? dob;
    if (m['date_of_birth'] != null) {
      try { dob = DateTime.parse(m['date_of_birth'] as String); } catch (_) {}
    }
    return UserProfile(
      displayName:          m['display_name']          as String?,
      dateOfBirth:          dob,
      gender:               _enumFromName(Gender.values,        m['gender']         as String?),
      heightCm:             (m['height_cm']             as num?)?.toDouble(),
      weightKg:             (m['weight_kg']             as num?)?.toDouble(),
      targetWeightKg:       (m['target_weight_kg']      as num?)?.toDouble(),
      fitnessLevel:         _enumFromName(FitnessLevel.values,  m['fitness_level']  as String?),
      primaryGoal:          _enumFromName(PrimaryGoal.values,   m['primary_goal']   as String?),
      weeklyWorkoutTarget:  m['weekly_workout_target']  as int?,
      equipment:            _enumFromName(EquipmentType.values, m['equipment']      as String?),
      activityLevel:        _enumFromName(ActivityLevel.values, m['activity_level'] as String?),
      injuries:             m['injuries']               as String?,
      unitSystem:           _enumFromName(UnitSystem.values,    m['unit_system']    as String?) ?? UnitSystem.metric,
    );
  }

  static Map<String, dynamic> _toApiMap(UserProfile p) => {
    'display_name':          p.displayName,
    'date_of_birth':         p.dateOfBirth?.toIso8601String().split('T').first,
    'gender':                _toSnake(p.gender?.name),
    'height_cm':             p.heightCm,
    'weight_kg':             p.weightKg,
    'target_weight_kg':      p.targetWeightKg,
    'fitness_level':         _toSnake(p.fitnessLevel?.name),
    'primary_goal':          _toSnake(p.primaryGoal?.name),
    'weekly_workout_target': p.weeklyWorkoutTarget,
    'equipment':             _toSnake(p.equipment?.name),
    'activity_level':        _toSnake(p.activityLevel?.name),
    'injuries':              p.injuries,
    'unit_system':           p.unitSystem.name,
  };

  /// Convert camelCase Dart enum name → snake_case for the API.
  static String? _toSnake(String? name) {
    if (name == null) return null;
    return name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
  }

  /// Convert snake_case API value → camelCase to match the Dart enum name.
  static String? _toCamel(String? name) {
    if (name == null) return null;
    return name.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m.group(1)!.toUpperCase(),
    );
  }

  static T? _enumFromName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    final camel = _toCamel(name) ?? name;
    try {
      return values.firstWhere((e) => e.name == camel);
    } catch (_) {
      return null;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((_) => ProfileNotifier());
