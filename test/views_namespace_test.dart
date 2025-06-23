import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('ViewsNamespace', () {
    late ViewsNamespace viewsNamespace;
    late Idl idl;
    late PublicKey programId;
    late SimulateNamespace simulateNamespace;
    late BorshCoder coder;

    setUp(() {
      // Create a test IDL with view-eligible instructions
      idl = Idl(
        instructions: [
          // View-eligible instruction (read-only with return value)
          IdlInstruction(
            name: 'getPrice',
            args: [
              IdlField(name: 'market', type: idlTypePubkey()),
            ],
            accounts: [
              IdlInstructionAccount(
                name: 'marketAccount',
                writable: false, // Read-only
                signer: false,
              ),
            ],
            returns: 'u64', // Has return value
          ),
          // Non-view instruction (writable account)
          IdlInstruction(
            name: 'updatePrice',
            args: [
              IdlField(name: 'market', type: idlTypePubkey()),
              IdlField(name: 'newPrice', type: idlTypeU64()),
            ],
            accounts: [
              IdlInstructionAccount(
                name: 'marketAccount',
                writable: true, // Writable - not eligible for view
                signer: false,
              ),
            ],
            returns: null, // No return value
          ),
          // Non-view instruction (no return value)
          IdlInstruction(
            name: 'initialize',
            args: [
              IdlField(name: 'authority', type: idlTypePubkey()),
            ],
            accounts: [
              IdlInstructionAccount(
                name: 'authority',
                writable: false, // Read-only
                signer: true,
              ),
            ],
            returns: null, // No return value - not eligible for view
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'u64',
            type: IdlTypeDefType(kind: 'struct', fields: []),
          ),
        ],
      );

      programId = PublicKey.fromBase58('11111111111111111111111111111112');
      coder = BorshCoder(idl);

      // Mock simulate namespace for testing
      simulateNamespace = SimulateNamespace.build(
        idl: idl,
        transactionNamespace: TransactionNamespace.build(
          idl: idl,
          instructionNamespace: InstructionNamespace.build(
            idl: idl,
            coder: coder,
            programId: programId,
            provider: AnchorProvider.defaultProvider(),
          ),
        ),
        provider: AnchorProvider.defaultProvider(),
        coder: coder,
        programId: programId,
      );

      viewsNamespace = ViewsNamespace.build(
        idl: idl,
        programId: programId,
        simulateNamespace: simulateNamespace,
        coder: coder,
      );
    });

    test('builds views namespace from IDL', () {
      expect(viewsNamespace, isNotNull);
      expect(viewsNamespace.names, isNotEmpty);
    });

    test('identifies view-eligible instructions correctly', () {
      // Should only include getPrice (read-only with return value)
      expect(viewsNamespace.contains('getPrice'), isTrue);
      expect(
          viewsNamespace.contains('updatePrice'), isFalse); // Writable account
      expect(viewsNamespace.contains('initialize'), isFalse); // No return value
    });

    test('creates view functions for eligible instructions', () {
      final getPriceView = viewsNamespace['getPrice'];
      expect(getPriceView, isNotNull);
      expect(getPriceView!.name, equals('getPrice'));
      expect(getPriceView.hasReturnType, isTrue);
      expect(getPriceView.returnType, equals('u64'));
    });

    test('returns null for non-existent view functions', () {
      final nonExistentView = viewsNamespace['nonExistent'];
      expect(nonExistentView, isNull);
    });

    test('provides correct view function count', () {
      expect(viewsNamespace.length, equals(1)); // Only getPrice is eligible
    });

    test('lists all view function names', () {
      final names = viewsNamespace.names.toList();
      expect(names, hasLength(1));
      expect(names, contains('getPrice'));
    });

    test('view function has correct properties', () {
      final getPriceView = viewsNamespace['getPrice']!;

      expect(getPriceView.name, equals('getPrice'));
      expect(getPriceView.returnType, equals('u64'));
      expect(getPriceView.hasReturnType, isTrue);
    });

    test('toString provides meaningful description', () {
      final description = viewsNamespace.toString();
      expect(description, contains('ViewsNamespace'));
      expect(description, contains('getPrice'));
    });

    group('ViewFunction', () {
      late ViewFunction viewFunction;

      setUp(() {
        viewFunction = viewsNamespace['getPrice']!;
      });

      test('has correct instruction reference', () {
        expect(viewFunction.name, equals('getPrice'));
        expect(viewFunction.returnType, equals('u64'));
        expect(viewFunction.hasReturnType, isTrue);
      });

      test('toString provides meaningful description', () {
        final description = viewFunction.toString();
        expect(description, contains('ViewFunction'));
        expect(description, contains('getPrice'));
        expect(description, contains('u64'));
      });
    });

    group('View Eligibility Tests', () {
      test('instruction with writable account is not view-eligible', () {
        final instruction = IdlInstruction(
          name: 'testWritable',
          args: [],
          accounts: [
            IdlInstructionAccount(
              name: 'account',
              writable: true,
              signer: false,
            ),
          ],
          returns: 'u64',
        );

        expect(ViewsNamespace.isViewEligible(instruction), isFalse);
      });

      test('instruction without return type is not view-eligible', () {
        final instruction = IdlInstruction(
          name: 'testNoReturn',
          args: [],
          accounts: [
            IdlInstructionAccount(
              name: 'account',
              writable: false,
              signer: false,
            ),
          ],
          returns: null,
        );

        expect(ViewsNamespace.isViewEligible(instruction), isFalse);
      });

      test(
          'instruction with read-only accounts and return type is view-eligible',
          () {
        final instruction = IdlInstruction(
          name: 'testReadOnly',
          args: [],
          accounts: [
            IdlInstructionAccount(
              name: 'account',
              writable: false,
              signer: false,
            ),
          ],
          returns: 'u64',
        );

        expect(ViewsNamespace.isViewEligible(instruction), isTrue);
      });

      test('instruction with nested accounts checks writability correctly', () {
        final instruction = IdlInstruction(
          name: 'testNested',
          args: [],
          accounts: [
            IdlInstructionAccounts(
              name: 'nestedAccounts',
              accounts: [
                IdlInstructionAccount(
                  name: 'readOnlyAccount',
                  writable: false,
                  signer: false,
                ),
                IdlInstructionAccount(
                  name: 'writableAccount',
                  writable:
                      true, // This makes the instruction not view-eligible
                  signer: false,
                ),
              ],
            ),
          ],
          returns: 'u64',
        );

        expect(ViewsNamespace.isViewEligible(instruction), isFalse);
      });
    });
  });
}
