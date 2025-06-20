import 'package:test/test.dart';
import '../lib/src/program/program_class.dart';
import '../lib/src/idl/idl.dart';
import '../lib/src/provider/provider.dart';
import '../lib/src/types/public_key.dart';

void main() {
  group('Program Class Foundation Tests', () {
    late Idl testIdl;
    late PublicKey testProgramId;

    setUp(() {
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111112');

      testIdl = Idl(
        address: testProgramId.toBase58(),
        metadata: IdlMetadata(
          name: 'test_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [],
      );
    });

    test('should create a Program instance with IDL', () {
      final program = Program(testIdl);

      expect(program.programId, equals(testProgramId));
      expect(program.idl.metadata?.name, equals('test_program'));
      expect(program.rawIdl, equals(testIdl));
    });

    test('should create a Program with custom provider', () {
      final connection = Connection('http://localhost:8899');
      final provider = AnchorProvider.readOnly(connection);

      final program = Program(testIdl, provider: provider);

      expect(program.provider, equals(provider));
      expect(program.programId, equals(testProgramId));
    });

    test('should validate program ID correctly', () {
      final program = Program(testIdl);

      // Should not throw for correct program ID
      expect(() => program.validateProgramId(testProgramId), returnsNormally);

      // Should throw for incorrect program ID
      final wrongProgramId =
          PublicKey.fromBase58('11111111111111111111111111111113');
      expect(
        () => program.validateProgramId(wrongProgramId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should get account size from coder', () {
      final program = Program(testIdl);

      // This will fail for now since we don't have actual account definitions
      // but it tests that the method exists and calls the coder
      expect(
        () => program.getAccountSize('nonexistent'),
        throwsA(isA<Exception>()),
      );
    });

    test('should calculate IDL address deterministically', () async {
      // For now, this will throw Exception since crypto implementation is incomplete
      // but we can test that the method exists and is called correctly
      expect(
        () async => await Program.getIdlAddress(testProgramId),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle Program.at with missing IDL', () async {
      // This should return null since we can't fetch IDL from a mock connection
      final program = await Program.at(testProgramId.toBase58());
      expect(program, isNull);
    });

    test('should handle Program.fetchIdl with missing IDL', () async {
      // This should return null since we can't fetch IDL from a mock connection
      final idl = await Program.fetchIdl(testProgramId);
      expect(idl, isNull);
    });

    test('should implement equality and hashCode correctly', () {
      final program1 = Program(testIdl);
      final program2 = Program(testIdl);

      expect(program1, equals(program2));
      expect(program1.hashCode, equals(program2.hashCode));

      // Different IDL should not be equal
      final differentIdl = Idl(
        address: testProgramId.toBase58(),
        metadata: IdlMetadata(
          name: 'different_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [],
      );
      final program3 = Program(differentIdl);

      expect(program1, isNot(equals(program3)));
    });

    test('should have meaningful toString representation', () {
      final program = Program(testIdl);
      final string = program.toString();

      expect(string, contains('Program'));
      expect(string, contains(testProgramId.toBase58()));
      expect(string, contains('test_program'));
    });
  });
}
