// Wirth's eight queens: arrays, a recursion, 92 solutions.
using System;

class Queens {
    static bool[] row = new bool[8];
    static bool[] up = new bool[15];
    static bool[] down = new bool[15];
    static int[] at = new int[8];
    static int solutions;

    static void Place(int col) {
        for (int r = 0; r < 8; r++) {
            if (!row[r] && !up[r + col] && !down[r - col + 7]) {
                at[col] = r;
                row[r] = up[r + col] = down[r - col + 7] = true;
                if (col == 7) {
                    solutions++;
                    if (solutions == 1) {
                        for (int i = 0; i < 8; i++) Console.Write(at[i] + 1);
                        Console.WriteLine();
                    }
                } else {
                    Place(col + 1);
                }
                row[r] = up[r + col] = down[r - col + 7] = false;
            }
        }
    }

    static void Main() {
        Place(0);
        Console.WriteLine(solutions + " solutions");
    }
}
