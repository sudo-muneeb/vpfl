// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlaybackHistoriesTable extends PlaybackHistories
    with TableInfo<$PlaybackHistoriesTable, PlaybackHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _watchCountMeta = const VerificationMeta(
    'watchCount',
  );
  @override
  late final GeneratedColumn<int> watchCount = GeneratedColumn<int>(
    'watch_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uri,
    displayName,
    lastOpenedAt,
    positionMs,
    durationMs,
    watchCount,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('watch_count')) {
      context.handle(
        _watchCountMeta,
        watchCount.isAcceptableOrUnknown(data['watch_count']!, _watchCountMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  PlaybackHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackHistory(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      watchCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watch_count'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $PlaybackHistoriesTable createAlias(String alias) {
    return $PlaybackHistoriesTable(attachedDatabase, alias);
  }
}

class PlaybackHistory extends DataClass implements Insertable<PlaybackHistory> {
  final String uri;
  final String displayName;
  final DateTime lastOpenedAt;
  final int positionMs;
  final int durationMs;
  final int watchCount;
  final bool completed;
  const PlaybackHistory({
    required this.uri,
    required this.displayName,
    required this.lastOpenedAt,
    required this.positionMs,
    required this.durationMs,
    required this.watchCount,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['display_name'] = Variable<String>(displayName);
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['watch_count'] = Variable<int>(watchCount);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PlaybackHistoriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackHistoriesCompanion(
      uri: Value(uri),
      displayName: Value(displayName),
      lastOpenedAt: Value(lastOpenedAt),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      watchCount: Value(watchCount),
      completed: Value(completed),
    );
  }

  factory PlaybackHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackHistory(
      uri: serializer.fromJson<String>(json['uri']),
      displayName: serializer.fromJson<String>(json['displayName']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      watchCount: serializer.fromJson<int>(json['watchCount']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'displayName': serializer.toJson<String>(displayName),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'watchCount': serializer.toJson<int>(watchCount),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PlaybackHistory copyWith({
    String? uri,
    String? displayName,
    DateTime? lastOpenedAt,
    int? positionMs,
    int? durationMs,
    int? watchCount,
    bool? completed,
  }) => PlaybackHistory(
    uri: uri ?? this.uri,
    displayName: displayName ?? this.displayName,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    watchCount: watchCount ?? this.watchCount,
    completed: completed ?? this.completed,
  );
  PlaybackHistory copyWithCompanion(PlaybackHistoriesCompanion data) {
    return PlaybackHistory(
      uri: data.uri.present ? data.uri.value : this.uri,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      watchCount: data.watchCount.present
          ? data.watchCount.value
          : this.watchCount,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistory(')
          ..write('uri: $uri, ')
          ..write('displayName: $displayName, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('watchCount: $watchCount, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uri,
    displayName,
    lastOpenedAt,
    positionMs,
    durationMs,
    watchCount,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackHistory &&
          other.uri == this.uri &&
          other.displayName == this.displayName &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.watchCount == this.watchCount &&
          other.completed == this.completed);
}

class PlaybackHistoriesCompanion extends UpdateCompanion<PlaybackHistory> {
  final Value<String> uri;
  final Value<String> displayName;
  final Value<DateTime> lastOpenedAt;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int> watchCount;
  final Value<bool> completed;
  final Value<int> rowid;
  const PlaybackHistoriesCompanion({
    this.uri = const Value.absent(),
    this.displayName = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.watchCount = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackHistoriesCompanion.insert({
    required String uri,
    required String displayName,
    required DateTime lastOpenedAt,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.watchCount = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       displayName = Value(displayName),
       lastOpenedAt = Value(lastOpenedAt);
  static Insertable<PlaybackHistory> custom({
    Expression<String>? uri,
    Expression<String>? displayName,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<int>? watchCount,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (displayName != null) 'display_name': displayName,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (watchCount != null) 'watch_count': watchCount,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackHistoriesCompanion copyWith({
    Value<String>? uri,
    Value<String>? displayName,
    Value<DateTime>? lastOpenedAt,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<int>? watchCount,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return PlaybackHistoriesCompanion(
      uri: uri ?? this.uri,
      displayName: displayName ?? this.displayName,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      watchCount: watchCount ?? this.watchCount,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (watchCount.present) {
      map['watch_count'] = Variable<int>(watchCount.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoriesCompanion(')
          ..write('uri: $uri, ')
          ..write('displayName: $displayName, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('watchCount: $watchCount, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedFoldersTable extends SavedFolders
    with TableInfo<$SavedFoldersTable, SavedFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScannedAtMeta = const VerificationMeta(
    'lastScannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScannedAt =
      GeneratedColumn<DateTime>(
        'last_scanned_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    displayName,
    addedAt,
    lastScannedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_scanned_at')) {
      context.handle(
        _lastScannedAtMeta,
        lastScannedAt.isAcceptableOrUnknown(
          data['last_scanned_at']!,
          _lastScannedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastScannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scanned_at'],
      ),
    );
  }

  @override
  $SavedFoldersTable createAlias(String alias) {
    return $SavedFoldersTable(attachedDatabase, alias);
  }
}

class SavedFolder extends DataClass implements Insertable<SavedFolder> {
  final int id;
  final String path;
  final String displayName;
  final DateTime addedAt;
  final DateTime? lastScannedAt;
  const SavedFolder({
    required this.id,
    required this.path,
    required this.displayName,
    required this.addedAt,
    this.lastScannedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['display_name'] = Variable<String>(displayName);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastScannedAt != null) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt);
    }
    return map;
  }

  SavedFoldersCompanion toCompanion(bool nullToAbsent) {
    return SavedFoldersCompanion(
      id: Value(id),
      path: Value(path),
      displayName: Value(displayName),
      addedAt: Value(addedAt),
      lastScannedAt: lastScannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScannedAt),
    );
  }

  factory SavedFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedFolder(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      displayName: serializer.fromJson<String>(json['displayName']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastScannedAt: serializer.fromJson<DateTime?>(json['lastScannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'displayName': serializer.toJson<String>(displayName),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastScannedAt': serializer.toJson<DateTime?>(lastScannedAt),
    };
  }

  SavedFolder copyWith({
    int? id,
    String? path,
    String? displayName,
    DateTime? addedAt,
    Value<DateTime?> lastScannedAt = const Value.absent(),
  }) => SavedFolder(
    id: id ?? this.id,
    path: path ?? this.path,
    displayName: displayName ?? this.displayName,
    addedAt: addedAt ?? this.addedAt,
    lastScannedAt: lastScannedAt.present
        ? lastScannedAt.value
        : this.lastScannedAt,
  );
  SavedFolder copyWithCompanion(SavedFoldersCompanion data) {
    return SavedFolder(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScannedAt: data.lastScannedAt.present
          ? data.lastScannedAt.value
          : this.lastScannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedFolder(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('displayName: $displayName, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScannedAt: $lastScannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, path, displayName, addedAt, lastScannedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedFolder &&
          other.id == this.id &&
          other.path == this.path &&
          other.displayName == this.displayName &&
          other.addedAt == this.addedAt &&
          other.lastScannedAt == this.lastScannedAt);
}

class SavedFoldersCompanion extends UpdateCompanion<SavedFolder> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> displayName;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastScannedAt;
  const SavedFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.displayName = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
  });
  SavedFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String displayName,
    required DateTime addedAt,
    this.lastScannedAt = const Value.absent(),
  }) : path = Value(path),
       displayName = Value(displayName),
       addedAt = Value(addedAt);
  static Insertable<SavedFolder> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? displayName,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastScannedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (displayName != null) 'display_name': displayName,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScannedAt != null) 'last_scanned_at': lastScannedAt,
    });
  }

  SavedFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? displayName,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastScannedAt,
  }) {
    return SavedFoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt ?? this.addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastScannedAt.present) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('displayName: $displayName, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScannedAt: $lastScannedAt')
          ..write(')'))
        .toString();
  }
}

class $LibraryMediaItemsTable extends LibraryMediaItems
    with TableInfo<$LibraryMediaItemsTable, LibraryMediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryMediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_folders (id)',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexedAtMeta = const VerificationMeta(
    'indexedAt',
  );
  @override
  late final GeneratedColumn<DateTime> indexedAt = GeneratedColumn<DateTime>(
    'indexed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uri,
    folderId,
    path,
    displayName,
    sizeBytes,
    modifiedAt,
    indexedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryMediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('indexed_at')) {
      context.handle(
        _indexedAtMeta,
        indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_indexedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  LibraryMediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryMediaItem(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
      indexedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}indexed_at'],
      )!,
    );
  }

  @override
  $LibraryMediaItemsTable createAlias(String alias) {
    return $LibraryMediaItemsTable(attachedDatabase, alias);
  }
}

class LibraryMediaItem extends DataClass
    implements Insertable<LibraryMediaItem> {
  final String uri;
  final int folderId;
  final String path;
  final String displayName;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime indexedAt;
  const LibraryMediaItem({
    required this.uri,
    required this.folderId,
    required this.path,
    required this.displayName,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.indexedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['folder_id'] = Variable<int>(folderId);
    map['path'] = Variable<String>(path);
    map['display_name'] = Variable<String>(displayName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    map['indexed_at'] = Variable<DateTime>(indexedAt);
    return map;
  }

  LibraryMediaItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryMediaItemsCompanion(
      uri: Value(uri),
      folderId: Value(folderId),
      path: Value(path),
      displayName: Value(displayName),
      sizeBytes: Value(sizeBytes),
      modifiedAt: Value(modifiedAt),
      indexedAt: Value(indexedAt),
    );
  }

  factory LibraryMediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryMediaItem(
      uri: serializer.fromJson<String>(json['uri']),
      folderId: serializer.fromJson<int>(json['folderId']),
      path: serializer.fromJson<String>(json['path']),
      displayName: serializer.fromJson<String>(json['displayName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
      indexedAt: serializer.fromJson<DateTime>(json['indexedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'folderId': serializer.toJson<int>(folderId),
      'path': serializer.toJson<String>(path),
      'displayName': serializer.toJson<String>(displayName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
      'indexedAt': serializer.toJson<DateTime>(indexedAt),
    };
  }

  LibraryMediaItem copyWith({
    String? uri,
    int? folderId,
    String? path,
    String? displayName,
    int? sizeBytes,
    DateTime? modifiedAt,
    DateTime? indexedAt,
  }) => LibraryMediaItem(
    uri: uri ?? this.uri,
    folderId: folderId ?? this.folderId,
    path: path ?? this.path,
    displayName: displayName ?? this.displayName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    indexedAt: indexedAt ?? this.indexedAt,
  );
  LibraryMediaItem copyWithCompanion(LibraryMediaItemsCompanion data) {
    return LibraryMediaItem(
      uri: data.uri.present ? data.uri.value : this.uri,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      path: data.path.present ? data.path.value : this.path,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryMediaItem(')
          ..write('uri: $uri, ')
          ..write('folderId: $folderId, ')
          ..write('path: $path, ')
          ..write('displayName: $displayName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('indexedAt: $indexedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uri,
    folderId,
    path,
    displayName,
    sizeBytes,
    modifiedAt,
    indexedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryMediaItem &&
          other.uri == this.uri &&
          other.folderId == this.folderId &&
          other.path == this.path &&
          other.displayName == this.displayName &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedAt == this.modifiedAt &&
          other.indexedAt == this.indexedAt);
}

class LibraryMediaItemsCompanion extends UpdateCompanion<LibraryMediaItem> {
  final Value<String> uri;
  final Value<int> folderId;
  final Value<String> path;
  final Value<String> displayName;
  final Value<int> sizeBytes;
  final Value<DateTime> modifiedAt;
  final Value<DateTime> indexedAt;
  final Value<int> rowid;
  const LibraryMediaItemsCompanion({
    this.uri = const Value.absent(),
    this.folderId = const Value.absent(),
    this.path = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryMediaItemsCompanion.insert({
    required String uri,
    required int folderId,
    required String path,
    required String displayName,
    required int sizeBytes,
    required DateTime modifiedAt,
    required DateTime indexedAt,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       folderId = Value(folderId),
       path = Value(path),
       displayName = Value(displayName),
       sizeBytes = Value(sizeBytes),
       modifiedAt = Value(modifiedAt),
       indexedAt = Value(indexedAt);
  static Insertable<LibraryMediaItem> custom({
    Expression<String>? uri,
    Expression<int>? folderId,
    Expression<String>? path,
    Expression<String>? displayName,
    Expression<int>? sizeBytes,
    Expression<DateTime>? modifiedAt,
    Expression<DateTime>? indexedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (folderId != null) 'folder_id': folderId,
      if (path != null) 'path': path,
      if (displayName != null) 'display_name': displayName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (indexedAt != null) 'indexed_at': indexedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryMediaItemsCompanion copyWith({
    Value<String>? uri,
    Value<int>? folderId,
    Value<String>? path,
    Value<String>? displayName,
    Value<int>? sizeBytes,
    Value<DateTime>? modifiedAt,
    Value<DateTime>? indexedAt,
    Value<int>? rowid,
  }) {
    return LibraryMediaItemsCompanion(
      uri: uri ?? this.uri,
      folderId: folderId ?? this.folderId,
      path: path ?? this.path,
      displayName: displayName ?? this.displayName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      indexedAt: indexedAt ?? this.indexedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<DateTime>(indexedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryMediaItemsCompanion(')
          ..write('uri: $uri, ')
          ..write('folderId: $folderId, ')
          ..write('path: $path, ')
          ..write('displayName: $displayName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlaybackHistoriesTable playbackHistories =
      $PlaybackHistoriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SavedFoldersTable savedFolders = $SavedFoldersTable(this);
  late final $LibraryMediaItemsTable libraryMediaItems =
      $LibraryMediaItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    playbackHistories,
    appSettings,
    savedFolders,
    libraryMediaItems,
  ];
}

typedef $$PlaybackHistoriesTableCreateCompanionBuilder =
    PlaybackHistoriesCompanion Function({
      required String uri,
      required String displayName,
      required DateTime lastOpenedAt,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> watchCount,
      Value<bool> completed,
      Value<int> rowid,
    });
typedef $$PlaybackHistoriesTableUpdateCompanionBuilder =
    PlaybackHistoriesCompanion Function({
      Value<String> uri,
      Value<String> displayName,
      Value<DateTime> lastOpenedAt,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> watchCount,
      Value<bool> completed,
      Value<int> rowid,
    });

class $$PlaybackHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackHistoriesTable> {
  $$PlaybackHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchCount => $composableBuilder(
    column: $table.watchCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackHistoriesTable> {
  $$PlaybackHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchCount => $composableBuilder(
    column: $table.watchCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackHistoriesTable> {
  $$PlaybackHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get watchCount => $composableBuilder(
    column: $table.watchCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$PlaybackHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackHistoriesTable,
          PlaybackHistory,
          $$PlaybackHistoriesTableFilterComposer,
          $$PlaybackHistoriesTableOrderingComposer,
          $$PlaybackHistoriesTableAnnotationComposer,
          $$PlaybackHistoriesTableCreateCompanionBuilder,
          $$PlaybackHistoriesTableUpdateCompanionBuilder,
          (
            PlaybackHistory,
            BaseReferences<
              _$AppDatabase,
              $PlaybackHistoriesTable,
              PlaybackHistory
            >,
          ),
          PlaybackHistory,
          PrefetchHooks Function()
        > {
  $$PlaybackHistoriesTableTableManager(
    _$AppDatabase db,
    $PlaybackHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> watchCount = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackHistoriesCompanion(
                uri: uri,
                displayName: displayName,
                lastOpenedAt: lastOpenedAt,
                positionMs: positionMs,
                durationMs: durationMs,
                watchCount: watchCount,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                required String displayName,
                required DateTime lastOpenedAt,
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> watchCount = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackHistoriesCompanion.insert(
                uri: uri,
                displayName: displayName,
                lastOpenedAt: lastOpenedAt,
                positionMs: positionMs,
                durationMs: durationMs,
                watchCount: watchCount,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackHistoriesTable, PlaybackHistory>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlaybackHistoriesTable,
                    PlaybackHistory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackHistoriesTable,
      PlaybackHistory,
      $$PlaybackHistoriesTableFilterComposer,
      $$PlaybackHistoriesTableOrderingComposer,
      $$PlaybackHistoriesTableAnnotationComposer,
      $$PlaybackHistoriesTableCreateCompanionBuilder,
      $$PlaybackHistoriesTableUpdateCompanionBuilder,
      (
        PlaybackHistory,
        BaseReferences<_$AppDatabase, $PlaybackHistoriesTable, PlaybackHistory>,
      ),
      PlaybackHistory,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$SavedFoldersTableCreateCompanionBuilder =
    SavedFoldersCompanion Function({
      Value<int> id,
      required String path,
      required String displayName,
      required DateTime addedAt,
      Value<DateTime?> lastScannedAt,
    });
typedef $$SavedFoldersTableUpdateCompanionBuilder =
    SavedFoldersCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<String> displayName,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScannedAt,
    });

final class $$SavedFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $SavedFoldersTable, SavedFolder> {
  $$SavedFoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LibraryMediaItemsTable, List<LibraryMediaItem>>
  _libraryMediaItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryMediaItems,
        aliasName: 'saved_folders__id__library_media_items__folder_id',
      );

  $$LibraryMediaItemsTableProcessedTableManager get libraryMediaItemsRefs {
    final manager = $$LibraryMediaItemsTableTableManager(
      $_db,
      $_db.libraryMediaItems,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryMediaItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $SavedFoldersTable> {
  $$SavedFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryMediaItemsRefs(
    Expression<bool> Function($$LibraryMediaItemsTableFilterComposer f) f,
  ) {
    final $$LibraryMediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryMediaItems,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryMediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.libraryMediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedFoldersTable> {
  $$SavedFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedFoldersTable> {
  $$SavedFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => column,
  );

  Expression<T> libraryMediaItemsRefs<T extends Object>(
    Expression<T> Function($$LibraryMediaItemsTableAnnotationComposer a) f,
  ) {
    final $$LibraryMediaItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryMediaItems,
          getReferencedColumn: (t) => t.folderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryMediaItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.libraryMediaItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedFoldersTable,
          SavedFolder,
          $$SavedFoldersTableFilterComposer,
          $$SavedFoldersTableOrderingComposer,
          $$SavedFoldersTableAnnotationComposer,
          $$SavedFoldersTableCreateCompanionBuilder,
          $$SavedFoldersTableUpdateCompanionBuilder,
          (SavedFolder, $$SavedFoldersTableReferences),
          SavedFolder,
          PrefetchHooks Function({bool libraryMediaItemsRefs})
        > {
  $$SavedFoldersTableTableManager(_$AppDatabase db, $SavedFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScannedAt = const Value.absent(),
              }) => SavedFoldersCompanion(
                id: id,
                path: path,
                displayName: displayName,
                addedAt: addedAt,
                lastScannedAt: lastScannedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String displayName,
                required DateTime addedAt,
                Value<DateTime?> lastScannedAt = const Value.absent(),
              }) => SavedFoldersCompanion.insert(
                id: id,
                path: path,
                displayName: displayName,
                addedAt: addedAt,
                lastScannedAt: lastScannedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedFoldersTable, SavedFolder>(table),
                  $$SavedFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryMediaItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (libraryMediaItemsRefs) db.libraryMediaItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (libraryMediaItemsRefs)
                    await $_getPrefetchedData<
                      SavedFolder,
                      $SavedFoldersTable,
                      LibraryMediaItem
                    >(
                      currentTable: table,
                      referencedTable: $$SavedFoldersTableReferences
                          ._libraryMediaItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).libraryMediaItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedFoldersTable,
      SavedFolder,
      $$SavedFoldersTableFilterComposer,
      $$SavedFoldersTableOrderingComposer,
      $$SavedFoldersTableAnnotationComposer,
      $$SavedFoldersTableCreateCompanionBuilder,
      $$SavedFoldersTableUpdateCompanionBuilder,
      (SavedFolder, $$SavedFoldersTableReferences),
      SavedFolder,
      PrefetchHooks Function({bool libraryMediaItemsRefs})
    >;
typedef $$LibraryMediaItemsTableCreateCompanionBuilder =
    LibraryMediaItemsCompanion Function({
      required String uri,
      required int folderId,
      required String path,
      required String displayName,
      required int sizeBytes,
      required DateTime modifiedAt,
      required DateTime indexedAt,
      Value<int> rowid,
    });
typedef $$LibraryMediaItemsTableUpdateCompanionBuilder =
    LibraryMediaItemsCompanion Function({
      Value<String> uri,
      Value<int> folderId,
      Value<String> path,
      Value<String> displayName,
      Value<int> sizeBytes,
      Value<DateTime> modifiedAt,
      Value<DateTime> indexedAt,
      Value<int> rowid,
    });

final class $$LibraryMediaItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LibraryMediaItemsTable,
          LibraryMediaItem
        > {
  $$LibraryMediaItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedFoldersTable _folderIdTable(_$AppDatabase db) => db.savedFolders
      .createAlias('library_media_items__folder_id__saved_folders__id');

  $$SavedFoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$SavedFoldersTableTableManager(
      $_db,
      $_db.savedFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibraryMediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryMediaItemsTable> {
  $$LibraryMediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedFoldersTableFilterComposer get folderId {
    final $$SavedFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.savedFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedFoldersTableFilterComposer(
            $db: $db,
            $table: $db.savedFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryMediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryMediaItemsTable> {
  $$LibraryMediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedFoldersTableOrderingComposer get folderId {
    final $$SavedFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.savedFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.savedFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryMediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryMediaItemsTable> {
  $$LibraryMediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  $$SavedFoldersTableAnnotationComposer get folderId {
    final $$SavedFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.savedFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.savedFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryMediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryMediaItemsTable,
          LibraryMediaItem,
          $$LibraryMediaItemsTableFilterComposer,
          $$LibraryMediaItemsTableOrderingComposer,
          $$LibraryMediaItemsTableAnnotationComposer,
          $$LibraryMediaItemsTableCreateCompanionBuilder,
          $$LibraryMediaItemsTableUpdateCompanionBuilder,
          (LibraryMediaItem, $$LibraryMediaItemsTableReferences),
          LibraryMediaItem,
          PrefetchHooks Function({bool folderId})
        > {
  $$LibraryMediaItemsTableTableManager(
    _$AppDatabase db,
    $LibraryMediaItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryMediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryMediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryMediaItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<DateTime> indexedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryMediaItemsCompanion(
                uri: uri,
                folderId: folderId,
                path: path,
                displayName: displayName,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                required int folderId,
                required String path,
                required String displayName,
                required int sizeBytes,
                required DateTime modifiedAt,
                required DateTime indexedAt,
                Value<int> rowid = const Value.absent(),
              }) => LibraryMediaItemsCompanion.insert(
                uri: uri,
                folderId: folderId,
                path: path,
                displayName: displayName,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryMediaItemsTable, LibraryMediaItem>(table),
                  $$LibraryMediaItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$LibraryMediaItemsTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$LibraryMediaItemsTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LibraryMediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryMediaItemsTable,
      LibraryMediaItem,
      $$LibraryMediaItemsTableFilterComposer,
      $$LibraryMediaItemsTableOrderingComposer,
      $$LibraryMediaItemsTableAnnotationComposer,
      $$LibraryMediaItemsTableCreateCompanionBuilder,
      $$LibraryMediaItemsTableUpdateCompanionBuilder,
      (LibraryMediaItem, $$LibraryMediaItemsTableReferences),
      LibraryMediaItem,
      PrefetchHooks Function({bool folderId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlaybackHistoriesTableTableManager get playbackHistories =>
      $$PlaybackHistoriesTableTableManager(_db, _db.playbackHistories);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SavedFoldersTableTableManager get savedFolders =>
      $$SavedFoldersTableTableManager(_db, _db.savedFolders);
  $$LibraryMediaItemsTableTableManager get libraryMediaItems =>
      $$LibraryMediaItemsTableTableManager(_db, _db.libraryMediaItems);
}
