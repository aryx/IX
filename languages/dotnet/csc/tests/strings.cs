// The survey's strings.cs as mini-csc takes it (plan_dotnet.md,
// decision 11): its interpolation a concatenation, its switch on
// strings ifs. It prints what survey/programs/strings.expected says.
using System;
using System.Text;

class Strings {
    static int Value(string roman) {
        if (roman == "I") return 1;
        if (roman == "V") return 5;
        if (roman == "X") return 10;
        return 0;
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
        Console.WriteLine("n is " + n + " and s is " + s);
        Console.WriteLine(Value("V") + Value("X"));
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 5; i++) sb.Append(i).Append(' ');
        Console.WriteLine(sb.ToString());
        Console.WriteLine(int.Parse("123") + 1);
    }
}
