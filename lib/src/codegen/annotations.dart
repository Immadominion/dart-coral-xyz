/// Annotation for marking classes that should generate Anchor program code
///
/// This annotation is used to mark classes that represent Anchor programs
/// and should have code generated for them from IDL files.
library;

/// Annotation for Anchor program code generation
class AnchorProgram {
  /// Creates an AnchorProgram annotation
  const AnchorProgram(this.idlPath, {this.programId});

  /// Path to the IDL file (relative to project root)
  final String idlPath;

  /// Optional program ID (can be read from IDL if not provided)
  final String? programId;
}

/// Annotation for custom IDL type definitions
class IdlTypeAnnotation {
  /// Creates an IdlTypeAnnotation annotation
  const IdlTypeAnnotation(this.name);

  /// Name of the type in the IDL
  final String name;
}

/// Annotation for custom account definitions
class IdlAccountAnnotation {
  /// Creates an IdlAccountAnnotation annotation
  const IdlAccountAnnotation(this.name);

  /// Name of the account in the IDL
  final String name;
}

/// Annotation for custom instruction definitions
class IdlInstructionAnnotation {
  /// Creates an IdlInstructionAnnotation annotation
  const IdlInstructionAnnotation(this.name);

  /// Name of the instruction in the IDL
  final String name;
}

/// Annotation for custom error definitions
class IdlErrorAnnotation {
  /// Creates an IdlErrorAnnotation annotation
  const IdlErrorAnnotation(this.name);

  /// Name of the error in the IDL
  final String name;
}
