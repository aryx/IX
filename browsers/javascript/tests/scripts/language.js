// the language, a line of output each: run by mini-node, compared with
// language.expected (scripts.sh), which is what Node says too. Only
// what the engine has (README.md lists what it has not: in, delete,
// switch, do, finally, the bitwise operators...)
function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
console.log("fib", fib(15));

// closures, and a counter each its own
function counter() { var n = 0; return function () { n = n + 1; return n; }; }
var a = counter(), b = counter();
a(); a();
console.log("closures", a(), b());

// let, const, arrows, default of an absent argument
const twice = f => x => f(f(x));
let inc = x => x + 1;
console.log("arrows", twice(inc)(5), twice(twice(inc))(0));

// objects and prototypes
function Point(x, y) { this.x = x; this.y = y; }
Point.prototype.norm2 = function () { return this.x * this.x + this.y * this.y; };
var p = new Point(3, 4);
console.log("prototype", p.norm2(), p instanceof Point, typeof p, typeof Point, typeof undefined, typeof null);
var o = { a: 1, "b c": 2, f: function () { return this.a; } };
o.d = o.f() + 1;
o.a = undefined;
var keys = [];
keys = Object.keys(o);
console.log("object", keys.join(","), o.a === undefined, o.d, o["b c"]);

// arrays
var xs = [5, 3, 8, 1];
console.log("array", xs.length, xs.slice(1, 3).join(" "), xs.indexOf(8), xs.concat([9]).length);
console.log("higher", xs.map(function (x) { return x * 2; }).join(" "), xs.filter(function (x) { return x > 2; }).join(" "),
  xs.reduce(function (s, x) { return s + x; }, 0));
xs.sort(function (a, b) { return a - b; });
xs.push(13); xs.unshift(0);
console.log("sorted", xs.join(" "), xs.pop(), xs.shift(), xs.reverse().join(" "));

// strings
var s = "Hello, World";
console.log("string", s.length, s.toUpperCase(), s.indexOf("World"), s.charAt(4), s.substring(7), s.split(", ").join("|"), s.slice(-5));
console.log("concat", 1 + "2", "3" * "4", 1 + 2 + "3", "a" < "b", "10" == 10, "10" === 10, null == undefined, null === undefined);

// numbers
console.log("number", 0.1 + 0.2, 1 / 3, 7 % 3, -7 % 3, 5 / 2, Math.floor(-2.5), Math.round(2.5), Math.max(1, 9, 4), Math.abs(-3));
console.log("parse", parseInt("42px"), parseInt("ff", 16), parseFloat("3.25"), isNaN(parseInt("x")), (0.5).toFixed(2), 1e21, 255);

// control
var out = [];
for (var i = 0; i < 10; i++) { if (i % 2) continue; if (i > 6) break; out.push(i); }
var n = 0; while (n < 3) n++;
for (var x of ["a", "b"]) out.push(x);
if (n === 3) out.push("three"); else out.push("not three");
console.log("control", out.join(" "), n);

// exceptions
function risky(x) { if (x > 1) throw new Error("too big: " + x); return x; }
try { risky(1); risky(2); console.log("not reached"); }
catch (e) { console.log("caught", e.message, e.name); }
try { undefinedFunction(); } catch (e) { console.log("reference", e.name); }
try { null.x; } catch (e) { console.log("type", e.name); }

// regular expressions
console.log("regexp", /a+b/.test("caab"), "2026-10-09".replace(/(\d+)-(\d+)-(\d+)/, "$3/$2/$1"), "a1b22c".replace(/\d+/g, "#"),
  "one two  three".split(/\s+/).length, ("key = value".match(/(\w+)\s*=\s*(\w+)/) || [])[2]);

// JSON
var j = JSON.stringify({ n: 1, s: "x\"y", l: [true, null, 1.5], o: { k: [] } });
console.log("json", j);
