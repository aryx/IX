// Delegates: a method as a value, a lambda and what it captures.
using System;

delegate int Binary(int a, int b);

class Closures {
    static int Add(int a, int b) { return a + b; }

    static Func<int> Counter() {
        int n = 0;
        return () => ++n;       // n lives on after Counter returns
    }

    static int Twice(Func<int, int> f, int x) { return f(f(x)); }

    static void Main() {
        Binary op = Add;
        Console.WriteLine(op(2, 3));
        op = (a, b) => a * b;
        Console.WriteLine(op(2, 3));
        Func<int> c1 = Counter(), c2 = Counter();
        c1(); c1();
        Console.WriteLine(c1() + c2());
        int k = 10;
        Console.WriteLine(Twice(x => x + k, 1));
        Action<string> say = Console.WriteLine;
        say("done");
    }
}
