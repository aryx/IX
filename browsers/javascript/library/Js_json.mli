(* Js_json: JSON.parse -- a text read into values.

   JSON is the notation of JavaScript's own literals, cut down to what
   every language can read: objects, arrays, strings in double quotes,
   numbers, true, false, null -- and nothing else (no undefined, no
   function, no comment, no comma after the last item).

   cs-history:
   Douglas Crockford named it and wrote it down in 2001 (json.org; RFC
   4627 in 2006), observing that he had not invented it but found it:
   pages were already sending such text to each other and reading it
   with eval. That was the danger -- eval runs whatever it is given --
   and why his json2.js (2007), then the language itself (JSON.parse
   and JSON.stringify, ES5, 2009), got a reader that only reads. It
   replaced XML as what an XMLHttpRequest brings back, though the XML
   stayed in the name.

     JSON.parse('{"a": [1, 2.5e1, "x\\n"], "b": null}')
       // { a: [1, 25, "x\n"], b: null }
     JSON.parse("{a: 1}")      // SyntaxError: a key needs its quotes
     JSON.parse("[1, 2,]")     // SyntaxError: nothing after the last comma

   The grammar is small enough to be read by one function per kind of
   value, each calling the others (recursive descent), with no tokens
   between: a value is told by its first character.

   JSON.stringify, the other way, is Js_value.to_json. JSON.parse's
   second argument (a function to revive each value) is not read.

   Reference: ECMA-404, "The JSON Data Interchange Syntax" (2013), four
   pages; RFC 8259 (2017); ECMA-262 section 25.5. Crockford, "JSON: The
   Fat-Free Alternative to XML" (2006). *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_json.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the value a JSON text stands for; Js_value.Throw of a SyntaxError
 * saying where the text stops being JSON *)
val parse : string -> Js_value.value
