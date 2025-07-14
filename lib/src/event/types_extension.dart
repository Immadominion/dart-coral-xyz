/// Extended types for the event system
///
/// This file contains additional type definitions needed for the advanced
/// event system features in the Program class.
library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/event/types.dart';

/// Event processor interface for event pipelines
abstract class EventProcessor {
  Future<dynamic> process(dynamic event);
}

/// Simple filter processor implementation
class FilterProcessor implements EventProcessor {

  FilterProcessor(this._filterFn);
  final bool Function(dynamic) _filterFn;

  @override
  Future<dynamic> process(dynamic event) async {
    if (_filterFn(event)) {
      return event;
    }
    return null;
  }
}

/// Event pipeline for processing events
class EventPipeline {

  EventPipeline(this._processors) {
    final transformedStream = _inputController.stream;
    outputStream = transformedStream.asyncExpand((event) async* {
      var processedEvent = event;
      for (final processor in _processors) {
        processedEvent = await processor.process(processedEvent);
        if (processedEvent == null) break;
      }
      if (processedEvent != null) {
        yield processedEvent;
      }
    });
  }
  final List<EventProcessor> _processors;
  final StreamController<dynamic> _inputController =
      StreamController<dynamic>();
  late final Stream<dynamic> outputStream;

  void addEvent(dynamic event) {
    _inputController.add(event);
  }

  Future<void> close() async {
    await _inputController.close();
  }
}

/// Event connection state
class EventConnectionState {

  const EventConnectionState({
    required this.isConnected,
    this.lastConnectionTime,
    this.connectionError,
  });
  final bool isConnected;
  final DateTime? lastConnectionTime;
  final String? connectionError;
}

/// Event statistics
class EventStats {

  const EventStats({
    required this.totalEvents,
    required this.parseErrors,
    required this.lastEventSlot,
    this.lastEventTime,
  });
  final int totalEvents;
  final int parseErrors;
  final int lastEventSlot;
  final DateTime? lastEventTime;
}

/// Program event data structure
class ProgramEvent {

  const ProgramEvent({
    required this.eventName,
    required this.eventData,
    required this.context,
  });
  final String eventName;
  final dynamic eventData;
  final EventContext context;
}

/// Event persistence service
class EventPersistenceService {

  EventPersistenceService(this._programId, this._provider);
  final PublicKey _programId;
  final AnchorProvider _provider;
  bool _initialized = false;

  Future<void> initialize() async {
    // Implementation would set up storage and listeners for _programId
    _initialized = true;
  }

  Future<Map<String, dynamic>> getStats() async => {
      'enabled': _initialized,
      'events': 0,
      'storage': 'memory',
      'programId': _programId.toBase58(),
    };

  Future<List<ProgramEvent>> restoreEvents() async {
    // Implementation would retrieve events from storage using _provider and _programId
    final _ = _provider; // Use the provider
    return <ProgramEvent>[];
  }

  Future<void> dispose() async {
    // Implementation would clean up resources
    _initialized = false;
  }
}

/// Event debugging monitor
class EventDebugMonitor {

  EventDebugMonitor(this._programId);
  final PublicKey _programId;
  bool _initialized = false;

  Future<void> initialize() async {
    // Implementation would set up debugging tools for _programId
    _initialized = true;
  }

  Future<Map<String, dynamic>> getStats() async => {
      'enabled': _initialized,
      'events': 0,
      'monitors': <String>[],
      'programId': _programId.toBase58(),
    };

  Future<void> dispose() async {
    // Implementation would clean up resources
    _initialized = false;
  }
}

/// Event aggregation service
class EventAggregationService {

  EventAggregationService(this._programId, this._provider);
  final PublicKey _programId;
  final AnchorProvider _provider;
  bool _initialized = false;
  final List<EventPipeline> _pipelines = [];

  Future<void> initialize() async {
    // Implementation would set up aggregation system for _programId using _provider
    _initialized = true;
  }

  Future<EventPipeline> createPipeline(List<EventProcessor> processors) async {
    final pipeline = EventPipeline(processors);
    _pipelines.add(pipeline);
    return pipeline;
  }

  Future<List<dynamic>> getResults() async {
    // Implementation would return aggregated results
    // Using _initialized to check state
    if (!_initialized) return <dynamic>[];
    final _ = _provider; // Use provider
    final __ = _programId; // Use programId
    return <dynamic>[];
  }

  Future<void> dispose() async {
    // Implementation would clean up resources
    for (final pipeline in _pipelines) {
      await pipeline.close();
    }
    _pipelines.clear();
    _initialized = false;
  }
}

/// Note: EventManager extensions would need to be defined in the same file
/// as EventManager to access private fields. This is a placeholder for
/// demonstration purposes. In practice, these methods should be added
/// directly to the EventManager class.
///
/// Example of what the extension would look like if it were in the same file:
/// ```dart
/// extension EventManagerExtension on EventManager {
///   EventStats get stats => EventStats(
///         totalEvents: _totalEvents,
///         parseErrors: _parseErrors,
///         lastEventSlot: 0,
///         lastEventTime: DateTime.now(),
///       );
///
///   EventConnectionState get connectionState => EventConnectionState(
///         isConnected: _onLogsSubscriptionId != null,
///         lastConnectionTime: DateTime.now(),
///       );
///
///   Stream<EventConnectionState> get connectionStateStream =>
///       Stream.periodic(Duration(seconds: 5), (_) => connectionState);
/// }
/// ```
