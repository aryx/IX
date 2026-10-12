// Static methods and int32 only: a recursion, a loop, a branch.
using System;

class Fib {
    static int Rec(int n) {
        if (n < 2) return n;
        return Rec(n - 1) + Rec(n - 2);
    }

    static int Loop(int n) {
        int a = 0, b = 1;
        for (int i = 0; i < n; i++) {
            int t = a + b;
            a = b;
            b = t;
        }
        return a;
    }

    static void Main() {
        Console.WriteLine(Rec(20));
        Console.WriteLine(Loop(40));
        Console.WriteLine(Loop(47));   // past int32: wraps
    }
}
