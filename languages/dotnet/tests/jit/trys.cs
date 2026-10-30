// try, catch and finally in the JIT's code: a try's handler is a
// record on ML's chain of handlers, its frame seen by the first pass;
// caught by its class or a base class, a finally run when leaving
// normally and when an exception passes, a leave through two finally
// blocks, a try entered many times in a loop, rethrow, exceptions
// thrown by compiled code, by the library, and by a callee compiled.
using System;

class Trys {
    static string log = "";

    static int Div(int a, int b) { return a / b; }

    static int Safe(int a, int b) {
        try { return Div(a, b); }
        catch (DivideByZeroException) { return -1; }
    }

    static int Base(string s) {
        try { return int.Parse(s); }
        catch (SystemException e) { log += "[" + e.GetType().Name + "]"; return 0; }
    }

    static void Finally(int b) {
        try { log += "t"; Div(1, b); log += "x"; }
        finally { log += "f"; }
    }

    static int Nested(int b) {
        int r = 0;
        try {
            try { r = Div(10, b); }
            finally { log += "1"; }
        }
        finally { log += "2"; }
        return r;
    }

    static int Loop(int n) {
        int caught = 0;
        for (int i = 0; i < n; i++) {
            try { if (i % 3 == 0) throw new InvalidOperationException("i=" + i); }
            catch (InvalidOperationException) { caught++; }
        }
        return caught;
    }

    static void Again() {
        try { Div(1, 0); }
        catch (DivideByZeroException) { log += "a"; throw; }
    }

    static int Outer() {
        try { Again(); return 0; }
        catch (ArithmeticException e) { log += "o"; return e.Message.Length; }
    }

    static int Null(object o) {
        try { return o.GetHashCode() & 0; }
        catch (NullReferenceException) { return 7; }
    }

    static void Main() {
        Console.WriteLine(Safe(7, 2) + " " + Safe(7, 0));
        Console.WriteLine(Base("12") + Base("x") + " " + log);
        log = "";
        Finally(1);
        try { Finally(0); } catch (DivideByZeroException) { log += "c"; }
        Console.WriteLine(log);
        log = "";
        Console.WriteLine(Nested(5));
        try { Nested(0); } catch (DivideByZeroException) { log += "c"; }
        Console.WriteLine(log);
        Console.WriteLine(Loop(100000));
        log = "";
        Console.WriteLine(Outer() + " " + log);
        Console.WriteLine(Null(null));
    }
}
