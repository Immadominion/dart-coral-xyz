import 'package:solana/solana.dart' as solana;

void main() async {
  // Test if airdrop functionality exists in the solana package
  print('Testing airdrop API...');

  // Create a client
  final client = solana.SolanaClient(
    rpcUrl: Uri.parse('https://api.devnet.solana.com'),
    websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
  );

  print('Client created: ${client.runtimeType}');
  print('RPC client type: ${client.rpcClient.runtimeType}');

  // Check if requestAirdrop method exists
  try {
    // Create a dummy public key for testing
    final dummyKey = solana.Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',);

    // Try to call requestAirdrop (this will likely fail but we can see if the method exists)
    final result =
        await client.rpcClient.requestAirdrop(dummyKey.toBase58(), 1000000000);
    print('Airdrop result: $result');
  } catch (e) {
    print('Airdrop error (checking if method exists): $e');
    print('Error type: ${e.runtimeType}');
  }

  // Let's also check what methods are available on the RPC client
  print('\nRPC client type: ${client.rpcClient.runtimeType}');

  // Check the class structure
  print('Checking if we can inspect available methods...');
}
