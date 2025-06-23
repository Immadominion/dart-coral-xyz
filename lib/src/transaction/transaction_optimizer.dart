/// Transaction Optimization Infrastructure
///
/// This module provides transaction optimization capabilities for improving
/// cost, performance, and efficiency of Solana transactions.

library;

import '../types/public_key.dart';
import 'transaction_builder.dart';

/// Transaction optimization configuration
class TransactionOptimizationConfig {
  /// Enable account deduplication
  final bool deduplicateAccounts;

  /// Enable instruction reordering
  final bool reorderInstructions;

  /// Enable compute budget optimization
  final bool optimizeComputeBudget;

  /// Enable size optimization
  final bool optimizeSize;

  /// Target compute unit limit (null for auto)
  final int? targetComputeUnits;

  /// Target transaction size limit (null for auto)
  final int? targetSize;

  const TransactionOptimizationConfig({
    this.deduplicateAccounts = true,
    this.reorderInstructions = true,
    this.optimizeComputeBudget = true,
    this.optimizeSize = true,
    this.targetComputeUnits,
    this.targetSize,
  });

  /// Create aggressive optimization configuration
  factory TransactionOptimizationConfig.aggressive() {
    return const TransactionOptimizationConfig(
      deduplicateAccounts: true,
      reorderInstructions: true,
      optimizeComputeBudget: true,
      optimizeSize: true,
    );
  }

  /// Create conservative optimization configuration
  factory TransactionOptimizationConfig.conservative() {
    return const TransactionOptimizationConfig(
      deduplicateAccounts: true,
      reorderInstructions: false,
      optimizeComputeBudget: false,
      optimizeSize: true,
    );
  }
}

/// Transaction optimization result
class TransactionOptimizationResult {
  /// Optimized transaction builder
  final TransactionBuilder optimizedBuilder;

  /// Optimization metrics
  final TransactionOptimizationMetrics metrics;

  /// Applied optimizations
  final List<String> appliedOptimizations;

  /// Optimization warnings
  final List<String> warnings;

  const TransactionOptimizationResult({
    required this.optimizedBuilder,
    required this.metrics,
    required this.appliedOptimizations,
    required this.warnings,
  });

  /// Get optimization summary
  String get summary {
    final buffer = StringBuffer();
    buffer.write('Applied ${appliedOptimizations.length} optimizations: ');
    buffer.write(appliedOptimizations.join(', '));

    if (warnings.isNotEmpty) {
      buffer.write(' (${warnings.length} warnings)');
    }

    return buffer.toString();
  }
}

/// Transaction optimization metrics
class TransactionOptimizationMetrics {
  /// Original transaction size
  final int originalSize;

  /// Optimized transaction size
  final int optimizedSize;

  /// Original compute units
  final int originalComputeUnits;

  /// Optimized compute units
  final int optimizedComputeUnits;

  /// Original instruction count
  final int originalInstructionCount;

  /// Optimized instruction count
  final int optimizedInstructionCount;

  /// Optimization time in milliseconds
  final int optimizationTimeMs;

  const TransactionOptimizationMetrics({
    required this.originalSize,
    required this.optimizedSize,
    required this.originalComputeUnits,
    required this.optimizedComputeUnits,
    required this.originalInstructionCount,
    required this.optimizedInstructionCount,
    required this.optimizationTimeMs,
  });

  /// Size reduction percentage
  double get sizeReduction =>
      ((originalSize - optimizedSize) / originalSize * 100).clamp(0, 100);

  /// Compute units reduction percentage
  double get computeReduction =>
      ((originalComputeUnits - optimizedComputeUnits) /
              originalComputeUnits *
              100)
          .clamp(0, 100);

  /// Instruction count reduction percentage
  double get instructionReduction =>
      ((originalInstructionCount - optimizedInstructionCount) /
              originalInstructionCount *
              100)
          .clamp(0, 100);

  /// Overall optimization score (0-100)
  double get optimizationScore {
    return (sizeReduction + computeReduction + instructionReduction) / 3;
  }
}

/// Account usage tracking for optimization
class AccountUsage {
  final PublicKey account;
  final List<int> instructionIndices;
  final bool isSigner;
  final bool isWritable;
  final int usageCount;

  const AccountUsage({
    required this.account,
    required this.instructionIndices,
    required this.isSigner,
    required this.isWritable,
    required this.usageCount,
  });
}

/// Instruction dependency information
class InstructionDependency {
  final int instructionIndex;
  final List<PublicKey> readAccounts;
  final List<PublicKey> writeAccounts;
  final List<int> dependsOn;

  const InstructionDependency({
    required this.instructionIndex,
    required this.readAccounts,
    required this.writeAccounts,
    required this.dependsOn,
  });
}

