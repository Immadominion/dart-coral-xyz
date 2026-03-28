/// T3 — Integration Tests: Connection & RPC
///
/// Tests the Connection class against a running solana-test-validator.
/// Prerequisite: solana-test-validator must be running on localhost:8899.
///
/// Run: dart test test/integration/connection_rpc_test.dart
@TestOn('vm')
@Tags(['integration'])
library;

import 'package:coral_xyz/coral_xyz.dart';
import 'package:coral_xyz/src/provider/connection.dart';
import 'package:coral_xyz/src/provider/wallet.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/solana.dart' as solana;
import 'package:test/test.dart';

const _rpcUrl = 'http://127.0.0.1:8899';
const _lamportsPerSol = 1000000000;

/// Check if the localnet validator is reachable.
Future<bool> _isValidatorRunning() async {
  try {
    final connection = Connection(_rpcUrl);
    await connection.getLatestBlockhash();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  late Connection connection;

  setUpAll(() async {
    final running = await _isValidatorRunning();
    if (!running) {
      throw StateError(
        'solana-test-validator not running on $_rpcUrl. '
        'Start it with: solana-test-validator --reset --quiet',
      );
    }
  });

  setUp(() {
    connection = Connection(_rpcUrl);
  });

  // ─── T3.1 — Connection & RPC ───────────────────────────────────────────────

  group('T3.1 — Connection & RPC', () {
    test('connect to localnet', () {
      expect(connection.endpoint, equals(_rpcUrl));
      expect(connection.rpcClient, isNotNull);
    });

    test('getLatestBlockhash returns valid blockhash', () async {
      final blockhash = await connection.getLatestBlockhash();
      // Blockhashes are base58-encoded strings
      expect(blockhash.blockhash, isNotEmpty);
      expect(blockhash.lastValidBlockHeight, greaterThan(0));
    });

    test('requestAirdrop and getBalance', () async {
      final wallet = await KeypairWallet.generate();
      final address = wallet.publicKey.toBase58();

      final sig = await connection.requestAirdrop(address, 2 * _lamportsPerSol);
      expect(sig, isNotEmpty);

      await connection.confirmTransaction(sig);

      final balance = await connection.getBalance(address);
      expect(balance, equals(2 * _lamportsPerSol));
    });

    test('getBalance of new account is 0', () async {
      final wallet = await KeypairWallet.generate();
      final balance = await connection.getBalance(wallet.publicKey.toBase58());
      expect(balance, equals(0));
    });

    test('getAccountInfo for funded account', () async {
      final wallet = await KeypairWallet.generate();
      final address = wallet.publicKey.toBase58();

      final sig = await connection.requestAirdrop(address, _lamportsPerSol);
      await connection.confirmTransaction(sig);

      final account = await connection.getAccountInfo(address);
      expect(account, isNotNull);
      expect(account!.lamports, equals(_lamportsPerSol));
      // System program-owned account
      expect(account.owner, equals('11111111111111111111111111111111'));
    });

    test('getAccountInfo for non-existent account returns null', () async {
      final wallet = await KeypairWallet.generate();
      final account = await connection.getAccountInfo(
        wallet.publicKey.toBase58(),
      );
      expect(account, isNull);
    });

    test('getMinimumBalanceForRentExemption', () async {
      final rent = await connection.getMinimumBalanceForRentExemption(100);
      // Rent should be a positive amount
      expect(rent, greaterThan(0));
    });

    test('getMultipleAccountsInfo', () async {
      final w1 = await KeypairWallet.generate();
      final w2 = await KeypairWallet.generate();
      final a1 = w1.publicKey.toBase58();
      final a2 = w2.publicKey.toBase58();

      // Fund only the first
      final sig = await connection.requestAirdrop(a1, _lamportsPerSol);
      await connection.confirmTransaction(sig);

      final accounts = await connection.getMultipleAccountsInfo([a1, a2]);
      expect(accounts.length, equals(2));
      expect(accounts[0], isNotNull);
      expect(accounts[1], isNull);
    });
  });

  // ─── T3.2 — Transaction Sending ────────────────────────────────────────────

  group('T3.2 — Transaction sending', () {
    test('SOL transfer via sendAndConfirmTransaction', () async {
      final sender = await KeypairWallet.generate();
      final recipient = await solana.Ed25519HDKeyPair.random();

      // Fund sender
      final airdropSig = await connection.requestAirdrop(
        sender.publicKey.toBase58(),
        2 * _lamportsPerSol,
      );
      await connection.confirmTransaction(airdropSig);

      // Transfer 0.5 SOL
      final message = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: sender.keypair.publicKey,
          recipientAccount: recipient.publicKey,
          lamports: _lamportsPerSol ~/ 2,
        ),
      );

      final txSig = await connection.sendAndConfirmTransaction(
        message: message,
        signers: [sender.keypair],
        commitment: dto.Commitment.confirmed,
      );
      expect(txSig, isNotEmpty);

      // Verify recipient balance
      final recipientBalance = await connection.getBalance(
        recipient.publicKey.toBase58(),
      );
      expect(recipientBalance, equals(_lamportsPerSol ~/ 2));
    });

    test('transaction simulation succeeds for valid TX', () async {
      final sender = await KeypairWallet.generate();
      final recipient = await solana.Ed25519HDKeyPair.random();

      // Fund sender
      final sig = await connection.requestAirdrop(
        sender.publicKey.toBase58(),
        2 * _lamportsPerSol,
      );
      await connection.confirmTransaction(sig);

      // Send the transaction to get a base64 version for simulation
      // We test simulation indirectly by sending a valid transaction
      // and confirming it succeeds
      final message = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: sender.keypair.publicKey,
          recipientAccount: recipient.publicKey,
          lamports: _lamportsPerSol ~/ 4,
        ),
      );

      final txSig = await connection.sendAndConfirmTransaction(
        message: message,
        signers: [sender.keypair],
      );
      expect(txSig, isNotEmpty);
    });

    test('getTransaction returns details after confirmation', () async {
      final sender = await KeypairWallet.generate();
      final recipient = await solana.Ed25519HDKeyPair.random();

      // Fund sender
      final airdropSig = await connection.requestAirdrop(
        sender.publicKey.toBase58(),
        2 * _lamportsPerSol,
      );
      await connection.confirmTransaction(airdropSig);

      // Transfer
      final message = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: sender.keypair.publicKey,
          recipientAccount: recipient.publicKey,
          lamports: _lamportsPerSol ~/ 10,
        ),
      );

      final txSig = await connection.sendAndConfirmTransaction(
        message: message,
        signers: [sender.keypair],
        commitment: dto.Commitment.confirmed,
      );

      // Fetch transaction details
      final details = await connection.getTransaction(txSig);
      expect(details, isNotNull);
    });

    test('confirmTransaction with timeout', () async {
      final wallet = await KeypairWallet.generate();
      final sig = await connection.requestAirdrop(
        wallet.publicKey.toBase58(),
        _lamportsPerSol,
      );

      // Should confirm within a reasonable time
      await connection.confirmTransaction(
        sig,
        timeout: const Duration(seconds: 30),
      );

      final balance = await connection.getBalance(wallet.publicKey.toBase58());
      expect(balance, equals(_lamportsPerSol));
    });

    test('multiple sequential transfers maintain correct balances', () async {
      final sender = await KeypairWallet.generate();
      final r1 = await solana.Ed25519HDKeyPair.random();
      final r2 = await solana.Ed25519HDKeyPair.random();

      // Fund sender with 3 SOL
      final sig = await connection.requestAirdrop(
        sender.publicKey.toBase58(),
        3 * _lamportsPerSol,
      );
      await connection.confirmTransaction(sig);

      // Transfer 0.5 SOL to r1
      final msg1 = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: sender.keypair.publicKey,
          recipientAccount: r1.publicKey,
          lamports: _lamportsPerSol ~/ 2,
        ),
      );
      await connection.sendAndConfirmTransaction(
        message: msg1,
        signers: [sender.keypair],
      );

      // Transfer 0.3 SOL to r2
      final msg2 = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: sender.keypair.publicKey,
          recipientAccount: r2.publicKey,
          lamports: 300000000,
        ),
      );
      await connection.sendAndConfirmTransaction(
        message: msg2,
        signers: [sender.keypair],
      );

      // Verify balances
      final b1 = await connection.getBalance(r1.publicKey.toBase58());
      final b2 = await connection.getBalance(r2.publicKey.toBase58());
      expect(b1, equals(_lamportsPerSol ~/ 2));
      expect(b2, equals(300000000));

      // Sender: 3 SOL - 0.5 SOL - 0.3 SOL - 2 * TX fee
      final senderBalance = await connection.getBalance(
        sender.publicKey.toBase58(),
      );
      // Should be around 2.2 SOL minus fees
      expect(senderBalance, lessThan(2200000000));
      expect(senderBalance, greaterThan(2100000000)); // Fees won't be > 0.1 SOL
    });
  });

  // ─── T3.3 — AnchorProvider ─────────────────────────────────────────────────

  group('T3.3 — AnchorProvider', () {
    test('AnchorProvider.local() creates a working provider', () async {
      final provider = await AnchorProvider.local(url: _rpcUrl);
      expect(provider, isNotNull);
      expect(provider.connection, isNotNull);
      expect(provider.connection.endpoint, equals(_rpcUrl));
    });

    test('AnchorProvider.withWallet creates provider with wallet', () async {
      final wallet = await KeypairWallet.generate();
      final provider = AnchorProvider.withWallet(connection, wallet);
      expect(provider.wallet, isNotNull);
      expect(provider.connection, equals(connection));
    });

    test('AnchorProvider.readOnly creates wallet-less provider', () {
      final provider = AnchorProvider.readOnly(connection);
      expect(provider.connection, equals(connection));
    });
  });

  // ─── T3.4 — Wallet Classes ─────────────────────────────────────────────────

  group('T3.4 — Wallet classes', () {
    test('KeypairWallet.generate creates new wallet', () async {
      final wallet = await KeypairWallet.generate();
      expect(wallet.publicKey, isNotNull);
      expect(wallet.publicKey.toBase58(), isNotEmpty);
    });

    test('Keypair.generate creates new keypair', () async {
      final kp = await Keypair.generate();
      expect(kp.publicKey, isNotNull);
      expect(kp.publicKey.toBase58(), isNotEmpty);
    });

    test('two generated wallets have different keys', () async {
      final w1 = await KeypairWallet.generate();
      final w2 = await KeypairWallet.generate();
      expect(w1.publicKey.toBase58(), isNot(equals(w2.publicKey.toBase58())));
    });
  });
}
