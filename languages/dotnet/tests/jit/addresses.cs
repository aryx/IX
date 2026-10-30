// Addresses in the JIT's code: a local's (ldloca: ref x, out x, an
// int's x.ToString()), an argument's, a field's (ldflda), a static
// field's (ldsflda), an element's (ldelema), a ref parameter used by
// the method compiled (ldind, stind), and a delegate's method (ldftn).
// A local's address is nothing at run time: the call-out that takes it
// is given the local's value and gives back its new one.
using System;

class Box { public int x; }

class Addresses {
    static int counter;

    static void Inc(ref int x) { x++; }
    static bool TryHalf(int n, out int half) { half = n / 2; return n % 2 == 0; }
    static void Swap<T>(ref T a, ref T b) { T t = a; a = b; b = t; }
    static int Sum(Func<int, int> f, int n) { int s = 0; for (int i = 0; i < n; i++) s += f(i); return s; }
    static int Twice(int a) { Inc(ref a); Inc(ref a); return a; }

    static void Main() {
        int a = 1;
        Inc(ref a); Inc(ref a);
        Console.WriteLine(a);
        int h;
        bool even = TryHalf(7, out h);
        Console.WriteLine(even + " " + h);
        string x = "x", y = "y";
        Swap(ref x, ref y);
        Console.WriteLine(x + y);
        Box b = new Box();
        Inc(ref b.x); Inc(ref b.x);
        Console.WriteLine(b.x);
        Inc(ref counter);
        Console.WriteLine(counter);
        int[] arr = { 5 };
        Inc(ref arr[0]);
        Console.WriteLine(arr[0]);
        Console.WriteLine(a.ToString() + "/" + h.ToString());
        int big = 2000000000;
        Inc(ref big);
        Console.WriteLine(big);
        Console.WriteLine(Twice(40));
        Console.WriteLine(Sum(i => i * i, 10));
    }
}
