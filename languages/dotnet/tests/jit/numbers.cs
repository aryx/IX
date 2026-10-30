// int64s and doubles in the JIT's code: their values the interpreter's
// (I8, R8), their arithmetic, conversions and comparisons call-outs,
// a branch on them the interpreter's test; checked arithmetic (an
// int32's too) and its OverflowException; fields and arrays of them.
using System;

class Acc { public long Total; public double Mean; }

class Numbers {
    static long Fact(int n) { long r = 1; for (int i = 2; i <= n; i++) r *= i; return r; }
    static double Sqrt(double x) { double g = x / 2; for (int i = 0; i < 30; i++) g = (g + x / g) / 2; return g; }
    static int Checked(int a, int b) { return checked(a + b); }
    static long Max(long[] xs) { long m = long.MinValue; foreach (long x in xs) if (x > m) m = x; return m; }
    static int Sign(double d) { if (d < 0) return -1; if (d > 0) return 1; return 0; }

    static void Main() {
        Console.WriteLine(Fact(20));
        Console.WriteLine(Fact(21));
        Console.WriteLine(Sqrt(2.0));
        Console.WriteLine((int)Sqrt(1000000.0));
        long big = 3000000000L;
        int small = (int)big;
        Console.WriteLine(big + " " + small + " " + (big > int.MaxValue) + " " + (big / 7) + " " + (big % 7));
        Console.WriteLine(Max(new long[] { 5, -9, 1L << 40, 12 }));
        Console.WriteLine(Sign(-0.5) + " " + Sign(0.0) + " " + Sign(1e-300));
        double d = 7;
        d /= 2;
        Console.WriteLine(d + " " + (long)d + " " + (d == 3.5) + " " + (uint)4000000000L);
        try { Console.WriteLine(Checked(int.MaxValue, 1)); }
        catch (OverflowException) { Console.WriteLine("overflow"); }
        Acc a = new Acc();
        double[] ds = { 1.5, 2.5, 3.0 };
        for (int i = 0; i < ds.Length; i++) { a.Total += (long)(ds[i] * 2); a.Mean += ds[i] / ds.Length; }
        Console.WriteLine(a.Total + " " + a.Mean);
        long s = 0;
        for (int i = 0; i < 100000; i++) s += i * (long)i;
        Console.WriteLine(s);
    }
}
