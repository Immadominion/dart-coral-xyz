/// Event listening and management system for Anchor programs
///
/// Provides event listening, parsing, and subscription management
/// matching the TypeScript Anchor event system.
library;

export 'event_authority.dart';
export 'event_manager.dart';
export 'event_parser.dart';
export 'types.dart'
    hide EventCallback; // EventCallback also defined in event_manager.dart
