import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  // Test that BorshAccountsCoder can be imported and used
  print('Testing BorshAccountsCoder import and basic usage...');

  try {
    final idl = const Idl(
      address: 'TestAddress',
      metadata: IdlMetadata(name: 'test', version: '1.0.0', spec: '0.1.0'),
      instructions: [],
      accounts: [
        IdlAccount(
          name: 'TestAccount',
          type: IdlTypeDefType(kind: 'struct', fields: [
            IdlField(name: 'value', type: IdlType(kind: 'u64')),
          ],),
        ),
      ],
    );

    final coder = BorshAccountsCoder<String>(idl);
    print('✅ BorshAccountsCoder created successfully');

    final discriminator = coder.accountDiscriminator('TestAccount');
    print('✅ Account discriminator calculated: ${discriminator.length} bytes');

    final size = coder.size('TestAccount');
    print('✅ Account size calculated: $size bytes');

    print('✅ All basic BorshAccountsCoder functionality verified!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
