import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';

import '../idl/idl.dart';
import '../types/public_key.dart';
import 'event_definition.dart';
import '../coder/event_coder.dart'; // Use canonical BorshEventCoder

/// Constants for log parsing matching TypeScript implementation
const String programLog = "Program log: ";
const String programData = "Program data: ";
const int programLogStartIndex = programLog.length;
const int programDataStartIndex = programData.length;

/// Event log parser for extracting events from transaction logs
/// Matches TypeScript's EventParser functionality with discriminator validation
class EventLogParser {
  /// Program ID for filtering events
  final PublicKey programId;

  /// Event definitions mapped by discriminator
  final Map<List<int>, EventDefinition> eventsByDiscriminator;

  /// Event definitions mapped by name
  final Map<String, EventDefinition> eventsByName;

  /// Parser configuration
  final EventLogParserConfig config;

  /// BorshEventCoder for IDL-based event decoding (preferred method)
  final BorshEventCoder? _eventCoder;

  /// Regular expression for parsing program invocation logs
  static final RegExp invokeRegex =
      RegExp(r'^Program ([1-9A-HJ-NP-Za-km-z]+) invoke \[(\d+)\]$');

  /// Root execution depth
  static const String rootDepth = "1";

  const EventLogParser({
    required this.programId,
    required this.eventsByDiscriminator,
    required this.eventsByName,
    required this.config,
    BorshEventCoder? eventCoder,
  }) : _eventCoder = eventCoder;

  /// Create EventLogParser from IDL (preferred method)
  /// Uses BorshEventCoder for proper TypeScript-style delegation
  factory EventLogParser.fromIdl(
    PublicKey programId,
    Idl idl, {
    EventLogParserConfig? config,
  }) {
    config ??= EventLogParserConfig.defaultConfig();

    // Create BorshEventCoder for IDL-based decoding
    final eventCoder = BorshEventCoder(idl);

    // Extract events from IDL to create EventDefinitions for fallback
    final events = <EventDefinition>[];
    if (idl.events != null) {
      // Create type map for custom types
      final customTypes = <String, IdlTypeDef>{};
      if (idl.types != null) {
        for (final typeDef in idl.types!) {
          customTypes[typeDef.name] = typeDef;
        }
      }

      for (final idlEvent in idl.events!) {
        // Create EventDefinition for backward compatibility
        final eventDef =
            EventDefinition.fromIdl(idlEvent, customTypes: customTypes);
        events.add(eventDef);
      }
    }

    final eventsByDiscriminator = <List<int>, EventDefinition>{};
    final eventsByName = <String, EventDefinition>{};

    for (final event in events) {
      if (event.discriminator != null) {
        eventsByDiscriminator[event.discriminator!] = event;
      }
      eventsByName[event.name] = event;
    }

    return EventLogParser(
      programId: programId,
      eventsByDiscriminator: eventsByDiscriminator,
      eventsByName: eventsByName,
      config: config,
      eventCoder: eventCoder,
    );
  }

  /// Create EventLogParser from event definitions (legacy method)
  /// Maintains backward compatibility but doesn't use BorshEventCoder
  factory EventLogParser.fromEvents(
    PublicKey programId,
    List<EventDefinition> events, {
    EventLogParserConfig? config,
  }) {
    config ??= EventLogParserConfig.defaultConfig();

    final eventsByDiscriminator = <List<int>, EventDefinition>{};
    final eventsByName = <String, EventDefinition>{};

    for (final event in events) {
      if (event.discriminator != null) {
        eventsByDiscriminator[event.discriminator!] = event;
      }
      eventsByName[event.name] = event;
    }

    return EventLogParser(
      programId: programId,
      eventsByDiscriminator: eventsByDiscriminator,
      eventsByName: eventsByName,
      config: config,
      eventCoder: null, // No IDL-based coder available
    );
  }

