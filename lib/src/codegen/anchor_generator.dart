/// Core Anchor code generator
///
/// This module implements the main code generation logic for Anchor programs,
/// generating typed interfaces, method builders, account classes, and error classes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:path/path.dart' as path;

import '../idl/idl.dart';
import 'annotations.dart';
import 'generators/program_generator.dart';
import 'generators/account_generator.dart';
import 'generators/instruction_generator.dart';
import 'generators/error_generator.dart';
import 'generators/type_generator.dart';

/// Main generator for Anchor program code
class AnchorGenerator extends GeneratorForAnnotation<AnchorProgram> {
  /// Creates an AnchorGenerator with the given build options
  AnchorGenerator(this.options);

  /// Build options from build.yaml
  final BuilderOptions options;

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // Get IDL path from annotation
    final idlPath = annotation.read('idlPath').stringValue;
    final programId = annotation.read('programId').literalValue as String?;

    // Load and parse IDL
    final idl = await _loadIdl(idlPath, buildStep);

    // Generate code sections
    final buffer = StringBuffer();

    // Generate header
    _generateHeader(buffer, idl, programId);

    // Generate program interface
    final programGenerator = ProgramGenerator(idl, options);
    buffer.writeln(programGenerator.generate());

    // Generate account classes
    if (idl.accounts?.isNotEmpty == true) {
      final accountGenerator = AccountGenerator(idl, options);
      buffer.writeln(accountGenerator.generate());
    }

    // Generate instruction classes
    if (idl.instructions.isNotEmpty) {
      final instructionGenerator = InstructionGenerator(idl, options);
      buffer.writeln(instructionGenerator.generate());
    }

    // Generate error classes
    if (idl.errors?.isNotEmpty == true) {
      final errorGenerator = ErrorGenerator(idl, options);
      buffer.writeln(errorGenerator.generate());
    }

    // Generate type definitions
    if (idl.types?.isNotEmpty == true) {
      final typeGenerator = TypeGenerator(idl, options);
      buffer.writeln(typeGenerator.generate());
    }

    return buffer.toString();
  }

  /// Load IDL from file
  Future<Idl> _loadIdl(String idlPath, BuildStep buildStep) async {
    try {
      // First, try to read the IDL path directly as specified in annotation
      var assetId = AssetId(buildStep.inputId.package, idlPath);
      if (await buildStep.canRead(assetId)) {
        final contents = await buildStep.readAsString(assetId);
        final json = jsonDecode(contents) as Map<String, dynamic>;
        return Idl.fromJson(json);
      }

      // If not found, try with configured IDL path
      final configuredPath =
          options.config['idl_path'] as String? ?? 'target/idl';
      final fullPath = path.join(configuredPath, path.basename(idlPath));
      assetId = AssetId(buildStep.inputId.package, fullPath);
      if (await buildStep.canRead(assetId)) {
        final contents = await buildStep.readAsString(assetId);
        final json = jsonDecode(contents) as Map<String, dynamic>;
        return Idl.fromJson(json);
      }

      // Fallback to filesystem read
      final file = File(idlPath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        return Idl.fromJson(json);
      }

      throw BuildError('IDL file not found: $idlPath (also tried $fullPath)');
    } catch (e) {
      throw BuildError('Failed to load IDL from $idlPath: $e');
    }
  }

  /// Generate file header with imports and metadata
  void _generateHeader(StringBuffer buffer, Idl idl, String? programId) {
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from IDL: ${idl.name ?? 'unknown'}');
    if (idl.version != null) {
      buffer.writeln('// Version: ${idl.version}');
    }
    buffer.writeln('// Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // Add part of directive (commented out for now since it may not be needed)
    // buffer.writeln('part of \'${element.source.uri.pathSegments.last}\';');
    // buffer.writeln();

    // Add imports
    buffer.writeln('import \'dart:typed_data\';');
    buffer
        .writeln('import \'package:coral_xyz_anchor/coral_xyz_anchor.dart\';');
    buffer.writeln('import \'package:solana/solana.dart\';');
    buffer.writeln('import \'package:borsh/borsh.dart\';');
    buffer.writeln();

    // Add program ID constant if provided
    if (programId != null) {
      buffer.writeln('/// Program ID for ${idl.name ?? 'program'}');
      buffer.writeln('const String kProgramId = \'$programId\';');
      buffer.writeln();
    } else if (idl.address != null) {
      buffer.writeln('/// Program ID for ${idl.name ?? 'program'}');
      buffer.writeln('const String kProgramId = \'${idl.address}\';');
      buffer.writeln();
    }
  }
}

/// Error thrown during code generation
class BuildError implements Exception {
  /// Creates a BuildError with the given message
  const BuildError(this.message);

  /// Error message
  final String message;

  @override
  String toString() => 'BuildError: $message';
}
