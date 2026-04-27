import 'package:hive/hive.dart';

class UserPreferences {
  UserPreferences({
    required this.currency,
    required this.dateFormat,
    required this.notificationsEnabled,
    required this.cloudSyncEnabled,
  });

  final String currency;
  final String dateFormat;
  final bool notificationsEnabled;
  final bool cloudSyncEnabled;

  UserPreferences copyWith({
    String? currency,
    String? dateFormat,
    bool? notificationsEnabled,
    bool? cloudSyncEnabled,
  }) {
    return UserPreferences(
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    );
  }
}

class UserPreferencesAdapter extends TypeAdapter<UserPreferences> {
  @override
  final int typeId = 4;

  @override
  UserPreferences read(BinaryReader reader) {
    return UserPreferences(
      currency: reader.readString(),
      dateFormat: reader.readString(),
      notificationsEnabled: reader.readBool(),
      cloudSyncEnabled: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, UserPreferences obj) {
    writer
      ..writeString(obj.currency)
      ..writeString(obj.dateFormat)
      ..writeBool(obj.notificationsEnabled)
      ..writeBool(obj.cloudSyncEnabled);
  }
}