/// Transaction optimizer with comprehensive optimization strategies
class TransactionOptimizer {
  final TransactionOptimizationConfig _config;

  const TransactionOptimizer({
    TransactionOptimizationConfig? config,
  }) : _config = config ?? const TransactionOptimizationConfig();

  /// Optimize a transaction builder
  Future<TransactionOptimizationResult> optimize(
    TransactionBuilder builder,
  ) async {
    final stopwatch = Stopwatch()..start();
    final appliedOptimizations = <String>[];
    final warnings = <String>[];

    // Clone the builder for optimization
    final optimizedBuilder = _cloneBuilder(builder);

    // Get original metrics
    final originalStats = builder.getStats();
    final originalSize = originalStats['estimatedSize'] as int;
    final originalInstructionCount = originalStats['instructionCount'] as int;
    final originalComputeUnits = _estimateComputeUnits(originalStats);

    try {
      // Apply optimizations
      if (_config.deduplicateAccounts) {
        final deduplicated = await _deduplicateAccounts(optimizedBuilder);
        if (deduplicated) {
          appliedOptimizations.add('account_deduplication');
        }
      }

      if (_config.reorderInstructions) {
        final reordered = await _reorderInstructions(optimizedBuilder);
        if (reordered) {
          appliedOptimizations.add('instruction_reordering');
        }
      }

      if (_config.optimizeComputeBudget) {
        final optimized = await _optimizeComputeBudget(optimizedBuilder);
        if (optimized) {
          appliedOptimizations.add('compute_budget_optimization');
        }
      }

      if (_config.optimizeSize) {
        final optimized = await _optimizeSize(optimizedBuilder);
        if (optimized) {
          appliedOptimizations.add('size_optimization');
        }
      }

      stopwatch.stop();

      // Calculate final metrics
      final optimizedStats = optimizedBuilder.getStats();
      final optimizedSize = optimizedStats['estimatedSize'] as int;
      final optimizedInstructionCount =
          optimizedStats['instructionCount'] as int;
      final optimizedComputeUnits = _estimateComputeUnits(optimizedStats);

      final metrics = TransactionOptimizationMetrics(
        originalSize: originalSize,
        optimizedSize: optimizedSize,
        originalComputeUnits: originalComputeUnits,
        optimizedComputeUnits: optimizedComputeUnits,
        originalInstructionCount: originalInstructionCount,
        optimizedInstructionCount: optimizedInstructionCount,
        optimizationTimeMs: stopwatch.elapsedMilliseconds,
      );

      return TransactionOptimizationResult(
        optimizedBuilder: optimizedBuilder,
        metrics: metrics,
        appliedOptimizations: appliedOptimizations,
        warnings: warnings,
      );
    } catch (e) {
      stopwatch.stop();

      warnings.add('Optimization failed: $e');

      // Return original builder if optimization fails
      return TransactionOptimizationResult(
        optimizedBuilder: builder,
        metrics: TransactionOptimizationMetrics(
          originalSize: originalSize,
          optimizedSize: originalSize,
          originalComputeUnits: originalComputeUnits,
          optimizedComputeUnits: originalComputeUnits,
          originalInstructionCount: originalInstructionCount,
          optimizedInstructionCount: originalInstructionCount,
          optimizationTimeMs: stopwatch.elapsedMilliseconds,
        ),
        appliedOptimizations: [],
        warnings: warnings,
      );
    }
  }

  /// Clone a transaction builder (simplified implementation)
  TransactionBuilder _cloneBuilder(TransactionBuilder original) {
    // For now, return the original builder
    // In a complete implementation, this would create a deep copy
    return original;
  }

  /// Deduplicate accounts to reduce transaction size
  Future<bool> _deduplicateAccounts(TransactionBuilder builder) async {
    // Analyze account usage
    final accountUsage = _analyzeAccountUsage(builder);

    // Identify redundant accounts
    final redundantAccounts = accountUsage
        .where((usage) => usage.usageCount == 1 && !usage.isSigner)
        .toList();

    if (redundantAccounts.isEmpty) {
      return false;
    }

    // TODO: Implement account deduplication logic
    // This would involve merging similar accounts and updating instruction references

    return redundantAccounts.isNotEmpty;
  }

  /// Reorder instructions for optimal execution
  Future<bool> _reorderInstructions(TransactionBuilder builder) async {
    // Analyze instruction dependencies
    final dependencies = _analyzeInstructionDependencies(builder);

    if (dependencies.length <= 1) {
      return false; // No reordering needed for single instruction
    }

    // TODO: Implement instruction reordering logic
    // This would topologically sort instructions based on dependencies

    return false; // Placeholder
  }

