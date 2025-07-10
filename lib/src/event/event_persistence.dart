/// Event persistence and restoration system
///
/// This module provides capabilities for persisting events to storage
/// and restoring them for replay or analysis purposes.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../idl/idl.dart';
import 'types.dart';

/// Service for persisting and restoring events
class EventPersistenceService {
  final String _storageDirectory;
  final bool _enableCompression;
  final int _maxFileSize;
  final Duration _rotationInterval;

  late final Directory _storageDir;
  Timer? _rotationTimer;
  String? _currentLogFile;
  int _currentFileSize = 0;

  EventPersistenceService({
    required String storageDirectory,
    bool enableCompression = true,
    int maxFileSize = 10 * 1024 * 1024, // 10MB default
    Duration rotationInterval = const Duration(hours: 24),
  })  : _storageDirectory = storageDirectory,
        _enableCompression = enableCompression,
        _maxFileSize = maxFileSize,
        _rotationInterval = rotationInterval {
    _initializeStorage();
  }

  /// Initialize storage directory and rotation timer
  Future<void> _initializeStorage() async {
    _storageDir = Directory(_storageDirectory);
    if (!await _storageDir.exists()) {
      await _storageDir.create(recursive: true);
    }

    // Start rotation timer
    _rotationTimer = Timer.periodic(_rotationInterval, (_) => _rotateLogFile());

    // Create initial log file
    await _createNewLogFile();
  }

  /// Persist an event to storage
  Future<void> persistEvent(ParsedEvent<dynamic> event) async {
    final eventData = PersistedEvent(
      event: event,
      timestamp: DateTime.now(),
      programId: event.name, // This should be the actual program ID
    );

    final jsonData = json.encode(eventData.toJson());
    await _writeToLogFile(jsonData);
  }

  /// Persist multiple events in batch
  Future<void> persistEventBatch(List<ParsedEvent<dynamic>> events) async {
    final batch = events
        .map((event) => PersistedEvent(
              event: event,
              timestamp: DateTime.now(),
              programId: event.name, // This should be the actual program ID
            ))
        .toList();

    final batchData = {
      'batch': true,
      'timestamp': DateTime.now().toIso8601String(),
      'events': batch.map((e) => e.toJson()).toList(),
    };

    final jsonData = json.encode(batchData);
    await _writeToLogFile(jsonData);
  }

  /// Restore events from storage
  Stream<ParsedEvent<dynamic>> restoreEvents({
    DateTime? fromDate,
    DateTime? toDate,
    String? programId,
    String? eventName,
  }) async* {
    final files = await _getLogFiles();

    for (final file in files) {
      if (fromDate != null && _getFileDate(file) != null) {
        final fileDate = _getFileDate(file)!;
        if (fileDate.isBefore(fromDate)) continue;
      }

      await for (final event in _readEventsFromFile(file)) {
        // Apply filters
        if (toDate != null && event.timestamp.isAfter(toDate)) continue;
        if (programId != null && event.programId != programId) continue;
        if (eventName != null && event.event.name != eventName) continue;

        yield event.event;
      }
    }
  }

  /// Get event statistics from storage
  Future<EventPersistenceStats> getStatistics() async {
    final files = await _getLogFiles();
    int totalEvents = 0;
    int totalSize = 0;
    DateTime? oldestEvent;
    DateTime? newestEvent;

    for (final file in files) {
      final stat = await file.stat();
      totalSize += stat.size;

      await for (final event in _readEventsFromFile(file)) {
        totalEvents++;
        if (oldestEvent == null || event.timestamp.isBefore(oldestEvent)) {
          oldestEvent = event.timestamp;
        }
        if (newestEvent == null || event.timestamp.isAfter(newestEvent)) {
          newestEvent = event.timestamp;
        }
      }
    }

    return EventPersistenceStats(
      totalEvents: totalEvents,
      totalSizeBytes: totalSize,
      fileCount: files.length,
      oldestEvent: oldestEvent,
      newestEvent: newestEvent,
      compressionEnabled: _enableCompression,
    );
  }

