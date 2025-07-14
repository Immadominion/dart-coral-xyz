import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

/// Mock MWA client for testing
class MockMWAClient implements MobileWalletAdapterClient {
  MockMWAClient(this.pubkey);
  final PublicKey pubkey;

  @override
  Future<List<Uint8List>> signTransactions(List<Uint8List> messages) async {
    // Return fake signatures (64 bytes each)
    return messages.map((m) => Uint8List(64)).toList();
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    // Return fake signature (64 bytes)
    return Uint8List(64);
  }

  @override
  Future<PublicKey> getPublicKey() async => pubkey;
}

void main() {
  group('MobileWalletAdapterWallet Integration', () {
    late PublicKey pubkey;
    late MobileWalletAdapterWallet mwaWallet;
    late MockMWAClient mwaClient;

    setUp(() async {
      pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      mwaClient = MockMWAClient(pubkey);
      mwaWallet = await MobileWalletAdapterWallet.create(mwaClient);
    });

    test('should expose publicKey', () {
      expect(mwaWallet.publicKey, equals(pubkey));
    });

    test('should sign a transaction', () async {
      final tx = Transaction(instructions: [
        TransactionInstruction(
          programId: pubkey,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ),
      ], recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',);
      final signed = await mwaWallet.signTransaction(tx);
      expect(signed.signatures.length, greaterThan(0));
      expect(signed.feePayer, isNull); // Not set by wallet
    });

    test('should sign multiple transactions', () async {
      final txs = [
        Transaction(
            instructions: [],
            recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',),
        Transaction(
            instructions: [],
            recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',),
      ];
      final signed = await mwaWallet.signAllTransactions(txs);
      expect(signed.length, equals(2));
      for (final tx in signed) {
        expect(tx.signatures.length, greaterThan(0));
      }
    });

    test('should sign a message', () async {
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await mwaWallet.signMessage(msg);
      expect(sig, isA<Uint8List>());
      expect(sig, equals(Uint8List(64)));
    });
  });

  group('AnchorProvider with MWA Wallet', () {
    late Connection connection;
    late MobileWalletAdapterWallet mwaWallet;
    late AnchorProvider provider;
    late MockMWAClient mwaClient;
    late PublicKey pubkey;

    setUp(() async {
      connection = Connection('http://localhost:8899');
      pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      mwaClient = MockMWAClient(pubkey);
      mwaWallet = await MobileWalletAdapterWallet.create(mwaClient);
      provider = AnchorProvider(connection, mwaWallet);
    });

    test('should use MWA wallet for provider', () {
      expect(provider.wallet, equals(mwaWallet));
      expect(provider.publicKey, equals(pubkey));
    });

    test('should send and confirm transaction (mock)', () async {
      final tx = Transaction(instructions: [
        TransactionInstruction(
          programId: pubkey,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ),
      ], recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',);
      final sig = await provider.sendAndConfirm(tx);
      expect(sig, isA<String>());
    });
  });
}
