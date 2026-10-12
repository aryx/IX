// Generics kept at run time: a class and a method of a type parameter.
using System;

class Stack<T> {
    T[] items = new T[4];
    int n;
    public void Push(T x) {
        if (n == items.Length) {
            T[] bigger = new T[2 * n];
            for (int i = 0; i < n; i++) bigger[i] = items[i];
            items = bigger;
        }
        items[n++] = x;
    }
    public T Pop() { return items[--n]; }
    public bool Empty { get { return n == 0; } }
    public string What() { return "a stack of " + typeof(T).Name; }
}

class Pair<A, B> {
    public A First; public B Second;
    public Pair(A a, B b) { First = a; Second = b; }
}

class Generic {
    static void Swap<T>(ref T a, ref T b) { T t = a; a = b; b = t; }
    static Pair<B, A> Flip<A, B>(Pair<A, B> p) { return new Pair<B, A>(p.Second, p.First); }

    static void Main() {
        Stack<int> si = new Stack<int>();
        Stack<string> ss = new Stack<string>();
        for (int i = 0; i < 10; i++) si.Push(i * i);
        ss.Push("a"); ss.Push("b");
        Console.WriteLine(si.What());
        Console.WriteLine(ss.What());
        int sum = 0;
        while (!si.Empty) sum += si.Pop();
        Console.WriteLine(sum);
        string x = "left", y = "right";
        Swap(ref x, ref y);
        Console.WriteLine(x + " " + ss.Pop());
        Pair<string, int> q = Flip(new Pair<int, string>(1, "one"));
        Console.WriteLine(q.First + " " + q.Second);
        object o = si;
        Console.WriteLine(o is Stack<int>);
        Console.WriteLine(o is Stack<string>);   // false: not erased
    }
}
