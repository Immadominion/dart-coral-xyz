/// Feature flag management matching TypeScript Anchor SDK utils.features
library;

/// Feature flag management utilities
///
/// Matches TypeScript: utils.features.*
class FeaturesUtils {
  static final Map<String, bool> _features = <String, bool>{
    'seeds': true,
    'resolution': true,
    'defaultImpl': true,
  };

  /// Set a feature flag
  static void set(String key) {
    _features[key] = true;
  }

  /// Unset a feature flag
  static void unset(String key) {
    _features[key] = false;
  }

  /// Check if a feature is enabled
  static bool isSet(String key) {
    return _features[key] ?? false;
  }

  /// Get all enabled features
  static List<String> getEnabled() {
    return _features.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Reset all features to default state
  static void reset() {
    _features.clear();
    _features.addAll({'seeds': true, 'resolution': true, 'defaultImpl': true});
  }
}