  /// Clear all persisted events
  Future<void> clearEvents({DateTime? beforeDate}) async {
    final files = await _getLogFiles();

    for (final file in files) {
      if (beforeDate != null) {
        final fileDate = _getFileDate(file);
        if (fileDate != null && fileDate.isAfter(beforeDate)) continue;
      }

      await file.delete();
    }
  }

  /// Compact storage by removing old events and compressing
  Future<void> compactStorage({
    Duration? retentionPeriod,
    bool forceCompression = false,
  }) async {
    final cutoffDate = retentionPeriod != null
        ? DateTime.now().subtract(retentionPeriod)
        : null;

    if (cutoffDate != null) {
      await clearEvents(beforeDate: cutoffDate);
    }

    if (forceCompression && !_enableCompression) {
      // Re-write files with compression
      await _rewriteWithCompression();
    }
  }

  /// Write data to current log file
  Future<void> _writeToLogFile(String data) async {
    if (_currentLogFile == null) {
      await _createNewLogFile();
    }

    final file = File(_currentLogFile!);
    await file.writeAsString('$data\n', mode: FileMode.append);

    _currentFileSize += data.length + 1; // +1 for newline

    // Check if rotation is needed
    if (_currentFileSize >= _maxFileSize) {
      await _rotateLogFile();
    }
  }

