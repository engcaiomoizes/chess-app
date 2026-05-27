import 'package:dartchess/dartchess.dart';

class ChessPieceMapper {
  static String? pieceCode(Piece? piece) {
    if (piece == null) return null;

    final colorCode = piece.color == Side.white ? 'w' : 'b';

    final roleCode = switch (piece.role) {
      Role.pawn => 'p',
      Role.knight => 'n',
      Role.bishop => 'b',
      Role.rook => 'r',
      Role.queen => 'q',
      Role.king => 'k',
    };

    return "$colorCode$roleCode";
  }

  static String assetPath(String pieceCode) {
    return "assets/pieces/$pieceCode.png";
  }
}