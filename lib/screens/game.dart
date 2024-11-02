import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:convert';

class Mygame extends StatefulWidget {
  const Mygame({super.key});

  @override
  State<Mygame> createState() => _MygameState();
}

class _MygameState extends State<Mygame> with SingleTickerProviderStateMixin {
  List<String> grids = ["3x3", "4x4", "5x5"];
  List<List<ui.Image?>> gridValues = [];
  List<List<ui.Image?>> winningGridValues = [];
  bool shuffled = false;
  bool paused = false;
  int gridSize = 3;
  int selectedGridIndex = -1; // Track selected button index
  Timer? timer;
  int secondsElapsed = 0;

  // Animation variables
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Map<String, dynamic>? _data; // Data member to hold JSON data

  Future<void> loadJsonData() async {
    String jsonString = await rootBundle.loadString('assets/data.json');
    setState(() {
      _data = json.decode(jsonString);
    });
  }

  @override
  void initState() {
    super.initState();
    selectedGridIndex = 0; // Set default selection to "3x3"
    loadAndSplitImage(3); // Load the 3x3 grid at startup
    loadJsonData();

    // Initialize the animation controller and scale animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  Future<void> loadAndSplitImage(int size) async {
    try {
      final ByteData data = await rootBundle.load('assets/play1.png');
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      List<List<ui.Image?>> newGridValues = [];
      List<List<ui.Image?>> newWinningGridValues = [];
      int pieceWidth = image.width ~/ size;
      int pieceHeight = image.height ~/ size;

      for (int i = 0; i < size; i++) {
        List<ui.Image?> row = [];
        List<ui.Image?> winningRow = [];
        for (int j = 0; j < size; j++) {
          if (i == size - 1 && j == size - 1) {
            row.add(null); // Empty slot
            winningRow.add(null);
          } else {
            ui.Image piece = await cropImage(image, j * pieceWidth,
                i * pieceHeight, pieceWidth, pieceHeight);
            row.add(piece);
            winningRow.add(piece);
          }
        }
        newGridValues.add(row);
        newWinningGridValues.add(winningRow);
      }

      setState(() {
        gridSize = size;
        gridValues = newGridValues;
        winningGridValues = newWinningGridValues;
        shuffled = false;
        secondsElapsed = 0;
        paused = false;
        timer?.cancel();
      });
    } catch (e) {
      print("Error loading or splitting image: $e");
    }
  }