  /// Create a new log file
  Future<void> _createNewLogFile() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final extension = _enableCompression ? '.jsonl.gz' : '.jsonl';
    _currentLogFile = '${_storageDir.path}/events_$timestamp$extension';
    _currentFileSize = 0;
  }

  /// Rotate current log file
  Future<void> _rotateLogFile() async {
    if (_currentLogFile != null && _currentFileSize > 0) {
      // Close current file (compression would happen here if enabled)
      _currentLogFile = null;
      _currentFileSize = 0;
    }
    await _createNewLogFile();
  }

  /// Get all log files sorted by date
  Future<List<File>> _getLogFiles() async {
    final files = await _storageDir
        .list()
        .where((entity) => entity is File && entity.path.contains('events_'))
        .cast<File>()
        .toList();

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Extract date from filename
  DateTime? _getFileDate(File file) {
    final filename = file.path.split('/').last;
    final timestampMatch = RegExp(r'events_(.+)\.jsonl').firstMatch(filename);
    if (timestampMatch != null) {
      try {
        return DateTime.parse(timestampMatch.group(1)!.replaceAll('-', ':'));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Read events from a file
  Stream<PersistedEvent> _readEventsFromFile(File file) async* {
    final lines =
        file.openRead().transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final data = json.decode(line);
        if (data['batch'] == true) {
          // Handle batch format
          final events = data['events'] as List;
          for (final eventData in events) {
            if (eventData is Map<String, dynamic>) {
              yield PersistedEvent.fromJson(eventData);
            } else if (eventData is Map) {
              yield PersistedEvent.fromJson(
                  Map<String, dynamic>.from(eventData));
            }
          }
        } else {
          // Handle single event format
          if (data is Map<String, dynamic>) {
            yield PersistedEvent.fromJson(data);
          } else if (data is Map) {
            yield PersistedEvent.fromJson(Map<String, dynamic>.from(data));
          }
        }
      } catch (e) {
        // Log error and continue
        continue;
      }
    }
  }

  /// Re-write files with compression
  Future<void> _rewriteWithCompression() async {
    // Implementation would compress existing files
    // This is a placeholder for compression logic
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _rotationTimer?.cancel();
  }
}

/// Represents a persisted event with metadata
class PersistedEvent {
  final ParsedEvent<dynamic> event;
  final DateTime timestamp;
  final String programId;

  PersistedEvent({
    required this.event,
    required this.timestamp,
    required this.programId,
  });

  Map<String, dynamic> toJson() => {
        'event': {
          'name': event.name,
          'data': event.data,
        },
        'timestamp': timestamp.toIso8601String(),
        'programId': programId,
      };

  factory PersistedEvent.fromJson(Map<String, dynamic> json) {
    // Defensive: ensure types for all fields
    final eventMap = json['event'] as Map? ?? {};
    final name = eventMap['name']?.toString() ?? '';
    final data = eventMap['data'];
    final signature = json['signature']?.toString() ?? '';
    final slotRaw = json['slot'];
    final slot =
        slotRaw is int ? slotRaw : int.tryParse(slotRaw?.toString() ?? '') ?? 0;
    final timestampRaw = json['timestamp'];
    final timestampStr = timestampRaw?.toString() ?? '';
    final programId = json['programId']?.toString() ?? '';

    final eventDef = IdlEvent(
      name: name,
      fields: [], // Empty fields for restoration
    );

    return PersistedEvent(
      event: ParsedEvent<dynamic>(
        name: name,
        data: data,
        context: EventContext(
          signature: signature,
          slot: slot,
        ),
        eventDef: eventDef,
      ),
      timestamp: DateTime.parse(timestampStr),
      programId: programId,
    );
  }
}

/// Statistics about persisted events
class EventPersistenceStats {
  final int totalEvents;
  final int totalSizeBytes;
  final int fileCount;
  final DateTime? oldestEvent;
  final DateTime? newestEvent;
  final bool compressionEnabled;

  EventPersistenceStats({
    required this.totalEvents,
    required this.totalSizeBytes,
    required this.fileCount,
    this.oldestEvent,
    this.newestEvent,
    required this.compressionEnabled,
  });

  double get averageEventSize =>
      totalEvents > 0 ? totalSizeBytes / totalEvents : 0;

  Duration? get timeSpan => oldestEvent != null && newestEvent != null
      ? newestEvent!.difference(oldestEvent!)
      : null;

  Map<String, dynamic> toJson() => {
        'totalEvents': totalEvents,
        'totalSizeBytes': totalSizeBytes,
        'fileCount': fileCount,
        'oldestEvent': oldestEvent?.toIso8601String(),
        'newestEvent': newestEvent?.toIso8601String(),
        'compressionEnabled': compressionEnabled,
        'averageEventSize': averageEventSize,
        'timeSpanMinutes': timeSpan?.inMinutes,
      };
}

/// Configuration for event persistence
class EventPersistenceConfig {
  final String storageDirectory;
  final bool enableCompression;
  final int maxFileSize;
  final Duration rotationInterval;
  final Duration? retentionPeriod;
  final bool enableBatchPersistence;
  final int batchSize;
  final Duration batchTimeout;

  const EventPersistenceConfig({
    required this.storageDirectory,
    this.enableCompression = true,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.rotationInterval = const Duration(hours: 24),
    this.retentionPeriod,
    this.enableBatchPersistence = true,
    this.batchSize = 100,
    this.batchTimeout = const Duration(seconds: 30),
  });

  /// Development preset with small files and short rotation
  factory EventPersistenceConfig.development() => EventPersistenceConfig(
        storageDirectory: './logs/events',
        enableCompression: false,
        maxFileSize: 1024 * 1024, // 1MB
        rotationInterval: const Duration(hours: 1),
        retentionPeriod: const Duration(days: 7),
        batchSize: 10,
        batchTimeout: const Duration(seconds: 5),
      );

  /// Production preset with larger files and compression
  factory EventPersistenceConfig.production() => EventPersistenceConfig(
        storageDirectory: '/var/log/anchor-events',
        enableCompression: true,
        maxFileSize: 50 * 1024 * 1024, // 50MB
        rotationInterval: const Duration(hours: 12),
        retentionPeriod: const Duration(days: 30),
        batchSize: 500,
        batchTimeout: const Duration(minutes: 2),
      );
}
