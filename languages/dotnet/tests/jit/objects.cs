// References in the JIT's code: objects, their fields, arrays, strings,
// virtual calls and the library's, made in loops that allocate, so
// that mini-ml's collector moves them many times while the code holds
// them (on mini-ml's value stack). A null and an index out of range
// in compiled code, caught by Main, which the interpreter runs (its
// try).
using System;

class Node {
    public int Value;
    public Node Next;
    public Node(int v, Node n) { Value = v; Next = n; }
}

abstract class Shape { public abstract int Area(); }
class Rect : Shape {
    int w, h;
    public Rect(int w, int h) { this.w = w; this.h = h; }
    public override int Area() { return w * h; }
}
class Square : Shape {
    int s;
    public Square(int s) { this.s = s; }
    public override int Area() { return s * s; }
}

class Objects {
    static int counter;

    static Node Build(int n) {
        Node head = null;
        for (int i = 0; i < n; i++) head = new Node(i, head);
        return head;
    }
    static int Sum(Node l) { int s = 0; while (l != null) { s += l.Value; l = l.Next; } return s; }
    static int Length(Node l) { int n = 0; for (; l != null; l = l.Next) n++; return n; }
    static int First(Node l) { return l.Value; }

    static Shape[] Shapes(int n) {
        Shape[] a = new Shape[n];
        for (int i = 0; i < n; i++) a[i] = i % 2 == 0 ? new Rect(i, 2) : new Square(i % 7);
        return a;
    }
    static int Areas(Shape[] shapes) {
        int t = 0;
        for (int i = 0; i < shapes.Length; i++) t += shapes[i].Area();
        return t;
    }

    static int[] Squares(int n) { int[] a = new int[n]; for (int i = 0; i < n; i++) a[i] = i * i; return a; }
    static int At(int[] a, int i) { return a[i]; }
    static byte[] Bytes(int n) { byte[] b = new byte[n]; for (int i = 0; i < n; i++) b[i] = (byte)(i * 7); return b; }
    static int Total(byte[] b) { int t = 0; for (int i = 0; i < b.Length; i++) t += b[i]; return t; }

    static string Join(string[] words) {
        string s = "";
        for (int i = 0; i < words.Length; i++) { if (i > 0) s += ","; s += words[i]; }
        return s;
    }
    static string Repeat(string s, int n) { string r = ""; for (int i = 0; i < n; i++) r = r + s; return r; }
    static int Vowels(string s) {
        int n = 0;
        for (int i = 0; i < s.Length; i++) { char c = s[i]; if (c == 'a' || c == 'e' || c == 'o') n++; }
        return n;
    }

    static bool Same(object a, object b) { return a == b; }
    static int Count() { counter++; return counter; }

    static void Main() {
        Node l = Build(300000);
        Console.WriteLine(Length(l));
        Console.WriteLine(Sum(l));
        Console.WriteLine(Areas(Shapes(30000)));
        int[] sq = Squares(1000);
        Console.WriteLine(At(sq, 999) + At(sq, 10));
        Console.WriteLine(Total(Bytes(30000)));
        Console.WriteLine(Join(new string[] { "alpha", "beta", "gamma" }));
        Console.WriteLine(Repeat("ab", 2000).Length);
        Console.WriteLine(Vowels(Repeat("hello world, ", 100)));
        Node a = new Node(1, null);
        Console.WriteLine(Same(a, a));
        Console.WriteLine(Same(a, new Node(1, null)));
        Console.WriteLine(Same(null, null));
        Console.WriteLine(Same(a, null));
        for (int i = 0; i < 5; i++) Count();
        Console.WriteLine(counter);
        try { Console.WriteLine(First(null)); }
        catch (NullReferenceException) { Console.WriteLine("caught: null"); }
        try { Console.WriteLine(At(sq, 1000)); }
        catch (IndexOutOfRangeException e) { Console.WriteLine("caught: " + e.Message); }
    }
}
