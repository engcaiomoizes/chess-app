import 'package:chess_app/features/chess/models/chess_move_result.dart';
import 'package:chess_app/services/board_motion/physical_board_graph.dart';
import 'package:chess_app/services/board_motion/physical_move_analyser.dart';
import 'package:dartchess/dartchess.dart';

import 'physical_command.dart';

class PhysicalMovePlanner {
  static const double squareSize = 40.0;

  List<PhysicalCommand> buildPlan(ChessMoveResult move) {
    final analysis = PhysicalMoveAnalyser.analyse(move);

    switch (analysis.type) {
      case PhysicalMoveType.castling:
        return _buildCastlingPlan(move, analysis);
      
      case PhysicalMoveType.normal:
      case PhysicalMoveType.capture:
      case PhysicalMoveType.enPassant:
      case PhysicalMoveType.promotion:
      case PhysicalMoveType.promotionCapture:
        return _buildNormalOrCapturePlan(move);
    }
  }

  List<PhysicalCommand> _buildCastlingPlan(
    ChessMoveResult move,
    PhysicalMoveAnalysis analysis,
  ) {
    final commands = <PhysicalCommand>[];

    final graph = PhysicalBoardGraph.fromPosition(move.positionBefore);
    final occupied = Set<int>.from(graph.occupied);

    final kingMove = analysis.primaryMove;
    final rookMove = analysis.secondaryMove;

    if (rookMove == null) {
      throw Exception("Roque inválido: movimento da torre não identificado.");
    }

    final kingFromIndex = PhysicalBoardGraph.indexFromSquare(kingMove.from);
    final kingToIndex = PhysicalBoardGraph.indexFromSquare(kingMove.to);

    final rookFromIndex = PhysicalBoardGraph.indexFromSquare(rookMove.from);
    final rookToIndex = PhysicalBoardGraph.indexFromSquare(rookMove.to);

    // 1. Move o rei.
    //
    // A casa da torre continua bloqueada, porque a torre ainda está lá.
    occupied.remove(kingFromIndex);

    commands.addAll(
      _buildMainMoveWithDetours(
        fromIndex: kingFromIndex,
        toIndex: kingToIndex,
        occupied: occupied,
        hardBlocked: {
          rookFromIndex,
        },
      ),
    );

    // O _buildMainMoveWithDetours já atualiza o occupied:
    // remove kingFromIndex e adiciona kingToIndex.

    // 2. Move a torre.
    //
    // A casa final do rei precisa ser bloqueio absoluto,
    // para a torre não tentar passar por cima do rei.
    occupied.remove(rookFromIndex);

    commands.addAll(
      _buildMainMoveWithDetours(
        fromIndex: rookFromIndex,
        toIndex: rookToIndex,
        occupied: occupied,
        hardBlocked: {
          kingToIndex,
        },
      ),
    );

    return commands;
  }

  List<PhysicalCommand> _buildNormalOrCapturePlan(ChessMoveResult move) {
    final commands = <PhysicalCommand>[];

    final graph = PhysicalBoardGraph.fromPosition(move.positionBefore);
    final occupied = Set<int>.from(graph.occupied);

    final fromIndex = PhysicalBoardGraph.indexFromSquare(move.from);
    final toIndex = PhysicalBoardGraph.indexFromSquare(move.to);

    // IMPORTANTE:
    // Não remova fromIndex daqui ainda.
    //
    // Em caso de captura, a peça atacante ainda está fisicamente
    // na casa de origem enquanto a peça capturada é retirada.
    //
    // Portanto, durante a remoção da peça capturada,
    // fromIndex deve continuar bloqueado.

    // Se houver captura, primeiro remove fisicamente a peça capturada.
    if (move.capturedPiece != null) {
      final captureCommands = _buildCaptureCommands(
        capturedSquare: move.to,
        capturedPiece: move.capturedPiece!,
        occupied: occupied,
        attackerFromIndex: fromIndex,
      );

      commands.addAll(captureCommands);

      // Depois da captura, a casa de destino ficou livre
      // para receber a peça atacante.
      occupied.remove(toIndex);
    }

    // Agora sim liberamos a origem da peça principa,
    // porque vamos mover essa peça.
    occupied.remove(fromIndex);

    // Agora planejamos o movimento principal.
    final mainCommands = _buildMainMoveWithDetours(
      fromIndex: fromIndex,
      toIndex: toIndex,
      occupied: occupied,
    );

    commands.addAll(mainCommands);

    return commands;
  }

