// Strings: the library's most used class, and what the compiler makes
// of an interpolation and of a switch.
using System;
using System.Text;

class Strings {
    static int Value(string roman) {
        switch (roman) {
            case "I": return 1;
            case "V": return 5;
            case "X": return 10;
            default: return 0;
        }
    }

    static void Main() {
        string s = "Hello";
        string t = s + ", " + "World";
        Console.WriteLine(t.Length);
        Console.WriteLine(t.Substring(7));
        Console.WriteLine(t.ToUpper());
        Console.WriteLine(t.IndexOf("World"));
        Console.WriteLine(t[4]);
        Console.WriteLine(s == "Hel" + "lo");
        int n = 42;
        Console.WriteLine($"n is {n} and s is {s}");
        Console.WriteLine(Value("V") + Value("X"));
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 5; i++) sb.Append(i).Append(' ');
        Console.WriteLine(sb.ToString());
        Console.WriteLine(int.Parse("123") + 1);
    }
}
