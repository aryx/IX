// errors and their prototypes: an error made by new, one the engine
// throws, a class over Error; checked against Node
var e = new TypeError("x");
console.log(e instanceof TypeError, e instanceof Error, Object.getPrototypeOf(e) === TypeError.prototype);
console.log(Object.getPrototypeOf(e) === Error.prototype, Object.getPrototypeOf(e) === Object.prototype, Object.getPrototypeOf(e) === null);
try { null.x } catch (t) { console.log(t instanceof TypeError, t instanceof Error, t.name, t.message, String(t)); }
try { undefinedName } catch (t) { console.log(t instanceof ReferenceError, t instanceof Error, t.name); }
class MyError extends Error { constructor(m) { super(m); this.name = "MyError"; } }
var m = new MyError("boom");
console.log(m instanceof MyError, m instanceof Error, m.message, m.name, String(m));
console.log(Error("plain") instanceof Error, new RangeError("r").name, new Error("a").toString(), typeof new Error("s").stack);
console.log(e.constructor === TypeError, TypeError.prototype.name, Error.prototype.name);
var c = new Error("with cause", { cause: e }); console.log(c.cause === e);
console.log(Object.getPrototypeOf(TypeError.prototype) === Error.prototype, new EvalError("v") instanceof Error, new URIError("u").name);
try { JSON.parse("{") } catch (t) { console.log(t instanceof SyntaxError, t.name); }
try { new Array(-1) } catch (t) { console.log(t instanceof RangeError, t.name); }
