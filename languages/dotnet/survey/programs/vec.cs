// Value types: a struct is copied, passed by reference, boxed.
using System;

struct Vec {
    public int X, Y;
    public Vec(int x, int y) { X = x; Y = y; }
    public static Vec operator +(Vec a, Vec b) { return new Vec(a.X + b.X, a.Y + b.Y); }
    public override string ToString() { return "(" + X + "," + Y + ")"; }
}

class VecMain {
    static void Double(ref Vec v) { v.X *= 2; v.Y *= 2; }
    static void Halve(Vec v) { v.X /= 2; v.Y /= 2; }

    static void Main() {
        Vec a = new Vec(1, 2);
        Vec b = a;              // a copy
        b.X = 10;
        Console.WriteLine(a);
        Console.WriteLine(a + b);
        Double(ref a);
        Halve(a);               // changes its own copy
        Console.WriteLine(a);
        object o = a;           // boxed: a copy on the heap
        a.X = 0;
        Console.WriteLine(o);
        Vec c = (Vec)o;         // unboxed
        Console.WriteLine(c.X);
        Vec[] vs = new Vec[3];  // three structs inline, no pointer
        vs[1].Y = 7;
        Console.WriteLine(vs[1]);
        long big = 1L << 40;
        double d = 1.5 * c.X;
        Console.WriteLine(big);
        Console.WriteLine(d);
    }
}
