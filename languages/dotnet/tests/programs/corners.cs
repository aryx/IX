// mini-dotnet's corners, those the survey's ten do not reach: each
// line printed checked against Microsoft's runtime (corners.expected).
using System;
using System.Collections.Generic;

interface IShape { int Area(); string Kind(); }
interface IOther { string Kind(); }

class Box : IShape, IOther {
    int side;
    public Box(int s) { side = s; }
    public int Area() { return side * side; }
    public string Kind() { return "box"; }
    string IOther.Kind() { return "other box"; }   // explicit: a MethodImpl
}

struct Point { public int X, Y; public string Name; }

class Holder {
    public Point P;                       // a struct inside an object
    public static int Made;
    static Holder() { Console.WriteLine("Holder's static constructor"); }
    public Holder() { Made++; }
}

class Base { public virtual string Who() { return "base"; } }
class Middle : Base { public override string Who() { return "middle"; } }
class Hidden : Middle { public new virtual string Who() { return "hidden"; } }

class Corners {
    static int Depth(int n) {
        try {
            try {
                if (n == 0) throw new InvalidOperationException("bottom");
                return Depth(n - 1) + 1;
            } finally {
                Console.WriteLine("inner finally " + n);
            }
        } catch (InvalidOperationException e) when (n == 2) {
            Console.WriteLine("filtered at 2: " + e.Message);
            return -100;
        }
    }

    static void Rethrow() {
        try {
            try { throw new ArgumentException("first"); }
            catch (ArgumentException) { Console.WriteLine("caught, rethrown"); throw; }
        } catch (Exception e) { Console.WriteLine("outer: " + e.Message); }
    }

    static string Roman(string s) {
        switch (s) {
            case "one": return "I"; case "two": return "II"; case "three": return "III";
            case "four": return "IV"; case "five": return "V"; case "six": return "VI";
            case "seven": return "VII"; case "eight": return "VIII";
            default: return "?";
        }
    }

    static string Day(int d) {
        switch (d) {
            case 0: return "sun"; case 1: return "mon"; case 2: return "tue";
            case 3: return "wed"; default: return "later";
        }
    }

    static void Main() {
        Box b = new Box(4);
        IShape s = b; IOther o = b;
        Console.WriteLine(s.Area() + " " + s.Kind() + " " + o.Kind());
        Base h = new Hidden();
        Console.WriteLine(h.Who() + " " + ((Hidden)h).Who());

        Console.WriteLine("before Holder");
        Holder ho = new Holder();
        ho.P.X = 3; ho.P.Name = "p";
        Point q = ho.P; q.X = 9;
        Console.WriteLine(ho.P.X + " " + q.X + " " + ho.P.Name + " " + Holder.Made);

        Console.WriteLine(Roman("seven") + Roman("two") + Roman("nine"));
        Console.WriteLine(Day(2) + " " + Day(9));

        long big = long.MaxValue;
        Console.WriteLine(big + " " + (big + 1) + " " + (int)big);
        uint u = 4000000000;
        Console.WriteLine(u + " " + (u / 3) + " " + (u > 5));
        Console.WriteLine((-7 / 2) + " " + (-7 % 2) + " " + (-7 >> 1) + " " + (unchecked((uint)-7) >> 28));
        Console.WriteLine(0.1 + 0.2);
        Console.WriteLine(1e20 + " " + 1.5e-7 + " " + (1.0 / 3) + " " + 100.0 + " " + -0.5);
        Console.WriteLine((double)int.MaxValue * 2 + " " + (int)3.99 + " " + (int)-3.99);
        try { checked { int x = int.MaxValue; x = x + 1; Console.WriteLine(x); } }
        catch (OverflowException) { Console.WriteLine("overflow"); }
        char c = 'A'; c++;
        Console.WriteLine(c + " " + (int)c + " " + (char)(c + 1));

        Console.WriteLine(Depth(3));
        Rethrow();

        var d = new Dictionary<int, string>();
        for (int i = 0; i < 20; i++) d[i * 7 % 13] = "v" + i;
        Console.WriteLine(d.Count + " " + d[6] + " " + d.ContainsKey(13));
        try { Console.WriteLine(d[99]); }
        catch (KeyNotFoundException e) { Console.WriteLine(e.Message); }

        object[] objs = { 1, "two", 3.5, 'c', true, null, new Box(1) };
        foreach (object x in objs) Console.Write((x == null ? "null" : x.ToString()) + ";");
        Console.WriteLine();
        Console.WriteLine(int.Parse(" -42 ") * 2);
        try { int.Parse("4x2"); } catch (FormatException) { Console.WriteLine("format"); }

        int[] arr = { 5, 3, 8 };
        int sum = 0;
        foreach (int x in arr) sum += x;
        Console.WriteLine(sum + " " + arr.Length);
    }
}