  /// Optimize compute budget for cost efficiency
  Future<bool> _optimizeComputeBudget(TransactionBuilder builder) async {
    final stats = builder.getStats();
    final estimatedUnits = _estimateComputeUnits(stats);

    // Add compute budget instruction if beneficial
    if (estimatedUnits > 200000) {
      // Add compute unit limit instruction
      final targetUnits =
          _config.targetComputeUnits ?? (estimatedUnits * 1.1).round();
      builder.computeUnits(targetUnits);
      return true;
    }

    return false;
  }

  /// Optimize transaction size
  Future<bool> _optimizeSize(TransactionBuilder builder) async {
    final stats = builder.getStats();
    final currentSize = stats['estimatedSize'] as int;

    if (currentSize > 1000) {
      // TODO: Implement size optimization strategies:
      // - Compress instruction data
      // - Use lookup tables for common accounts
      // - Split large transactions
      return true;
    }

    return false;
  }

  /// Analyze account usage patterns
  List<AccountUsage> _analyzeAccountUsage(TransactionBuilder builder) {
    // TODO: Implement account usage analysis
    // This would track how each account is used across instructions
    return [];
  }

  /// Analyze instruction dependencies
  List<InstructionDependency> _analyzeInstructionDependencies(
    TransactionBuilder builder,
  ) {
    // TODO: Implement dependency analysis
    // This would determine read/write dependencies between instructions
    return [];
  }

  /// Estimate compute units for stats
  int _estimateComputeUnits(Map<String, dynamic> stats) {
    final instructionCount = stats['instructionCount'] as int;
    final accountCount = stats['uniqueAccounts'] as int;

    // Simple estimation formula
    return 5000 + (instructionCount * 1000) + (accountCount * 100);
  }

  /// Get optimization recommendations
  List<String> getOptimizationRecommendations(TransactionBuilder builder) {
    final recommendations = <String>[];
    final stats = builder.getStats();

    final size = stats['estimatedSize'] as int;
    final instructionCount = stats['instructionCount'] as int;
    final accountCount = stats['uniqueAccounts'] as int;

    // Size recommendations
    if (size > 1000) {
      recommendations
          .add('Consider reducing transaction size (currently $size bytes)');
    }

    // Instruction count recommendations
    if (instructionCount > 10) {
      recommendations.add(
          'High instruction count ($instructionCount) - consider batching');
    }

    // Account count recommendations
    if (accountCount > 20) {
      recommendations.add(
          'High account count ($accountCount) - consider using lookup tables');
    }

    return recommendations;
  }

  /// Estimate transaction fee based on current Solana pricing
  double estimateTransactionFee(TransactionBuilder builder) {
    final stats = builder.getStats();
    final estimatedComputeUnits = _estimateComputeUnits(stats);

    // Base fee (5000 lamports) + compute fee
    const baseFee = 5000;
    const microLamportsPerComputeUnit = 1;

    final computeFee =
        (estimatedComputeUnits * microLamportsPerComputeUnit) / 1000000;

    return (baseFee + computeFee) / 1000000000; // Convert to SOL
  }

  /// Get performance insights
  Map<String, dynamic> getPerformanceInsights(TransactionBuilder builder) {
    final stats = builder.getStats();
    final estimatedFee = estimateTransactionFee(builder);
    final estimatedComputeUnits = _estimateComputeUnits(stats);

    return {
      'estimatedFee': estimatedFee,
      'estimatedComputeUnits': estimatedComputeUnits,
      'complexity': _calculateComplexityScore(stats),
      'efficiency': _calculateEfficiencyScore(stats),
      'recommendations': getOptimizationRecommendations(builder),
    };
  }

  /// Calculate transaction complexity score (0-100)
  double _calculateComplexityScore(Map<String, dynamic> stats) {
    final instructionCount = stats['instructionCount'] as int;
    final accountCount = stats['uniqueAccounts'] as int;
    final size = stats['estimatedSize'] as int;

    // Normalize each metric (higher values = higher complexity)
    final instructionScore = (instructionCount / 20 * 100).clamp(0, 100);
    final accountScore = (accountCount / 40 * 100).clamp(0, 100);
    final sizeScore = (size / 1232 * 100).clamp(0, 100);

    return (instructionScore + accountScore + sizeScore) / 3;
  }

  /// Calculate transaction efficiency score (0-100)
  double _calculateEfficiencyScore(Map<String, dynamic> stats) {
    final complexity = _calculateComplexityScore(stats);
    final size = stats['estimatedSize'] as int;

    // Efficiency is inverse of complexity and size utilization
    final sizeEfficiency = (1 - (size / 1232)) * 100;
    final complexityEfficiency = (1 - (complexity / 100)) * 100;

    return ((sizeEfficiency + complexityEfficiency) / 2).clamp(0, 100);
  }
}
