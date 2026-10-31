// C# using an ML unit compiled by mini-ml -dotnet (shapes.ml): its
// record a class whose constructor takes the fields, its variant an
// abstract class with a class a case, its functions static methods;
// an ML int a long, an ML string a string. Equals is ML's =.
using System;

static class Interop {
    static void Main() {
        var p = new Shapes.point(1, 2);
        var q = Shapes.translate(p, 10, 20);
        Console.WriteLine("translated: " + q.x + ", " + q.y);
        Shapes.shape s = new Shapes.shape.Rect(p, q);
        Console.WriteLine(Shapes.describe(s) + " of area " + Shapes.area(s));
        Console.WriteLine("a circle's area: " + Shapes.area(new Shapes.shape.Circle(p, 2)));
        Console.WriteLine("ML's = from C#: " + new Shapes.point(1, 2).Equals(p) + " " + p.Equals(q));
        switch (s) {
            case Shapes.shape.Rect r: Console.WriteLine("C#'s switch on an ML variant: a Rect to " + r.Item2.x); break;
            case Shapes.shape.Circle c: Console.WriteLine("a Circle"); break;
        }
    }
}
