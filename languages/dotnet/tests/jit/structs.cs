// Structs in the JIT's code: a struct is a value, copied when assigned,
// passed, returned, read from a field or an array; changed in place
// through its address (a local's, a field's, an element's, a method's
// this); boxed and unboxed. A copy shared by mistake would show here.
using System;

struct Point {
    public int X, Y;
    public Point(int x, int y) { X = x; Y = y; }
    public void Move(int d) { X += d; Y += d; }
    public int Sum() { return X + Y; }
    public override string ToString() { return "(" + X + "," + Y + ")"; }
}

class Holder { public Point P; }

class Structs {
    static Point Twice(Point p) { p.X *= 2; p.Y *= 2; return p; }
    static void Shift(ref Point p) { p.Move(10); }
    static int Total(Point[] ps) { int t = 0; for (int i = 0; i < ps.Length; i++) t += ps[i].Sum(); return t; }

    static void Main() {
        Point a = new Point(1, 2);
        Point b = a;
        b.X = 100;
        Console.WriteLine(a + " " + b);
        Point c = Twice(a);
        Console.WriteLine(a + " " + c);
        Shift(ref a);
        Console.WriteLine(a);
        a.Move(1);
        Console.WriteLine(a.Sum());
        Holder h = new Holder();
        h.P = a;
        h.P.X = 0;
        Point d = h.P;
        d.Y = 0;
        Console.WriteLine(a + " " + h.P + " " + d);
        Point[] ps = new Point[3];
        for (int i = 0; i < ps.Length; i++) { ps[i].X = i; ps[i].Y = i * 10; }
        ps[1].Move(5);
        Point e = ps[2];
        e.X = 99;
        Console.WriteLine(Total(ps) + " " + ps[2] + " " + e);
        object o = a;
        a.X = -1;
        Point f = (Point)o;
        Console.WriteLine(o + " " + f + " " + a);
        Point g = default(Point);
        Console.WriteLine(g + " " + g.Sum());
        int n = 0;
        for (int i = 0; i < 10000; i++) { Point q = new Point(i, 1); q.Move(1); n += q.Y; }
        Console.WriteLine(n);
    }
}
