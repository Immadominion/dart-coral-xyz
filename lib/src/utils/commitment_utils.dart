/// Utilities for working with Solana commitment types

import 'package:coral_xyz/src/types/commitment.dart';
import 'package:solana/dto.dart' as dto;

/// Convert local Commitment type to Solana package Commitment type
dto.Commitment toSolanaCommitment(Commitment? commitment) {
  if (commitment == null) return dto.Commitment.confirmed;

  switch (commitment) {
    case Commitment.processed:
      return dto.Commitment.processed;
    case Commitment.confirmed:
      return dto.Commitment.confirmed;
    case Commitment.finalized:
    case Commitment.max:
    case Commitment.root:
      return dto.Commitment.finalized;
    case Commitment.single:
    case Commitment.singleGossip:
    case Commitment.recent:
      return dto.Commitment.confirmed;
  }
}

/// Convert from Solana package Commitment type to local Commitment type
Commitment fromSolanaCommitment(dto.Commitment? commitment) {
  if (commitment == null) return Commitment.confirmed;

  switch (commitment) {
    case dto.Commitment.processed:
      return Commitment.processed;
    case dto.Commitment.confirmed:
      return Commitment.confirmed;
    case dto.Commitment.finalized:
      return Commitment.finalized;
  }
}