  /// Parse events from transaction logs
  /// Returns generator-like iterable of parsed events
  Iterable<ParsedEvent> parseLogs(
    List<String> logs, {
    bool errorOnDecodeFailure = false,
  }) sync* {
    final scanner = LogScanner(List.from(logs));
    final execution = ExecutionContext();

    final firstLog = scanner.next();
    if (firstLog == null) return;

    final firstMatch = invokeRegex.firstMatch(firstLog);
    if (firstMatch == null || firstMatch.group(2) != rootDepth) {
      if (config.strictParsing) {
        throw EventParsingException('Unexpected first log line: $firstLog');
      }
      return;
    }
    execution.push(firstMatch.group(1)!);

    while (scanner.peek() != null) {
      final log = scanner.next();
      if (log == null) break;

      final result = _handleLog(execution, log, errorOnDecodeFailure);
      final event = result.event;
      final newProgram = result.newProgram;
      final didPop = result.didPop;

      if (event != null) yield event;
      if (newProgram != null) execution.push(newProgram);

      if (didPop) {
        execution.pop();
        final nextLog = scanner.peek();
        if (nextLog != null && nextLog.endsWith("invoke [1]")) {
          final match = invokeRegex.firstMatch(nextLog);
          if (match != null) execution.push(match.group(1)!);
        }
      }
    }
  }

  /// Parse a single event from log data
  ParsedEvent? parseEvent(String logData, {bool validate = true}) {
    try {
      // PREFERRED: Use BorshEventCoder when available (TypeScript pattern)
      if (_eventCoder != null) {
        final decodedEvent = _eventCoder!.decode(logData);
        if (decodedEvent != null) {
          // Extract raw data and discriminator for context
          Uint8List? rawData;
          List<int>? discriminator;
          EventDefinition? definition;

          try {
            rawData = base64.decode(logData);
            definition = eventsByName[decodedEvent.name];
            if (definition?.discriminator != null) {
              discriminator = definition!.discriminator!;
            }
          } catch (e) {
            // Non-critical failure, continue with limited context
          }

          // Convert DecodedEvent to ParsedEvent
          return ParsedEvent.fromEvent(
            decodedEvent,
            validate: validate,
            definition: definition,
            rawData: rawData,
            discriminator: discriminator,
          );
        }
        // If BorshEventCoder couldn't decode, continue to fallback
      }

      // FALLBACK: Manual parsing for backward compatibility
      return _parseEventManually(logData, validate: validate);
    } catch (e) {
      if (config.strictParsing) {
        rethrow;
      }
      return null;
    }
  }

  /// Manual event parsing (legacy method)
  ParsedEvent? _parseEventManually(String logData, {bool validate = true}) {
    try {
      // Decode base64 data
      final Uint8List logBytes;
      try {
        logBytes = base64.decode(logData);
      } catch (e) {
        if (config.strictParsing) {
          throw EventParsingException('Invalid base64 log data: $logData');
        }
        return null;
      }

      // Try to match discriminator with known events
      for (final entry in eventsByDiscriminator.entries) {
        final discriminator = entry.key;
        final eventDef = entry.value;

        if (logBytes.length >= discriminator.length) {
          final logDiscriminator = logBytes.sublist(0, discriminator.length);

          if (_listsEqual(logDiscriminator, discriminator)) {
            // Extract event data
            final eventData = logBytes.sublist(discriminator.length);

            // Parse event data based on event definition
            final parsedData = _parseEventData(eventDef, eventData);

            // Validate if requested
            if (validate) {
              final validation = eventDef.validateEventData(parsedData);
              if (!validation.isValid && config.strictValidation) {
                throw EventParsingException(
                  'Event validation failed for ${eventDef.name}: ${validation.errors.join(', ')}',
                );
              }
            }

            return ParsedEvent(
              name: eventDef.name,
              data: parsedData,
              definition: eventDef,
              rawData: logBytes,
              discriminator: discriminator,
              isValid: validate
                  ? eventDef.validateEventData(parsedData).isValid
                  : true,
            );
          }
        }
      }

      // No matching discriminator found
      if (config.allowUnknownEvents) {
        return ParsedEvent(
          name: 'unknown',
          data: {'rawData': logData},
          definition: null,
          rawData: logBytes,
          discriminator:
              logBytes.length >= 8 ? logBytes.sublist(0, 8) : logBytes,
          isValid: false,
        );
      }

      return null;
    } catch (e) {
      if (config.strictParsing) {
        rethrow;
      }
      return null;
    }
  }