  Future<ui.Image> cropImage(
      ui.Image image, int x, int y, int width, int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
          x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    return await recorder.endRecording().toImage(width, height);
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (!paused) secondsElapsed++;
      });
    });
  }

  void togglePause() {
    setState(() {
      paused = !paused;
      if (paused) {
        timer?.cancel();
      } else {
        startTimer();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6D4B82),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: const Color(0xFF6D4B82),
          title: Container(
            padding: const EdgeInsets.only(top: 20),
            alignment: Alignment.center,
            child: const Text(
              "15 Puzzle",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Time: ${secondsElapsed ~/ 60}:${(secondsElapsed % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(
                width: 50,
              ),
              Text(
                'Best timing: ${_data![selectedGridIndex.toString()]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!shuffled)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(grids.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedGridIndex == index
                          ? Colors.orange // Change color if selected
                          : const Color(0xFF5E3A6F), // Default color
                    ),
                    onPressed: () {
                      setState(() {
                        selectedGridIndex = index; // Update selected index
                      });
                      int size = int.parse(grids[index].split('x')[0]);
                      loadAndSplitImage(size);
                    },
                    child: Text(
                      grids[index],
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white, // White text for contrast
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                buildGrid(paused ? winningGridValues : gridValues),
                if (paused)
                  Center(
                    child: Container(
                      color: Colors.black54,
                      child: const Text(
                        "PAUSED",
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E3A6F),
                ),
                onPressed: () {
                  if (!shuffled) {
                    setState(() {
                      shuffled = true;
                      shuffleGrid();
                      startTimer(); // Start timer when shuffle starts
                    });
                  } else {
                    togglePause();
                  }
                },
                child: Text(
                  shuffled ? (paused ? "Resume" : "Pause") : "Play now",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void shuffleGrid() {
    int emptyRow = gridSize - 1;
    int emptyCol = gridSize - 1;

    for (int i = 0; i < 100; i++) {
      List<List<int>> possibleMoves = [];

      if (emptyRow > 0) possibleMoves.add([emptyRow - 1, emptyCol]);
      if (emptyRow < gridSize - 1) possibleMoves.add([emptyRow + 1, emptyCol]);
      if (emptyCol > 0) possibleMoves.add([emptyRow, emptyCol - 1]);
      if (emptyCol < gridSize - 1) possibleMoves.add([emptyRow, emptyCol + 1]);

      var move = possibleMoves[Random().nextInt(possibleMoves.length)];
      int newRow = move[0];
      int newCol = move[1];

      setState(() {
        gridValues[emptyRow][emptyCol] = gridValues[newRow][newCol];
        gridValues[newRow][newCol] = null;
      });

      emptyRow = newRow;
      emptyCol = newCol;
    }
  }

  void showWinDialog() {
    // Start the scale animation
    _controller.forward().then((_) {
      // Show the dialog after the animation completes
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: AlertDialog(
              title: const Text(
                "Congratulations!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                "You won the game! 🎉",
                style: TextStyle(fontSize: 18),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss the dialog
                    shuffleGrid();
                    _controller.reverse(); // Reverse animation for next time
                  },
                  child: const Text(
                    "Play Again",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss the dialog
                    resetGame();
                    _controller.reverse(); // Reverse animation for next time
                  },
                  child: const Text(
                    "Home Page",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {
        _controller.reset();
        FocusScope.of(context).requestFocus(FocusNode());
      });
    });
  }

  void resetGame() {
    setState(() {
      shuffled = false;
      loadAndSplitImage(gridSize); // Load the initial grid again
    });
  }

  void handleCellTap(int row, int col) {
    if (paused) return;

    int emptyRow = -1;
    int emptyCol = -1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (gridValues[i][j] == null) {
          emptyRow = i;
          emptyCol = j;
          break;
        }
      }
      if (emptyRow != -1) break;
    }

    if ((row == emptyRow && (col == emptyCol - 1 || col == emptyCol + 1)) ||
        (col == emptyCol && (row == emptyRow - 1 || row == emptyRow + 1))) {
      setState(() {
        gridValues[emptyRow][emptyCol] = gridValues[row][col];
        gridValues[row][col] = null;
      });

      if (checkWin()) {
        print('You won!');
        timer?.cancel();
        showWinDialog(); // Show the win dialog
      }
    }
  }

  bool checkWin() {
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (gridValues[r][c] != winningGridValues[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  Widget buildGrid(List<List<ui.Image?>> grid) {
    return Padding(
      padding: const EdgeInsets.all(16.0), // Add padding around the grid
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridSize,
          crossAxisSpacing: 2.0, // Space between columns
          mainAxisSpacing: 2.0, // Space between rows
        ),
        itemCount: gridSize * gridSize,
        itemBuilder: (context, index) {
          int row = index ~/ gridSize;
          int col = index % gridSize;

          bool isCorrectPosition =
              grid[row][col] == winningGridValues[row][col];

          return GestureDetector(
            onTap: () {
              if (shuffled && !paused) {
                handleCellTap(row, col);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6),
                border: Border.all(
                  color: const Color(0xFF5E3A6F), // Dark border color
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(8), // Rounded corners
              ),
              child: grid[row][col] != null
                  ? ColorFiltered(
                      colorFilter: isCorrectPosition
                          ? ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply)
                          : const ColorFilter.mode(
                              Colors.black, BlendMode.saturation),
                      child: RawImage(
                        image: grid[row][col],
                        fit: BoxFit.cover,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
