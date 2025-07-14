/// Event listening and management system for Anchor programs
///
/// This module provides comprehensive event system functionality including
/// event listening, parsing, filtering, and subscription management.
/// It's designed to mirror the TypeScript Anchor event system while
/// leveraging Dart's strengths.

library;

export 'event_aggregation.dart';
export 'event_debugging.dart';
export 'event_filter.dart';
export 'event_listener.dart';
export 'event_manager.dart';
export 'event_parser.dart';
export 'event_persistence.dart';
export 'event_replay.dart';
export 'event_subscription.dart';
export 'types.dart'
    hide EventCallback, LogsNotification; // Hide duplicates from types.dart
