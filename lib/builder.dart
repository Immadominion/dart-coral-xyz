/// Build-time code generation for Anchor programs
///
/// This module provides build_runner integration for generating typed program
/// interfaces, method signatures, account classes, and error classes from IDL files.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/codegen/anchor_generator.dart';

/// Builder for Anchor code generation
Builder anchorBuilder(BuilderOptions options) =>
    LibraryBuilder(AnchorGenerator(options),
        generatedExtension: '.anchor.dart');

/// Partitioned builder for more efficient incremental builds
Builder anchorPartBuilder(BuilderOptions options) =>
    PartBuilder([AnchorGenerator(options)], '.anchor.dart');
