import 'package:test/test.dart';
import '../lib/coral_xyz_anchor.dart';

void main() {
  test('SimulationResultProcessor integration test', () {
    // Test that we can import and instantiate the SimulationResultProcessor
    final processor = SimulationResultProcessor();
    expect(processor, isNotNull);

    // Test ProcessingOptions
    final defaultOptions = ProcessingOptions.defaultOptions();
    expect(defaultOptions.extractEvents, true);

    final minimalOptions = ProcessingOptions.minimal();
    expect(minimalOptions.extractEvents, false);
    expect(minimalOptions.analyzeErrors, true);

    // Test configuration
    final config = SimulationProcessingConfig(maxCacheSize: 50);
    expect(config.maxCacheSize, equals(50));
  });
}