  /// Handle a single log line
  LogHandleResult _handleLog(
    ExecutionContext execution,
    String log,
    bool errorOnDecodeFailure,
  ) {
    // Check if executing program is this program
    if (execution.stack.isNotEmpty &&
        execution.program() == programId.toString()) {
      return _handleProgramLog(log, errorOnDecodeFailure);
    } else {
      final systemResult = _handleSystemLog(log);
      return LogHandleResult(
        event: null,
        newProgram: systemResult.newProgram,
        didPop: systemResult.didPop,
      );
    }
  }

  /// Handle logs from this program
  LogHandleResult _handleProgramLog(String log, bool errorOnDecodeFailure) {
    // Check for program log or program data
    if (log.startsWith(programLog) || log.startsWith(programData)) {
      final logStr = log.startsWith(programLog)
          ? log.substring(programLogStartIndex)
          : log.substring(programDataStartIndex);

      final event = parseEvent(logStr, validate: config.strictValidation);

      if (errorOnDecodeFailure && event == null) {
        throw EventParsingException('Unable to decode event: $logStr');
      }

      return LogHandleResult(
        event: event,
        newProgram: null,
        didPop: false,
      );
    } else {
      // System log
      final systemResult = _handleSystemLog(log);
      return LogHandleResult(
        event: null,
        newProgram: systemResult.newProgram,
        didPop: systemResult.didPop,
      );
    }
  }

  /// Handle system logs
  SystemLogResult _handleSystemLog(String log) {
    if (log.startsWith('Program ${programId.toString()} log:')) {
      return SystemLogResult(
        newProgram: programId.toString(),
        didPop: false,
      );
    } else if (log.contains("invoke") && !log.endsWith("[1]")) {
      return SystemLogResult(
        newProgram: "cpi",
        didPop: false,
      );
    } else {
      final successRegex = RegExp(r'^Program ([1-9A-HJ-NP-Za-km-z]+) success$');
      if (successRegex.hasMatch(log)) {
        return SystemLogResult(
          newProgram: null,
          didPop: true,
        );
      } else {
        return SystemLogResult(
          newProgram: null,
          didPop: false,
        );
      }
    }
  }

  /// Parse event data from bytes based on event definition
  Map<String, dynamic> _parseEventData(
    EventDefinition eventDef,
    Uint8List eventData,
  ) {
    // For now, implement basic parsing
    // In a real implementation, this would use Borsh deserialization
    // based on the event definition fields

    final result = <String, dynamic>{};
    int offset = 0;

    try {
      for (final field in eventDef.fields) {
        if (offset >= eventData.length) break;

        final value = parseFieldValue(field, eventData, offset);
        result[field.name] = value.value;
        offset += value.bytesConsumed;
      }
    } catch (e) {
      if (config.strictParsing) {
        throw EventParsingException('Failed to parse event data: $e');
      }
      // Return partial data on error
    }

    return result;
  }