  List<PhysicalCommand> _buildMainMoveWithDetours({
    required int fromIndex,
    required int toIndex,
    required Set<int> occupied,
    Set<int> hardBlocked = const {},
  }) {
    final commands = <PhysicalCommand>[];

    var graph = PhysicalBoardGraph(occupied: occupied);

    var mainPath = graph.shortestPath(
      fromIndex,
      toIndex,
      forbidden: hardBlocked,
    );

    if (mainPath.isEmpty) {
      throw Exception("Não foi possível calcular caminho físico.");
    }

    final detours = <_PhysicalDetour>[];

    var blockers = graph.occupiedNodesInsidePath(mainPath);

    while (blockers.isNotEmpty) {
      final blocker = blockers.first;

      final forbiddenDestinations = mainPath.toSet();

      final detourPath = graph.findTemporaryPathForBlocker(
        blocker: blocker,
        forbiddenDestinations: forbiddenDestinations,
        hardBlocked: {
          fromIndex,
          ...hardBlocked,
        },
      );

      if (detourPath.isEmpty) {
        throw Exception("Não foi possível calcula desvio para ${PhysicalBoardGraph.nameFromIndex(blocker)}.");
      }

      final temporaryIndex = detourPath.last;

      commands.addAll(_movePieceAlongPath(detourPath));

      occupied.remove(blocker);
      occupied.add(temporaryIndex);

      detours.add(
        _PhysicalDetour(
          originalIndex: blocker,
          temporaryIndex: temporaryIndex,
        ),
      );

      graph = PhysicalBoardGraph(occupied: occupied);
      mainPath = graph.shortestPath(
        fromIndex,
        toIndex,
        forbidden: hardBlocked,
      );

      blockers = graph.occupiedNodesInsidePath(mainPath);
    }

    // Move a peça principal.
    commands.addAll(_movePieceAlongPath(mainPath));

    // Atualiza a ocupação física depois da peça principal chegar ao destino.
    occupied.remove(fromIndex);
    occupied.add(toIndex);

    // Devolve as peças desviadas em ordem inversa.
    for (final detour in detours.reversed) {
      occupied.remove(detour.temporaryIndex);

      final restoreGraph = PhysicalBoardGraph(occupied: occupied);

      final blockedForRestore = <int>{
        ...occupied,
        ...hardBlocked,
      };

      final restorePath = restoreGraph.shortestPath(
        detour.temporaryIndex,
        detour.originalIndex,
        forbidden: blockedForRestore,
      );

      if (restorePath.isEmpty) {
        throw Exception("Não foi possível devolver peça para ${PhysicalBoardGraph.nameFromIndex(detour.originalIndex)}.");
      }

      commands.addAll(_movePieceAlongPath(restorePath));

      occupied.add(detour.originalIndex);
    }

    return commands;
  }

