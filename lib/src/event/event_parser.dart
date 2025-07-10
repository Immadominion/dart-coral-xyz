/// Event parser implementation for parsing program events from transaction logs
///
/// This module provides the EventParser class which handles parsing transaction
/// logs to extract and decode program events. It tracks program execution context
/// across Cross-Program Invocation (CPI) boundaries to ensure events are correctly
/// attributed to their originating programs.

import '../types/public_key.dart';
import '../coder/main_coder.dart';
import 'types.dart';
import '../idl/idl.dart';

/// Parser for extracting events from transaction logs
///
/// The EventParser handles the complex task of parsing transaction logs
/// to extract program events. It maintains an execution context stack
/// to track which program is currently executing, enabling proper event
/// attribution across CPI boundaries.
class EventParser {
  /// The program ID this parser is configured for
  final PublicKey programId;

  /// The coder used for decoding events
  final BorshCoder coder;

  /// Regular expression for matching program invoke logs
  static final RegExp _invokeRegex =
      RegExp(r'^Program ([1-9A-HJ-NP-Za-km-z]+) invoke \[(\d+)\]$');

  /// Regular expression for matching program success logs
  static final RegExp _successRegex =
      RegExp(r'^Program ([1-9A-HJ-NP-Za-km-z]+) success$');

  /// Root depth for program execution stack
  static const String _rootDepth = '1';

  /// Program log prefix
  static const String _programLogPrefix = 'Program log: ';

  /// Program data prefix
  static const String _programDataPrefix = 'Program data: ';

  const EventParser({
    required this.programId,
    required this.coder,
  });

  /// Parse events from transaction logs
  ///
  /// [logs] - The transaction log messages
  /// [errorOnDecodeFailure] - Whether to throw on decode failures
  /// [context] - Additional context for the events
  ///
  /// Returns an iterable of parsed events
  Iterable<ParsedEvent<dynamic>> parseLogs(
    List<String> logs, {
    bool errorOnDecodeFailure = false,
    EventContext? context,
  }) sync* {
    if (logs.isEmpty) return;

    final scanner = _LogScanner(logs);
    final execution = _ExecutionContext();

    // Get the first log and establish root execution context
    final firstLog = scanner.next();
    if (firstLog == null) return;

    final firstMatch = _invokeRegex.firstMatch(firstLog);
    if (firstMatch == null || firstMatch.group(2) != _rootDepth) {
      throw EventParseException('Unexpected first log line: $firstLog');
    }

    execution.push(firstMatch.group(1)!);

    // Process remaining logs
    while (scanner.peek() != null) {
      final log = scanner.next();
      if (log == null) break;

      final result = _handleLog(execution, log, errorOnDecodeFailure);
      final event = result.event;
      final newProgram = result.newProgram;
      final didPop = result.didPop;

      // Yield event with context if found
      if (event != null) {
        final eventContext = context ??
            EventContext(
              slot: 0, // Will be filled by caller
              signature: '', // Will be filled by caller
            );

        yield ParsedEvent<dynamic>(
          name: event.name as String,
          data: event.data,
          context: eventContext,
          eventDef: event.eventDef as IdlEvent,
        );
      }

      // Update execution context
      if (newProgram != null) {
        execution.push(newProgram);
      }

      if (didPop) {
        execution.pop();

        // Check if next log starts a new root invocation
        final nextLog = scanner.peek();
        if (nextLog != null && nextLog.endsWith('invoke [1]')) {
          final match = _invokeRegex.firstMatch(nextLog);
          if (match != null) {
            execution.push(match.group(1)!);
          }
        }
      }
    }
  }

  /// Handle a single log line
  _LogHandleResult _handleLog(
    _ExecutionContext execution,
    String log,
    bool errorOnDecodeFailure,
  ) {
    // Check if we're executing our target program
    if (execution.stack.isNotEmpty &&
        execution.currentProgram() == programId.toBase58()) {
      return _handleProgramLog(log, errorOnDecodeFailure);
    } else {
      final systemResult = _handleSystemLog(log);
      return _LogHandleResult(
        event: null,
        newProgram: systemResult.newProgram,
        didPop: systemResult.didPop,
      );
    }
  }

  /// Handle logs from our target program
  _LogHandleResult _handleProgramLog(String log, bool errorOnDecodeFailure) {
    // Check if this is a program log or program data
    if (log.startsWith(_programLogPrefix) ||
        log.startsWith(_programDataPrefix)) {
      final logStr = log.startsWith(_programLogPrefix)
          ? log.substring(_programLogPrefix.length)
          : log.substring(_programDataPrefix.length);

      try {
        final event = coder.events.decode(logStr);

        if (errorOnDecodeFailure && event == null) {
          throw EventParseException('Unable to decode event: $logStr');
        }

        return _LogHandleResult(
          event: event,
          newProgram: null,
          didPop: false,
        );
      } catch (e) {
        if (errorOnDecodeFailure) {
          throw EventParseException('Failed to decode event: $logStr', e);
        }

        return _LogHandleResult(
          event: null,
          newProgram: null,
          didPop: false,
        );
      }
    } else {
      // System log while our program is executing
      final systemResult = _handleSystemLog(log);
      return _LogHandleResult(
        event: null,
        newProgram: systemResult.newProgram,
        didPop: systemResult.didPop,
      );
    }
  }

  /// Handle system logs (when not executing our target program)
  _SystemLogResult _handleSystemLog(String log) {
    // Check if this is a CPI invoke (but not depth 1)
    if (log.contains('invoke') && !log.endsWith('[1]')) {
      return _SystemLogResult(
        newProgram: 'cpi',
        didPop: false,
      );
    }

    // Check if this is a program success (indicating program completion)
    final successMatch = _successRegex.firstMatch(log);
    if (successMatch != null) {
      return _SystemLogResult(
        newProgram: null,
        didPop: true,
      );
    }

    return _SystemLogResult(
      newProgram: null,
      didPop: false,
    );
  }
}

/// Execution context stack for tracking program execution
class _ExecutionContext {
  final List<String> stack = [];

  /// Get the currently executing program
  String currentProgram() {
    if (stack.isEmpty) {
      throw EventParseException(
          'Expected the execution stack to have elements');
    }
    return stack.last;
  }

  /// Push a new program onto the execution stack
  void push(String program) {
    stack.add(program);
  }

  /// Pop the current program from the execution stack
  void pop() {
    if (stack.isEmpty) {
      throw EventParseException(
          'Expected the execution stack to have elements');
    }
    stack.removeLast();
  }
}

/// Scanner for processing log messages
class _LogScanner {
  List<String> _logs;

  _LogScanner(List<String> logs)
      : _logs = logs.where((log) => log.startsWith('Program ')).toList();

  /// Get the next log message
  String? next() {
    if (_logs.isEmpty) return null;
    return _logs.removeAt(0);
  }

  /// Peek at the next log message without consuming it
  String? peek() {
    return _logs.isEmpty ? null : _logs.first;
  }
}

/// Result of handling a log message
class _LogHandleResult {
  final dynamic event;
  final String? newProgram;
  final bool didPop;

  const _LogHandleResult({
    required this.event,
    required this.newProgram,
    required this.didPop,
  });
}

/// Result of handling a system log
class _SystemLogResult {
  final String? newProgram;
  final bool didPop;

  const _SystemLogResult({
    required this.newProgram,
    required this.didPop,
  });
}
