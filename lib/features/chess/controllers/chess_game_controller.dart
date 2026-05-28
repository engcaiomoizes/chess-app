import 'package:chess_app/features/chess/models/chess_move_result.dart';
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

  ChessMoveResult? tapSquare(int row, int col) {
    if (_position.isGameOver) return null;

    final square = ChessSquareMapper.fromRowCol(row, col);
    final piece = _position.board.pieceAt(square);

    if (selectedSquare == null) {
      _selectSquare(square, piece);
      return null;
    }

    if (selectedSquare == square) {
      _clearSelection();
      notifyListeners();
      return null;
    }

    // Importante:
    // Antes de trocar a seleção para outra peça da mesma cor,
    // verificamos se a casa clicada é um destino legal.
    //
    // Isso permite executar o roque, porque no dartchess
    // a casa da Torre aparece como destino legal do Rei.
    if (legalTargets.has(square)) {
      return _tryMove(selectedSquare!, square);
    }

    // Só troca para a seleção se a casa clicada NÃO for um destino legal.
    if (piece != null && piece.color == _position.turn) {
      _selectSquare(square, piece);
      return null;
    }

    return _tryMove(selectedSquare!, square);
  }

  void _selectSquare(Square square, Piece? piece) {
    if (piece == null) return;

    if (piece.color != _position.turn) return;

    selectedSquare = square;
    legalTargets = _position.legalMovesOf(square);

    notifyListeners();
  }

  ChessMoveResult? _tryMove(Square from, Square to) {
    final positionBefore = _position;

    final movingPiece = positionBefore.board.pieceAt(from);
    final capturedPiece = positionBefore.board.pieceAt(to);

    if (movingPiece == null) {
      _clearSelection();
      notifyListeners();
      return null;
    }

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
      return null;
    }

    final result = _position.makeSan(move);

    _position = result.$1;
    final san = result.$2;

    lastMoveSan = san;
    lastMoveUci = move.uci;
    lastMoveFrom = from.name.toUpperCase();
    lastMoveTo = to.name.toUpperCase();

    moveHistorySan.add(lastMoveSan!);

    final moveResult = ChessMoveResult(
      uci: move.uci,
      san: san,
      from: from,
      to: to,
      movingPiece: movingPiece,
      capturedPiece: capturedPiece,
      positionBefore: positionBefore,
      positionAfter: _position,
    );

    _clearSelection();

    notifyListeners();

    return moveResult;
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
    lastMoveFrom = null;
    lastMoveTo = null;

    moveHistorySan.clear();

    notifyListeners();
  }
}