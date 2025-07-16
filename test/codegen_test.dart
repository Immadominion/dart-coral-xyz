/// Test file for code generation
///
/// This file demonstrates the use of the AnchorProgram annotation
/// to generate typed program interfaces.
library;

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

@AnchorProgram('test_program.json')
class TestProgram extends Program {
  TestProgram(super.idl, {super.provider, super.coder});
}
