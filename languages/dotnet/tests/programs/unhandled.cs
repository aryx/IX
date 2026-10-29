// An exception no one catches: the runtime says it and stops; the
// finally blocks on its way are not run (the first pass found no catch).
using System;

class Unhandled {
    static void Deep(int n) {
        if (n == 0) throw new InvalidOperationException("nobody catches this");
        try { Deep(n - 1); } finally { Console.WriteLine("finally " + n + ": not printed"); }
    }

    static void Main() {
        Console.WriteLine("before");
        Deep(2);
        Console.WriteLine("after: not printed");
    }
}
