import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveTransferException implements Exception {
  final String message;

  const SaveTransferException(this.message);

  @override
  String toString() => message;
}

class SaveTransferService {
  static const String _prefix = 'ALCHEMONS_SAVE_V2:';
  static const String _legacyPrefix = 'ALCHEMONS_SAVE_V1:';
  static const int _maxCloudSaveBytes = 900 * 1024;
  static const Set<String> _protectedPreferenceKeys = {
    'account.device_id.v1',
    'account.pending_transfer_code',
  };

  final AlchemonsDatabase db;

  const SaveTransferService(this.db);

  Future<String> exportSaveCode({required String ownerAccountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in db.allTables) {
      try {
        final rows = await db.customSelect(
          'SELECT * FROM "${table.actualTableName}"',
          readsFrom: {table},
        ).get();

        tables[table.actualTableName] = rows
            .map(
              (row) => row.data.map(
                (key, value) => MapEntry(
                  key,
                  _encodeValue(
                    value,
                    context: '${table.actualTableName}.$key',
                  ),
                ),
              ),
            )
            .toList();
      } on SaveTransferException {
        rethrow;
      } catch (error) {
        if (_isMissingTableError(error)) {
          tables[table.actualTableName] = const <Map<String, dynamic>>[];
          continue;
        }
        throw SaveTransferException(
          'Failed to export table ${table.actualTableName}: $error',
        );
      }
    }

    final preferences = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_protectedPreferenceKeys.contains(key)) {
        continue;
      }
      try {
        preferences[key] = _encodeValue(
          prefs.get(key),
          context: 'prefs.$key',
        );
      } on SaveTransferException {
        rethrow;
      } catch (error) {
        throw SaveTransferException('Failed to export preference $key: $error');
      }
    }

    final payload = <String, dynamic>{
      'ownerAccountId': ownerAccountId,
      'schemaVersion': db.schemaVersion,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
      'preferences': preferences,
    };

    final saveCode = _encodePayload(payload);
    final saveCodeBytes = utf8.encode(saveCode).length;
    if (saveCodeBytes > _maxCloudSaveBytes) {
      throw const SaveTransferException(
        'This account backup is too large for cloud save storage.',
      );
    }
    return saveCode;
  }

  Future<void> importSaveCode(
    String rawCode, {
    required String ownerAccountId,
  }) async {
    final trimmed = rawCode.trim();
    if (!trimmed.startsWith(_prefix) && !trimmed.startsWith(_legacyPrefix)) {
      throw const SaveTransferException('Save code is missing the expected header.');
    }

    late final Map<String, dynamic> payload;
    try {
      final jsonText = _decodePayload(trimmed);
      payload = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      throw const SaveTransferException('Save code could not be decoded.');
    }

    final rawTables = payload['tables'];
    final rawPreferences = payload['preferences'];
    final payloadOwnerAccountId = payload['ownerAccountId'];
    if (rawTables is! Map<String, dynamic> || rawPreferences is! Map<String, dynamic>) {
      throw const SaveTransferException('Save code is missing required data.');
    }
    if (payloadOwnerAccountId is! String || payloadOwnerAccountId.isEmpty) {
      throw const SaveTransferException(
        'Save code is missing its account binding.',
      );
    }
    if (payloadOwnerAccountId != ownerAccountId) {
      throw const SaveTransferException(
        'This save belongs to a different account.',
      );
    }

    final tableByName = <String, TableInfo<Table, Object?>>{
      for (final table in db.allTables) table.actualTableName: table,
    };

    for (final tableName in rawTables.keys) {
      if (!tableByName.containsKey(tableName)) {
        throw SaveTransferException('Save code contains an unknown table: $tableName');
      }
    }

    await db.transaction(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      try {
        for (final table in db.allTables.toList().reversed) {
          await db.delete(table).go();
        }

        for (final entry in rawTables.entries) {
          final table = tableByName[entry.key]!;
          final rows = entry.value;
          if (rows is! List) {
            throw SaveTransferException('Table ${entry.key} has invalid row data.');
          }

          final columnsByName = <String, GeneratedColumn<Object>>{
            for (final column in table.$columns) column.$name: column,
          };

          for (final row in rows) {
            if (row is! Map<String, dynamic>) {
              throw SaveTransferException(
                'Table ${entry.key} contains an invalid row.',
              );
            }

            final columnNames = <String>[];
            final variables = <Variable<Object>>[];
            for (final cell in row.entries) {
              final column = columnsByName[cell.key];
              if (column == null) {
                throw SaveTransferException(
                  'Table ${entry.key} contains an unknown column: ${cell.key}',
                );
              }
              final decoded = _decodeValue(cell.value);
              columnNames.add(cell.key);
              variables.add(_variableForValue(decoded));
            }

            final placeholders = List.filled(columnNames.length, '?').join(', ');
            final quotedColumns = columnNames
                .map((name) => '"$name"')
                .join(', ');

            await db.customInsert(
              'INSERT OR REPLACE INTO "${entry.key}" ($quotedColumns) VALUES ($placeholders)',
              variables: variables,
              updates: {table},
            );
          }
        }
      } finally {
        await db.customStatement('PRAGMA foreign_keys = ON');
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final protectedValues = <String, Object?>{};
    for (final key in _protectedPreferenceKeys) {
      protectedValues[key] = prefs.get(key);
    }
    await prefs.clear();
    for (final entry in protectedValues.entries) {
      await _writePreference(prefs, entry.key, entry.value);
    }
    for (final entry in rawPreferences.entries) {
      if (_protectedPreferenceKeys.contains(entry.key)) {
        continue;
      }
      await _writePreference(prefs, entry.key, _decodeValue(entry.value));
    }
  }

  dynamic _encodeValue(Object? value, {required String context}) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return <String, dynamic>{
        'type': 'datetime',
        'value': value.toUtc().toIso8601String(),
      };
    }
    if (value is Uint8List) {
      return <String, dynamic>{
        'type': 'bytes',
        'value': base64Encode(value),
      };
    }
    if (value is List<String>) {
      return <String, dynamic>{
        'type': 'string_list',
        'value': value,
      };
    }
    if (value is List) {
      return <String, dynamic>{
        'type': 'string_list',
        'value': value.map((item) => item.toString()).toList(),
      };
    }
    throw SaveTransferException(
      'Unsupported save value type at $context: ${value.runtimeType}',
    );
  }

  dynamic _decodeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      final type = value['type'];
      switch (type) {
        case 'datetime':
          return DateTime.parse(value['value'] as String);
        case 'bytes':
          return base64Decode(value['value'] as String);
        case 'string_list':
          return (value['value'] as List).map((item) => item.toString()).toList();
      }
    }
    throw const SaveTransferException('Save code contains an unsupported value.');
  }

  Future<void> _writePreference(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is List<String>) {
      await prefs.setStringList(key, value);
      return;
    }
    throw SaveTransferException('Preference $key has an unsupported type.');
  }

  bool _isMissingTableError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('no such table');
  }

  Variable<Object> _variableForValue(dynamic value) {
    if (value == null) {
      return const Variable<Object>(null);
    }
    return Variable<Object>(value as Object);
  }

  String _encodePayload(Map<String, dynamic> payload) {
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final compressedBytes = GZipEncoder().encodeBytes(jsonBytes, level: 9);
    final encoded = base64UrlEncode(compressedBytes);
    return '$_prefix$encoded';
  }

  String _decodePayload(String rawCode) {
    if (rawCode.startsWith(_prefix)) {
      final compressedBytes = base64Url.decode(rawCode.substring(_prefix.length));
      final jsonBytes = GZipDecoder().decodeBytes(compressedBytes);
      return utf8.decode(jsonBytes);
    }

    final legacyBytes = base64Url.decode(rawCode.substring(_legacyPrefix.length));
    return utf8.decode(Uint8List.fromList(legacyBytes));
  }
}
