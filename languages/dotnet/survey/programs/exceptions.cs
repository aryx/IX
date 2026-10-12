// Exceptions: thrown, caught by type, a finally, one of the machine's.
using System;

class Refused : Exception {
    public int Code;
    public Refused(string m, int code) : base(m) { Code = code; }
}

class Exceptions {
    static int Check(int x) {
        if (x < 0) throw new Refused("negative", x);
        return 100 / x;
    }

    static void Try(int x) {
        try {
            Console.WriteLine(Check(x));
        } catch (Refused r) {
            Console.WriteLine(r.Message + " " + r.Code);
        } catch (DivideByZeroException) {
            Console.WriteLine("by zero");
        } finally {
            Console.WriteLine("tried " + x);
        }
    }

    static void Main() {
        Try(5);
        Try(-1);
        Try(0);
        int[] a = new int[2];
        try {
            a[2] = 1;
        } catch (IndexOutOfRangeException) {
            Console.WriteLine("out of range");
        }
        string s = null;
        try {
            Console.WriteLine(s.Length);
        } catch (NullReferenceException) {
            Console.WriteLine("null");
        }
        object o = "text";
        try {
            Exceptions e = (Exceptions)o;
        } catch (InvalidCastException) {
            Console.WriteLine("bad cast");
        }
    }
}
