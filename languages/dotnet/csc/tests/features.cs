// mini-csc's own test: what the survey's seven programs reach only in
// part. Microsoft's csc compiles it too, and what its assembly prints
// under Microsoft's runtime is features.expected.
using System;
using System.Collections.Generic;

interface IAnimal { string Sound(); int Legs(); }

abstract class Animal : IAnimal {
    protected string name;
    static int made;
    static string kingdom = "animals";
    public Animal(string n) { name = n; made = made + 1; }
    public abstract string Sound();
    public virtual int Legs() { return 4; }
    public string Describe() { return name + " says " + Sound() + " on " + Legs() + " legs"; }
    public static int Made { get { return made; } }
    public static string Kingdom { get { return kingdom; } }
}

class Dog : Animal {
    public Dog(string n) : base(n) { }
    public override string Sound() { return "woof"; }
}

class Bird : Animal {
    int wings = 2;
    public Bird() : this("bird") { }
    public Bird(string n) : base(n) { }
    public override string Sound() { return "tweet"; }
    public override int Legs() { return base.Legs() - wings; }
}

class Counter {
    int n;
    public int Next() { n += 1; return n; }
    public override string ToString() { return "Counter at " + n; }
}

class Features {
    static int Divide(int a, int b) {
        try {
            return a / b;
        } catch (DivideByZeroException) {
            return -1;
        } finally {
            Console.WriteLine("divided " + a + " by " + b);
        }
    }

    static bool Find(List<string> l, string s, out int at) {
        at = -1;
        for (int i = 0; i < l.Count; i++) {
            if (l[i] == s) { at = i; return true; }
        }
        return false;
    }

    static void Main() {
        Animal[] zoo = { new Dog("rex"), new Bird() };
        foreach (Animal a in zoo) Console.WriteLine(a.Describe());
        IAnimal first = zoo[0];
        Console.WriteLine(first.Legs() + " " + Animal.Made + " " + Animal.Kingdom);
        Console.WriteLine(zoo[1] is Dog);
        Console.WriteLine(zoo[1] is Bird ? "a bird" : "not a bird");

        int sum = 0;
        for (int i = 0; i < 100; i++) {
            if (i % 3 == 0) continue;
            if (i > 50) break;
            sum += i;
        }
        Console.WriteLine(sum);
        int k = 10;
        do { k -= 3; } while (k > 0);
        Console.WriteLine(k);
        int j = 5;
        int pre = ++j, post = j++;
        Console.WriteLine(pre + " " + post + " " + j);
        j *= 4; j /= 3; j %= 5;
        Console.WriteLine(j);

        long big = 1000000L * 1000000;
        double half = 7 / 2.0;
        char c = 'a';
        c++;
        Console.WriteLine(big + " " + half + " " + c + " " + (int)c + " " + (char)(c + 1));
        Console.WriteLine((int)3.75 + " " + (long)k + " " + (double)3);
        object boxed = 41;
        int back = (int)boxed + 1;
        Console.WriteLine(back + " " + boxed);

        Console.WriteLine(Divide(7, 2));
        Console.WriteLine(Divide(7, 0));

        List<string> names = new List<string>();
        names.Add("ada"); names.Add("alan"); names.Add("grace");
        int at;
        if (Find(names, "alan", out at)) Console.WriteLine("alan at " + at);
        Console.WriteLine(Find(names, "linus", out at) + " " + at);

        Dictionary<string, int> counts = new Dictionary<string, int>();
        string[] words = { "a", "b", "a", "c", "a" };
        foreach (string w in words) {
            if (counts.ContainsKey(w)) counts[w] += 1;
            else counts[w] = 1;
        }
        Console.WriteLine(counts["a"] + " " + counts["c"]);

        Counter ct = new Counter();
        ct.Next(); ct.Next();
        Console.WriteLine(ct);
        string s = null;
        Console.WriteLine(s == null && !(ct == null));
        try {
            throw new InvalidOperationException("no");
        } catch (ArgumentException) {
            Console.WriteLine("not here");
        } catch (Exception e) {
            Console.WriteLine("caught " + e.Message);
        }
    }
}
