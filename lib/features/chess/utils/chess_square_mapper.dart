import 'package:dartchess/dartchess.dart';

class ChessSquareMapper {
  static Square fromRowCol(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;

    return Square.fromName("$file$rank");
  }

  static String nameFromRowCol(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;

    return "$file$rank";
  }
}