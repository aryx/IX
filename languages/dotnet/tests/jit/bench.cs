// The JIT's speed against the interpreter's (mini-dotnet -jit and
// without): methods of int32s only, calls (Fib), loops with division
// (Collatz's steps), loops of logic (bits counted), each compiled
// whole by the JIT; Main, which prints, is the interpreter's.
using System;

class Bench {
    static int Fib(int n) { return n < 2 ? n : Fib(n - 1) + Fib(n - 2); }
    static int Steps(int n) { int s = 0; while (n != 1) { n = n % 2 == 0 ? n / 2 : 3 * n + 1; s++; } return s; }
    static int Longest(int max) {
        int best = 0, at = 0;
        for (int i = 1; i < max; i++) { int s = Steps(i); if (s > best) { best = s; at = i; } }
        return at;
    }
    static int Bits(int max) {
        int total = 0;
        for (int i = 0; i < max; i++) { int x = i; while (x != 0) { total += x & 1; x = (int)((uint)x >> 1); } }
        return total;
    }

    static void Main() {
        Console.WriteLine(Fib(27));
        Console.WriteLine(Longest(100000));
        Console.WriteLine(Bits(1000000));
    }
}
