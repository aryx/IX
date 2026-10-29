// Methods of int32s only, every one of the JIT's templates in one of
// them: Main prints their results by the interpreter (and Microsoft's
// runtime, ints.expected); ints.c calls the same methods as the JIT
// compiles them, and prints the same lines.
using System;

class Ints {
    static int Gcd(int a, int b) { while (b != 0) { int t = a % b; a = b; b = t; } return a; }
    static int Pow(int b, int e) { int r = 1; for (int i = 0; i < e; i++) r *= b; return r; }
    static int Bits(int x) { int n = 0; while (x != 0) { n += x & 1; x = (int)((uint)x >> 1); } return n; }
    static int Mix(int a, int b, int c, int d) { return (a << 3) - (b >> 1) + (c ^ d) - (~a | b) + (-c); }
    static int Day(int d) {
        switch (d) { case 0: return 10; case 1: return 11; case 2: return 12; case 3: return 13; default: return -1; }
    }
    static bool Below(uint a, uint b) { return a < b; }
    static int Unsigned(int a, int b) { return (int)((uint)a / (uint)b) + (int)((uint)a % (uint)b); }
    static int Narrow(int x) { return (sbyte)x + (byte)x + (short)x + (char)x; }
    static int Clamp(int x, int lo, int hi) { if (x < lo) x = lo; if (x > hi) x = hi; return x; }
    static int Collatz(int n) { int steps = 0; while (n != 1) { n = n % 2 == 0 ? n / 2 : 3 * n + 1; steps++; } return steps; }
    static int Ack(int m, int n) { return m == 0 ? n + 1 : n == 0 ? Ack(m - 1, 1) : Ack(m - 1, Ack(m, n - 1)); }

    static void Main() {
        Console.WriteLine(Gcd(1071, 462));
        Console.WriteLine(Pow(3, 13));
        Console.WriteLine(Bits(-1) + " " + Bits(255));
        Console.WriteLine(Mix(7, -9, 12, 5));
        Console.WriteLine(Day(2) + " " + Day(7));
        Console.WriteLine(Below(1, 3000000000) + " " + Below(3000000000, 1));
        Console.WriteLine(Unsigned(-7, 3));
        Console.WriteLine(Narrow(0x1ff80) + " " + Narrow(-1));
        Console.WriteLine(Clamp(-5, 0, 9) + " " + Clamp(50, 0, 9) + " " + Clamp(4, 0, 9));
        Console.WriteLine(Collatz(27));
        Console.WriteLine(Ack(2, 3));
    }
}
