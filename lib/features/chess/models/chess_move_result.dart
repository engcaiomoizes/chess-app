import 'package:dartchess/dartchess.dart';

class ChessMoveResult {
  final String uci;
  final String san;

  final Square from;
  final Square to;

  final Piece movingPiece;
  final Piece? capturedPiece;

  final Position positionBefore;
  final Position positionAfter;

  ChessMoveResult({
    required this.uci,
    required this.san,
    required this.from,
    required this.to,
    required this.movingPiece,
    required this.capturedPiece,
    required this.positionBefore,
    required this.positionAfter,
  });
}