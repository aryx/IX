// Classes: fields, constructors, a virtual method, an interface.
using System;

interface INamed {
    string Name();
}

abstract class Shape : INamed {
    protected int x, y;
    static int count;
    protected Shape(int x, int y) { this.x = x; this.y = y; count++; }
    public abstract int Area();
    public virtual string Name() { return "shape"; }
    public static int Count { get { return count; } }
    public override string ToString() { return Name() + " of area " + Area(); }
}

class Square : Shape {
    int side;
    public Square(int x, int y, int side) : base(x, y) { this.side = side; }
    public override int Area() { return side * side; }
    public override string Name() { return "square"; }
}

class Rect : Shape {
    int w, h;
    public Rect(int x, int y, int w, int h) : base(x, y) { this.w = w; this.h = h; }
    public override int Area() { return w * h; }
}

class Shapes {
    static void Main() {
        Shape[] all = new Shape[] { new Square(0, 0, 3), new Rect(1, 1, 2, 5) };
        int total = 0;
        for (int i = 0; i < all.Length; i++) {
            Console.WriteLine(all[i]);
            total += all[i].Area();
        }
        INamed n = all[1];
        Console.WriteLine(n.Name());
        Console.WriteLine(all[0] is Square);
        Console.WriteLine(Shape.Count);
        Console.WriteLine(total);
    }
}
