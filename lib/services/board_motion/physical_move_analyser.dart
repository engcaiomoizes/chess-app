import 'package:chess_app/features/chess/models/chess_move_result.dart';
import 'package:dartchess/dartchess.dart';

enum PhysicalMoveType {
  normal,
  capture,
  castling,
  enPassant,
  promotion,
  promotionCapture,
}

class PhysicalPieceMove {
  final Square from;
  final Square to;
  final Piece piece;

  const PhysicalPieceMove({
    required this.from,
    required this.to,
    required this.piece,
  });
}

class PhysicalMoveAnalysis {
  final PhysicalMoveType type;

  // Movimento principal da jogada.
  //
  // Exemplos:
  // - jogada normal: peça movida
  // - captura: peça atacante
  // - roque: rei
  // - en passant: peão atacante
  // - promoção: peão promovido
  final PhysicalPieceMove primaryMove;

  // Movimento secundário.
  //
  // Usado principalmente no roque:
  // - torre h1 -> f1
  // - torre a1 -> d1
  // - torre h8 -> f8
  // - torre a8 -> d8
  final PhysicalPieceMove? secondaryMove;

  // Casa onde está a peça capturada fisicamente.
  //
  // Em captura comum, é a casa de destino.
  //
  // Em en passant, é a casa atrás do destino.
  final Square? capturedSquare;

  // Peça capturada, se houver.
  final Piece? capturedPiece;

  // Peça de promoção.
  //
  // Por enquanto, no seu controller, você está promovendo automaticamente
  // para dama. Mesmo assim deixamos isso preparado.
  final Role? promotionRole;

  const PhysicalMoveAnalysis({
    required this.type,
    required this.primaryMove,
    this.secondaryMove,
    this.capturedSquare,
    this.capturedPiece,
    this.promotionRole,
  });

  bool get isCapture {
    return type == PhysicalMoveType.capture ||
      type == PhysicalMoveType.enPassant ||
      type == PhysicalMoveType.promotionCapture;
  }

  bool get isCastling {
    return type == PhysicalMoveType.castling;
  }

  bool get isPromotion {
    return type == PhysicalMoveType.promotion ||
      type == PhysicalMoveType.promotionCapture;
  }
}

class PhysicalMoveAnalyser {
  static PhysicalMoveAnalysis analyse(ChessMoveResult move) {
    if (_isCastling(move)) {
      return _analyseCastling(move);
    }

    if (_isEnPassant(move)) {
      return _analyseEnPassant(move);
    }

    final isPromotion = _isPromotion(move);
    final isCapture = move.capturedPiece != null;

    if (isPromotion && isCapture) {
      return PhysicalMoveAnalysis(
        type: PhysicalMoveType.promotionCapture,
        primaryMove: PhysicalPieceMove(
          from: move.from,
          to: move.to,
          piece: move.movingPiece,
        ),
        capturedSquare: move.to,
        capturedPiece: move.capturedPiece,
        promotionRole: _promotionRoleFromUci(move.uci) ?? Role.queen,
      );
    }

    if (isPromotion) {
      return PhysicalMoveAnalysis(
        type: PhysicalMoveType.promotion,
        primaryMove: PhysicalPieceMove(
          from: move.from,
          to: move.to,
          piece: move.movingPiece,
        ),
        promotionRole: _promotionRoleFromUci(move.uci) ?? Role.queen,
      );
    }

    if (isCapture) {
      return PhysicalMoveAnalysis(
        type: PhysicalMoveType.capture,
        primaryMove: PhysicalPieceMove(
          from: move.from,
          to: move.to,
          piece: move.movingPiece,
        ),
        capturedSquare: move.to,
        capturedPiece: move.capturedPiece,
      );
    }

    return PhysicalMoveAnalysis(
      type: PhysicalMoveType.normal,
      primaryMove: PhysicalPieceMove(
        from: move.from,
        to: move.to,
        piece: move.movingPiece,
      ),
    );
  }

  static bool _isCastling(ChessMoveResult move) {
    final san = move.san.replaceAll('+', '').replaceAll('#', '');

    return move.movingPiece.role == Role.king &&
        (san == 'O-O' || san == 'O-O-O');
  }

  static PhysicalMoveAnalysis _analyseCastling(ChessMoveResult move) {
    final san = move.san.replaceAll('+', '').replaceAll('#', '');

    final isWhite = move.movingPiece.color == Side.white;
    final rank = isWhite ? '1' : '8';

    final isKingSide = san == 'O-O';

    final kingFrom = Square.fromName('e$rank');
    final kingTo = Square.fromName(isKingSide ? 'g$rank' : 'c$rank');

    final rookFrom = Square.fromName(isKingSide ? 'h$rank' : 'a$rank');
    final rookTo = Square.fromName(isKingSide ? 'f$rank' : 'd$rank');

    final rookPiece = move.positionBefore.board.pieceAt(rookFrom);

    if (rookPiece == null) {
      throw Exception(
        'Roque inválido fisicamente: torre não encontrada em ${rookFrom.name}.',
      );
    }

    return PhysicalMoveAnalysis(
      type: PhysicalMoveType.castling,
      primaryMove: PhysicalPieceMove(
        from: kingFrom,
        to: kingTo,
        piece: move.movingPiece,
      ),
      secondaryMove: PhysicalPieceMove(
        from: rookFrom,
        to: rookTo,
        piece: rookPiece,
      ),
    );
  }

  static bool _isEnPassant(ChessMoveResult move) {
    if (move.movingPiece.role != Role.pawn) return false;

    // Em en passant, o peão anda na diagonal,
    // mas a casa de destino está vazia antes da jogada.
    if (move.capturedPiece != null) return false;

    final fromFile = _fileIndex(move.from);
    final toFile = _fileIndex(move.to);

    return fromFile != toFile;
  }

  static PhysicalMoveAnalysis _analyseEnPassant(ChessMoveResult move) {
    final capturedSquare = _enPassantCapturedSquare(move);
    final capturedPiece = move.positionBefore.board.pieceAt(capturedSquare);

    if (capturedPiece == null) {
      throw Exception(
        'En passant inválido fisicamente: peça capturada não encontrada em ${capturedSquare.name}.',
      );
    }

    return PhysicalMoveAnalysis(
      type: PhysicalMoveType.enPassant,
      primaryMove: PhysicalPieceMove(
        from: move.from,
        to: move.to,
        piece: move.movingPiece,
      ),
      capturedSquare: capturedSquare,
      capturedPiece: capturedPiece,
    );
  }

  static Square _enPassantCapturedSquare(ChessMoveResult move) {
    final toFile = move.to.name[0];
    final fromRank = move.from.name.substring(1);

    return Square.fromName('$toFile$fromRank');
  }

  static bool _isPromotion(ChessMoveResult move) {
    if (move.movingPiece.role != Role.pawn) return false;

    final targetRank = move.to.name.substring(1);

    final whitePromotes =
        move.movingPiece.color == Side.white && targetRank == '8';

    final blackPromotes =
        move.movingPiece.color == Side.black && targetRank == '1';

    return whitePromotes || blackPromotes;
  }

  static Role? _promotionRoleFromUci(String uci) {
    if (uci.length < 5) return null;

    final promotionChar = uci[4].toLowerCase();

    switch (promotionChar) {
      case 'q':
        return Role.queen;
      case 'r':
        return Role.rook;
      case 'b':
        return Role.bishop;
      case 'n':
        return Role.knight;
      default:
        return null;
    }
  }

  static int _fileIndex(Square square) {
    return square.name.codeUnitAt(0) - 'a'.codeUnitAt(0);
  }
}