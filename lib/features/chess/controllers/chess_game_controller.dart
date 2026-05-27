import 'package:chess_app/features/chess/utils/chess_piece_mapper.dart';
import 'package:chess_app/features/chess/utils/chess_square_mapper.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

class ChessGameController extends ChangeNotifier {
  static final ChessGameController instance = ChessGameController._();

  ChessGameController._();

  Position _position = Chess.initial;

  Square? selectedSquare;
  SquareSet legalTargets = SquareSet.empty;

  String? lastMoveSan;
  String? lastMoveUci;
  String? lastMoveFrom;
  String? lastMoveTo;

  final List<String> moveHistorySan = [];

  Position get position => _position;

  bool get isWhiteTurn => _position.turn == Side.white;

  bool get isGameOver => _position.isGameOver;

  bool get isCheck => _position.isCheck;

  String get turnLabel {
    if (_position.isCheckmate) {
      return isWhiteTurn
        ? "Xeque-mate! As PRETAS venceram."
        : "Xeque-mate! As BRANCAS venceram.";
    }

    if (_position.isStalemate) {
      return "Empate por afogamento.";
    }

    if (_position.isInsufficientMaterial) {
      return "Empate por material insuficiente.";
    }

    if (_position.isCheck) {
      return isWhiteTurn
        ? "BRANCAS em xeque"
        : "PRETAS em xeque";
    }

    return isWhiteTurn
      ? "É a vez das BRANCAS"
      : "É a vez das PRETAS";
  }

  String? pieceCodeAt(int row, int col) {
    final square = ChessSquareMapper.fromRowCol(row, col);
    final piece = _position.board.pieceAt(square);

    return ChessPieceMapper.pieceCode(piece);
  }

  bool isSelected(int row, int col) {
    final square = ChessSquareMapper.fromRowCol(row, col);
    return selectedSquare == square;
  }

  bool isLegalTarget(int row, int col) {
    final square = ChessSquareMapper.fromRowCol(row, col);
    return legalTargets.has(square);
  }

  void tapSquare(int row, int col) {
    if (_position.isGameOver) return;

    final square = ChessSquareMapper.fromRowCol(row, col);
    final piece = _position.board.pieceAt(square);

    if (selectedSquare == null) {
      _selectSquare(square, piece);
      return;
    }

    if (selectedSquare == square) {
      _clearSelection();
      notifyListeners();
      return;
    }

    if (piece != null && piece.color == _position.turn) {
      _selectSquare(square, piece);
      return;
    }

    _tryMove(selectedSquare!, square);
  }

  void _selectSquare(Square square, Piece? piece) {
    if (piece == null) return;

    if (piece.color != _position.turn) return;

    selectedSquare = square;
    legalTargets = _position.legalMovesOf(square);

    notifyListeners();
  }

  void _tryMove(Square from, Square to) {
    final promotion = _promotionIfNeeded(from, to);

    final normalMove = NormalMove(
      from: from,
      to: to,
      promotion: promotion,
    );

    final move = _position.normalizeMove(normalMove);

    if (!_position.isLegal(move)) {
      _clearSelection();
      notifyListeners();
      return;
    }

    final result = _position.makeSan(move);

    _position = result.$1;
    final san = result.$2;

    lastMoveSan = san;
    lastMoveUci = move.uci;
    lastMoveFrom = from.name.toUpperCase();
    lastMoveTo = to.name.toUpperCase();

    moveHistorySan.add(lastMoveSan!);

    _clearSelection();

    notifyListeners();
  }

  Role? _promotionIfNeeded(Square from, Square to) {
    final piece = _position.board.pieceAt(from);

    if (piece == null) return null;
    if (piece.role != Role.pawn) return null;

    final targetRank = to.name.substring(1);

    final whitePromotes = piece.color == Side.white && targetRank == '8';
    final blackPromotes = piece.color == Side.black && targetRank == '1';

    if (whitePromotes || blackPromotes) {
      return Role.queen;
    }

    return null;
  }

  void _clearSelection() {
    selectedSquare = null;
    legalTargets = SquareSet.empty;
  }

  void resetGame() {
    _position = Chess.initial;
    selectedSquare = null;
    legalTargets = SquareSet.empty;
    lastMoveSan = null;
    lastMoveUci = null;
    moveHistorySan.clear();

    notifyListeners();
  }
}