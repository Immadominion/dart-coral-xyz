/// Build configuration for coral_xyz_anchor package
///
/// This file exports the necessary build configurations for the
/// anchor code generation system.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'anchor_generator.dart';

/// Build configuration for coral_xyz_anchor
Builder anchorBuilder(BuilderOptions options) =>
    LibraryBuilder(AnchorGenerator(options),
        generatedExtension: '.anchor.dart');

/// Build configuration for coral_xyz_anchor part builder
Builder anchorPartBuilder(BuilderOptions options) =>
    PartBuilder([AnchorGenerator(options)], '.anchor.dart');
