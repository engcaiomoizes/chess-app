import 'package:chess_app/features/chess/controllers/chess_game_controller.dart';
import 'package:chess_app/features/chess/utils/chess_piece_mapper.dart';
import 'package:flutter/material.dart';

class ChessGamePage extends StatefulWidget {
  const ChessGamePage({super.key});

  @override
  State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  final ChessGameController game = ChessGameController.instance;

  String _squareName(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;
    return "$file$rank";
  }

  void _onMicPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Microfone pressionado. Aqui entrará o comando de voz."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = MediaQuery.of(context).size.width - 24;

    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: _buildChessBoard(),
                  ),
        
                  const SizedBox(height: 12),
        
                  SizedBox(
                    width: boardSize,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "É a vez das ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            game.isWhiteTurn ? "BRANCAS" : "PRETAS",
                            style: TextStyle(
                              color: game.isWhiteTurn ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
        
                  const SizedBox(height: 10),
        
                  Container(
                    width: boardSize,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Estatísticas",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
        
                        SizedBox(height: 8),
        
                        const Text(
                          "Última jogada:",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: 4),

                        if (game.lastMoveFrom == null || game.lastMoveTo == null)
                          const Text(
                            "Nenhuma jogada realizada",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                game.lastMoveFrom!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.arrow_forward),
                              Text(
                                game.lastMoveTo!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          if (game.lastMoveSan != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Notação: ${game.lastMoveSan}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
        
                  const SizedBox(height: 24),
        
                  FloatingActionButton(
                    onPressed: _onMicPressed,
                    child: const Icon(Icons.mic),
                  ),

                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: game.resetGame,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reiniciar partida"),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildChessBoard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 64,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;

          return _buildSquare(row, col);
        },
      ),
    );
  }

  Widget _buildSquare(int row, int col) {
    final isLightSquare = (row + col).isEven;
    
    final pieceCode = game.pieceCodeAt(row, col);

    final isSelected = game.isSelected(row, col);
    final isLegalTarget = game.isLegalTarget(row, col);

    final squareColor = isSelected
      ? Colors.amber
      : isLegalTarget
        ? Colors.greenAccent
        : isLightSquare
          ? const Color(0xFFF0D9B5)
          : const Color(0xFFB58863);
    
    return GestureDetector(
      onTap: () => game.tapSquare(row, col),
      child: Container(
        color: squareColor,
        child: Stack(
          children: [
            if (pieceCode != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    ChessPieceMapper.assetPath(pieceCode),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              if (isLegalTarget && pieceCode == null)
                Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              Positioned(
                left: 3,
                bottom: 2,
                child: Text(
                  _squareName(row, col),
                  style: TextStyle(
                    fontSize: 9,
                    color: isLightSquare
                      ? Colors.brown.shade700
                      : Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}