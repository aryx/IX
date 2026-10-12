// The library's collections, and foreach over them.
using System;
using System.Collections.Generic;

class Collections {
    static void Main() {
        List<int> primes = new List<int>();
        for (int n = 2; n < 50; n++) {
            bool prime = true;
            foreach (int p in primes)
                if (n % p == 0) { prime = false; break; }
            if (prime) primes.Add(n);
        }
        Console.WriteLine(primes.Count);
        Console.WriteLine(primes[primes.Count - 1]);

        Dictionary<string, int> ages = new Dictionary<string, int>();
        ages["ada"] = 36;
        ages["alan"] = 41;
        ages["ada"] = ages["ada"] + 1;
        int v;
        if (ages.TryGetValue("alan", out v)) Console.WriteLine(v);
        Console.WriteLine(ages.ContainsKey("grace"));
        Console.WriteLine(ages["ada"]);

        string[] words = { "one", "two", "three" };
        int letters = 0;
        foreach (string w in words) letters += w.Length;
        Console.WriteLine(letters);
    }
}