  List<PhysicalCommand> _buildCaptureCommands({
    required Square capturedSquare,
    required Piece capturedPiece,
    required Set<int> occupied,
    required int attackerFromIndex,
  }) {
    final capturedIndex = PhysicalBoardGraph.indexFromSquare(capturedSquare);

    final candidates = _captureTrayCandidates();

    List<PhysicalCommand>? bestCommands;
    int? bestTrayIndex;
    double bestCost = double.infinity;

    for (final candidate in candidates) {
      if (candidate == capturedIndex) continue;
      if (candidate == attackerFromIndex) continue;
      if (occupied.contains(candidate)) continue;

      try {
        final simulatedOccupied = Set<int>.from(occupied);

        final commands = _buildMainMoveWithDetours(
          fromIndex: capturedIndex,
          toIndex: candidate,
          occupied: simulatedOccupied,
          hardBlocked: {attackerFromIndex},
        );

        final cost = _commandsDistanceCost(commands);

        if (cost < bestCost) {
          bestCost = cost;
          bestCommands = commands;
          bestTrayIndex = candidate;
        }
      } catch (_) {
        // Se este candidato não tiver caminho possível,
        // simplesmente tenta o próximo.
      }
    }

    if (bestCommands == null || bestTrayIndex == null) {
      throw Exception("Não foi possível encontrar uma área de captura livre.");
    }

    // Atualiza o estado físico usado pelo restante do plano:
    // a peça capturada saiu da casa original e foi para a borda escolhida.
    occupied.remove(capturedIndex);
    occupied.add(bestTrayIndex);

    return bestCommands;
  }

  List<int> _captureTrayCandidates() {
    final candidates = <int>[];

    for (var row = 0; row < PhysicalBoardGraph.gridSize; row++) {
      for (var col = 0; col < PhysicalBoardGraph.gridSize; col++) {
        final isOutsideBoard = 
          col == 0 ||
          col == 9 ||
          row == 0 ||
          row == 9;
        
        if (!isOutsideBoard) continue;

        candidates.add(
          PhysicalBoardGraph.indexFromColRow(col, row),
        );
      }
    }

    return candidates;
  }

  double _commandsDistanceCost(List<PhysicalCommand> commands) {
    double total = 0;

    double? lastX;
    double? lastY;

    for (final command in commands) {
      switch (command.type) {
        case PhysicalCommandType.moveTo:
          final x = command.x!;
          final y = command.y!;

          if (lastX != null && lastY != null) {
            total += (x - lastX).abs() + (y - lastY).abs();
          }

          lastX = x;
          lastY = y;
          break;
        
        case PhysicalCommandType.magnetOn:
        case PhysicalCommandType.magnetOff:
          // Penalidade simbólica para ligar/desligar o eletroímã.
          total += 20;
          break;
        
        case PhysicalCommandType.delay:
          // Penalidade pequena pelo tempo parado.
          total += (command.milliseconds ?? 0) / 100;
          break;
      }
    }

    return total;
  }

  List<PhysicalCommand> _movePieceAlongPath(List<int> path) {
    if (path.isEmpty) return [];

    final commands = <PhysicalCommand>[];

    final start = _indexToPhysical(path.first);

    commands.add(PhysicalCommand.moveTo(x: start.x, y: start.y));
    commands.add(PhysicalCommand.magnetOn());
    commands.add(PhysicalCommand.delay(200));

    for (final index in path.skip(1)) {
      final position = _indexToPhysical(index);

      commands.add(
        PhysicalCommand.moveTo(
          x: position.x,
          y: position.y,
        ),
      );
    }

    commands.add(PhysicalCommand.delay(200));
    commands.add(PhysicalCommand.magnetOff());

    return commands;
  }

  ({double x, double y}) _indexToPhysical(int index) {
    final pos = PhysicalBoardGraph.colRowFromIndex(index);

    // colunas:
    // 0 = antes do a
    // 1 = a
    // ...
    // 8 = h
    // 9 = depois do h
    //
    // linhas:
    // 0 = abaixo/fora
    // 1..8 = tabuleiro
    // 9 = acima/fora
    final x = (pos.col - 1) * squareSize + squareSize / 2;
    final y = (8 - pos.row) * squareSize + squareSize / 2;

    return (x: x, y: y);
  }
}

class _PhysicalDetour {
  final int originalIndex;
  final int temporaryIndex;

  _PhysicalDetour({
    required this.originalIndex,
    required this.temporaryIndex,
  });
}