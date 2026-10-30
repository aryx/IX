// A division by zero in a method the JIT compiles: its code calls the
// runtime, which throws DivideByZeroException, caught by Main, which
// the interpreter runs (its try).
using System;

class Zero {
    static int Quot(int a, int b) { return a / b; }
    static int Twice(int a, int b) { return Quot(a, b) + Quot(a, b); }

    static void Main() {
        Console.WriteLine(Twice(7, 2));
        try { Console.WriteLine(Twice(7, 0)); }
        catch (DivideByZeroException e) { Console.WriteLine("caught: " + e.Message); }
        Console.WriteLine(Quot(9, 3));
    }
}