  /// Parse a single field value from bytes
  /// Exposed for testing purposes
  @visibleForTesting
  FieldParseResult parseFieldValue(
    EventFieldDefinition field,
    Uint8List data,
    int offset,
  ) {
    final typeName = field.typeInfo.typeName;

    try {
      switch (typeName) {
        case 'bool':
          if (offset >= data.length) throw 'Insufficient data for bool';
          return FieldParseResult(
            value: data[offset] != 0,
            bytesConsumed: 1,
          );

        case 'u8':
        case 'i8':
          if (offset >= data.length) throw 'Insufficient data for $typeName';
          return FieldParseResult(
            value: data[offset],
            bytesConsumed: 1,
          );

        case 'u16':
        case 'i16':
          if (offset + 2 > data.length) throw 'Insufficient data for $typeName';
          final bytes = data.sublist(offset, offset + 2);
          final value = ByteData.sublistView(bytes).getUint16(0, Endian.little);
          return FieldParseResult(
            value: value,
            bytesConsumed: 2,
          );

        case 'u32':
        case 'i32':
          if (offset + 4 > data.length) throw 'Insufficient data for $typeName';
          final bytes = data.sublist(offset, offset + 4);
          final value = ByteData.sublistView(bytes).getUint32(0, Endian.little);
          return FieldParseResult(
            value: value,
            bytesConsumed: 4,
          );

        case 'u64':
        case 'i64':
          if (offset + 8 > data.length) throw 'Insufficient data for $typeName';
          final bytes = data.sublist(offset, offset + 8);
          final value = ByteData.sublistView(bytes).getUint64(0, Endian.little);
          return FieldParseResult(
            value: value,
            bytesConsumed: 8,
          );

        case 'string':
          if (offset + 4 > data.length)
            throw 'Insufficient data for string length';
          final lengthBytes = data.sublist(offset, offset + 4);
          final length =
              ByteData.sublistView(lengthBytes).getUint32(0, Endian.little);

          if (offset + 4 + length > data.length)
            throw 'Insufficient data for string content';
          final stringBytes = data.sublist(offset + 4, offset + 4 + length);
          final value = utf8.decode(stringBytes);

          return FieldParseResult(
            value: value,
            bytesConsumed: 4 + length,
          );

        case 'publicKey':
          if (offset + 32 > data.length)
            throw 'Insufficient data for publicKey';
          final keyBytes = data.sublist(offset, offset + 32);
          final value = PublicKey.fromBytes(keyBytes);
          return FieldParseResult(
            value: value,
            bytesConsumed: 32,
          );

        default:
          // For complex types, return raw bytes for now
          final estimatedSize = field.typeInfo.estimatedSize;
          final actualSize = (offset + estimatedSize <= data.length)
              ? estimatedSize
              : data.length - offset;

          return FieldParseResult(
            value: data.sublist(offset, offset + actualSize),
            bytesConsumed: actualSize,
          );
      }
    } catch (e) {
      if (config.strictParsing) {
        throw EventParsingException('Failed to parse field ${field.name}: $e');
      }

      // Return null value on error
      return FieldParseResult(
        value: null,
        bytesConsumed: 0,
      );
    }
  }

  /// Check if two lists are equal
  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Filter events by name
  Iterable<ParsedEvent> filterEventsByName(
    Iterable<ParsedEvent> events,
    Set<String> eventNames,
  ) {
    return events.where((event) => eventNames.contains(event.name));
  }

  /// Filter events by custom criteria
  Iterable<ParsedEvent> filterEvents(
    Iterable<ParsedEvent> events,
    bool Function(ParsedEvent) predicate,
  ) {
    return events.where(predicate);
  }
}

/// Configuration for event log parsing
class EventLogParserConfig {
  /// Whether to use strict parsing (throw errors on malformed data)
  final bool strictParsing;

  /// Whether to use strict validation (throw errors on validation failures)
  final bool strictValidation;

  /// Whether to allow unknown events to be parsed
  final bool allowUnknownEvents;

  /// Whether to recover from partial parsing errors
  final bool recoverFromErrors;

  const EventLogParserConfig({
    this.strictParsing = false,
    this.strictValidation = false,
    this.allowUnknownEvents = true,
    this.recoverFromErrors = true,
  });

  /// Default configuration
  factory EventLogParserConfig.defaultConfig() {
    return const EventLogParserConfig();
  }

  /// Strict configuration for production
  factory EventLogParserConfig.strict() {
    return const EventLogParserConfig(
      strictParsing: true,
      strictValidation: true,
      allowUnknownEvents: false,
      recoverFromErrors: false,
    );
  }

