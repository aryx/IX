function f(n) { return n <= 1 ? 1 : n * f(n-1) }
function g(a, b,   loc) { loc = a + b; return loc }
function fill(arr, n,   i) { for (i = 1; i <= n; i++) arr[i] = i*i }
function sum(arr,   k, s) { for (k in arr) s += arr[k]; return s }
function chg(s, a) { s = "changed"; a["k"] = "v" }
function noret() { x = 1 }
function early(n) { if (n) return "yes"; return }
function mk(a) { a[1] = 5 }
function field(a) { return $a }
func short(x) { return x x }
function fib(n) { return n < 2 ? n : fib(n-1) + fib(n-2) }
function loop(n,   i) { for (i = 0; i < 10; i++) if (i == n) return i; return -1 }
function strnum(v) { return v }
BEGIN {
	print f(10), g(1, 2), loc ""
	fill(sq, 5); print sum(sq), length(sq)
	x = "orig"; chg(x, arr); print x, arr["k"]
	print noret() "|" early(1) "|" early(0) "|"
	mk(u); print u[1]
	print short("ab"), fib(20), loop(4), loop(40), g(1)
	$0 = "p q"; print field(2)
	r = strnum("10"); print (r < 9); r = strnum(10); print (r < 9)
}
