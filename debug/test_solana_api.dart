import 'package:solana/solana.dart' as solana;

void main() async {
  // Test what's available in the solana package
  print('Testing solana package API...');

  // Create a client
  final client = solana.SolanaClient(
    rpcUrl: Uri.parse('https://api.devnet.solana.com'),
    websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
  );

  print('Client created: ${client.runtimeType}');
  print('RPC client type: ${client.rpcClient.runtimeType}');

  // Test getting latest blockhash to see what format it returns
  try {
    final latestBlockhash = await client.rpcClient.getLatestBlockhash();
    print('Latest blockhash result type: ${latestBlockhash.runtimeType}');
    print('Latest blockhash properties: ${latestBlockhash.toString()}');

    // Try to access common properties
    try {
      print('Blockhash value: ${latestBlockhash.value}');
    } catch (e) {
      print('No .value property: $e');
    }
  } catch (e) {
    print('Error getting latest blockhash: $e');
  }

  // Test creating a public key
  try {
    final pubkey = solana.Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',);
    print('Public key created: ${pubkey.runtimeType}');
    print('Public key: $pubkey');
  } catch (e) {
    print('Error creating public key: $e');
  }

  // Test if we can send a raw transaction (even if it fails)
  try {
    // This will probably fail, but we can see what method signature is expected
    await client.rpcClient.sendTransaction('test');
  } catch (e) {
    print('sendTransaction error (expected): $e');
  }
}