  /// Lenient configuration for development
  factory EventLogParserConfig.lenient() {
    return const EventLogParserConfig(
      strictParsing: false,
      strictValidation: false,
      allowUnknownEvents: true,
      recoverFromErrors: true,
    );
  }
}

/// Result of parsing a single event
class ParsedEvent {
  /// Event name
  final String name;

  /// Parsed event data
  final Map<String, dynamic> data;

  /// Event definition (null for unknown events)
  final EventDefinition? definition;

  /// Raw log data
  final Uint8List rawData;

  /// Event discriminator
  final List<int> discriminator;

  /// Whether the event is valid
  final bool isValid;

  const ParsedEvent({
    required this.name,
    required this.data,
    required this.definition,
    required this.rawData,
    required this.discriminator,
    required this.isValid,
  });

  /// Create ParsedEvent from Event (BorshEventCoder result)
  factory ParsedEvent.fromEvent(
    Event decodedEvent, {
    bool validate = true,
    EventDefinition? definition,
    Uint8List? rawData,
    List<int>? discriminator,
  }) {
    // Convert dynamic data to Map<String, dynamic>
    Map<String, dynamic> eventData;
    if (decodedEvent.data is Map<String, dynamic>) {
      eventData = decodedEvent.data as Map<String, dynamic>;
    } else {
      // Handle other data types by wrapping them
      eventData = {'data': decodedEvent.data};
    }

    return ParsedEvent(
      name: decodedEvent.name,
      data: eventData,
      definition: definition,
      rawData: rawData ?? Uint8List(0),
      discriminator: discriminator ?? [],
      isValid: validate, // Assume valid if decoded successfully
    );
  }

  @override
  String toString() => 'ParsedEvent(name: $name, isValid: $isValid)';
}

/// Result of handling a log line
class LogHandleResult {
  /// Parsed event (if any)
  final ParsedEvent? event;

  /// New program to push to execution stack
  final String? newProgram;

  /// Whether a program completed execution
  final bool didPop;

  const LogHandleResult({
    this.event,
    this.newProgram,
    required this.didPop,
  });
}

/// Result of handling a system log
class SystemLogResult {
  /// New program to push to execution stack
  final String? newProgram;

  /// Whether a program completed execution
  final bool didPop;

  const SystemLogResult({
    this.newProgram,
    required this.didPop,
  });
}

/// Result of parsing a field value
class FieldParseResult {
  /// Parsed value
  final dynamic value;

  /// Number of bytes consumed
  final int bytesConsumed;

  const FieldParseResult({
    required this.value,
    required this.bytesConsumed,
  });
}

/// Log scanner for iterating through log lines
class LogScanner {
  List<String> logs;

  LogScanner(this.logs) {
    // Filter out logs that don't start with "Program" to match TypeScript behavior
    logs = logs.where((log) => log.startsWith("Program ")).toList();
  }

  String? next() {
    if (logs.isEmpty) return null;
    final log = logs.first;
    logs = logs.sublist(1);
    return log;
  }

  String? peek() {
    return logs.isEmpty ? null : logs.first;
  }
}

/// Execution context for tracking program execution stack
class ExecutionContext {
  final List<String> stack = [];

  String program() {
    if (stack.isEmpty) {
      throw EventParsingException('Expected the stack to have elements');
    }
    return stack.last;
  }

  void push(String newProgram) {
    stack.add(newProgram);
  }

  void pop() {
    if (stack.isEmpty) {
      throw EventParsingException('Expected the stack to have elements');
    }
    stack.removeLast();
  }
}

/// Exception thrown during event parsing
class EventParsingException implements Exception {
  final String message;
  final String? eventName;
  final String? logData;

  const EventParsingException(
    this.message, {
    this.eventName,
    this.logData,
  });

  @override
  String toString() {
    return eventName != null
        ? 'EventParsingException ($eventName): $message'
        : 'EventParsingException: $message';
  }
}
