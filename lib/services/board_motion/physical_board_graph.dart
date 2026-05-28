import 'package:dartchess/dartchess.dart';

class PhysicalBoardGraph {
  static const int gridSize = 10;
  static const int vertexCount = gridSize * gridSize;

  static const int freeCost = 1;
  static const int occupiedCost = 10;
  static const int outsideCost = 8;

  final Set<int> occupied;

  PhysicalBoardGraph({
    required this.occupied,
  });

  static PhysicalBoardGraph fromPosition(Position position) {
    final occupied = <int>{};

    for (var fileCode = 'a'.codeUnitAt(0); fileCode <= 'h'.codeUnitAt(0); fileCode++) {
      for (var rank = 1; rank <= 8; rank++) {
        final squareName = "${String.fromCharCode(fileCode)}$rank";
        final square = Square.fromName(squareName);

        if (position.board.pieceAt(square) != null) {
          occupied.add(indexFromSquare(square));
        }
      }
    }

    return PhysicalBoardGraph(occupied: occupied);
  }

  static int indexFromSquare(Square square) {
    final fileCode = square.name.codeUnitAt(0);

    final col = fileCode - 'a'.codeUnitAt(0) + 1;
    final row = int.parse(square.name.substring(1));

    return indexFromColRow(col, row);
  }

  static int indexFromColRow(int col, int row) {
    return row * gridSize + col;
  }

  static ({int col, int row}) colRowFromIndex(int index) {
    final row = index ~/ gridSize;
    final col = index % gridSize;

    return (col: col, row: row);
  }

  static String nameFromIndex(int index) {
    final pos = colRowFromIndex(index);
    final file = String.fromCharCode('a'.codeUnitAt(0) - 1 + pos.col);

    return "$file${pos.row}";
  }

  List<int> neighborsOf(int index) {
    final pos = colRowFromIndex(index);

    final neighbors = <int>[];

    final col = pos.col;
    final row = pos.row;

    if (col > 0) {
      neighbors.add(indexFromColRow(col - 1, row));
    }

    if (col < gridSize - 1) {
      neighbors.add(indexFromColRow(col + 1, row));
    }

    if (row > 0) {
      neighbors.add(indexFromColRow(col, row - 1));
    }

    if (row < gridSize - 1) {
      neighbors.add(indexFromColRow(col, row + 1));
    }

    return neighbors;
  }

  int costToEnter(int index) {
    if (occupied.contains(index)) {
      return occupiedCost;
    }

    final pos = colRowFromIndex(index);

    final isOutsideBoard = 
      pos.col == 0 ||
      pos.col == 9 ||
      pos.row == 0 ||
      pos.row == 9;
    
    if (isOutsideBoard) {
      return outsideCost;
    }

    return freeCost;
  }

  List<int> shortestPath(int from, int to, { Set<int> forbidden = const {} }) {
    const undefined = -1;

    final distance = List<int>.filled(vertexCount, 1 << 30);
    final previous = List<int>.filled(vertexCount, undefined);
    final unvisited = <int>{};

    for (var i = 0; i < vertexCount; i++) {
      unvisited.add(i);
    }

    distance[from] = 0;

    while (unvisited.isNotEmpty) {
      final current = _closest(distance, unvisited);

      if (current == undefined) break;

      unvisited.remove(current);

      if (current == to) {
        return _buildPath(previous, current);
      }

      for (final neighbor in neighborsOf(current)) {
        if (!unvisited.contains(neighbor)) continue;

        if (forbidden.contains(neighbor) && neighbor != to && neighbor != from) {
          continue;
        }

        final newCost = distance[current] + costToEnter(neighbor);

        if (newCost < distance[neighbor]) {
          distance[neighbor] = newCost;
          previous[neighbor] = current;
        }
      }
    }

    return [];
  }

  int _closest(List<int> distance, Set<int> unvisited) {
    var bestIndex = -1;
    var bestDistance = 1 << 30;

    for (final index in unvisited) {
      if (distance[index] < bestDistance) {
        bestDistance = distance[index];
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  List<int> _buildPath(List<int> previous, int current) {
    final path = <int>[current];

    var cursor = current;

    while (previous[cursor] != -1) {
      cursor = previous[cursor];
      path.add(cursor);
    }

    return path.reversed.toList();
  }

  int pathCost(List<int> path) {
    var total = 0;

    for (var i = 1; i < path.length; i++) {
      total += costToEnter(path[i]);
    }

    return total;
  }

  List<int> occupiedNodesInsidePath(List<int> path) {
    if (path.length <= 2) return [];

    return path
      .sublist(1, path.length - 1)
      .where((index) => occupied.contains(index))
      .toList();
  }

  List<int> findTemporaryPathForBlocker({
    required int blocker,
    required Set<int> forbiddenDestinations,
    Set<int> hardBlocked = const {},
  }) {
    var bestPath = <int>[];
    var bestCost = 1 << 30;

    // Remove temporariamente a própria peça bloqueadora da lista de ocupadas,
    // porque ela é a peça que será movida.
    final tempOccupied = Set<int>.from(occupied);
    tempOccupied.remove(blocker);

    final tempGraph = PhysicalBoardGraph(occupied: tempOccupied);

    // Para o caminho de desvio, casas ocupadas são bloqueios absolutos.
    // Mas o caminho principal NÃO deve ser bloqueio absoluto,
    // porque a peça pode passar por uma casa livre do caminho principal.
    final blockedForDetour = <int>{
      ...tempOccupied,
      ...hardBlocked,
    };

    for (var candidate = 0; candidate < vertexCount; candidate++) {
      // A posição temporária não pode estar ocupada.
      if (tempOccupied.contains(candidate)) continue;

      // A posição temporária não pode estar no caminho principal.
      if (forbiddenDestinations.contains(candidate)) continue;

      // A posição temporária também não pode estar em bloqueio rígido.
      if (hardBlocked.contains(candidate)) continue;

      final path = tempGraph.shortestPath(
        blocker,
        candidate,
        forbidden: blockedForDetour,
      );

      if (path.isEmpty) continue;

      final cost = tempGraph.pathCost(path);

      if (cost < bestCost) {
        bestCost = cost;
        bestPath = path;
      }
    }

    return bestPath;
  }
}