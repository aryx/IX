// what the first engine had not: classes, destructuring, templates, async and await, generators, switch, in, finally, JSON.parse, bitwise operators
class A { constructor(x) { this.x = x } get twice() { return this.x * 2 } static of(x) { return new A(x) } }
const { x, ...rest } = { x: 1, y: 2, z: 3 };
const m = new Map([["a", 1]]); const s = new Set([1, 2, 2]);
console.log(`${A.of(21).twice} ${x} ${JSON.stringify(rest)} ${m.get("a")} ${s.size}`);
switch (x) { case 1: console.log("one"); break; default: console.log("other") }
async function f() { const v = await Promise.resolve(7); console.log("awaited " + v); return v + 1 }
f().then(v => console.log("then " + v));
function* g() { yield 1; yield 2 }
console.log([...g()].join(","), 5 & 3, 2 ** 10, "in" in { in: 1 }, typeof Symbol.iterator);
console.log(JSON.parse('{"a":[1,2,{"b":null}]}').a[2].b, "aXbXc".split("X").map(c => c.toUpperCase()).join("-"), /(\d+)-(\d+)/.exec("10-20")[2]);
try { null.x } catch (e) { console.log(e.name, e.message.length > 0) } finally { console.log("finally") }
label: for (var i = 0; i < 3; i++) { for (var j = 0; j < 3; j++) { if (j == 1) continue label; if (i == 2) break label; console.log(i, j) } }
var o = { a: 1, b: 2 }; delete o.a; var ks = []; for (var k in o) ks.push(k); do { ks.push("x") } while (ks.length < 3); console.log(ks.join(), void 0, 7 >>> 1, ~5, (1, 2));
