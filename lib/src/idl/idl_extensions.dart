/// Additional IDL type definitions for complete TypeScript SDK parity
/// Fills gaps in existing IDL type system

library;

/// IDL type argument definition - used in instruction returns
/// Matches TypeScript SDK IdlTypeArg
class IdlTypeArg {
  final String name;
  final dynamic type;

  const IdlTypeArg({
    required this.name,
    required this.type,
  });

  /// Create from JSON representation
  factory IdlTypeArg.fromJson(Map<String, dynamic> json) {
    return IdlTypeArg(
      name: json['name'] as String,
      type: json['type'],
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
      };

  @override
  String toString() => 'IdlTypeArg(name: $name, type: $type)';
}

/// Enhanced IDL instruction with additional type safety
/// Extends base IDL instruction functionality
mixin IdlInstructionExtensions {
  /// Documentation strings for the instruction
  List<String>? get docs => null;

  /// Return type specification (string format)
  String? get returns => null;
}
