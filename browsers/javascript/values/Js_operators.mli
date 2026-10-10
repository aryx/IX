(* Js_operators: what the operators do to two values -- the
   arithmetic and its coercions, the comparisons, the bits.

   (notes_javascript.md section 7.) JavaScript's operators take any
   values and convert them as they need:

     +            adds two numbers, but joins if either side (as a
                  primitive) is a string: 1 + "2" is "12"
     - * / % **   both sides made numbers: "3" * "4" is 12
     < > <= >=    two strings compared as strings, else as numbers; a
                  NaN on either side: false
     === !==      the same kind and the same value (Js_value.strict_equal)
     == !=        [loose_equal]: null and undefined equal each other and
                  nothing else; a number and a string compared as
                  numbers; a boolean made a number; an object its
                  primitive
     & | ^ << >>  both sides cut to 32-bit integers ([to_int32]: the
                  integer part modulo 2^32), the answer one too; a
                  shift's count is its low five bits
     >>>          the same, the left side taken without a sign: the
                  answer is never negative

   The bits are why "x | 0" and "~~x" are the idioms for "x as an
   integer", and why 1 << 31 is negative.

   evolution:
   The 32 bits had a second life. Since "x | 0" is the one way to say
   "an integer" in a language of floats, a compiler could write it as
   a type: Emscripten (Alon Zakai, 2010) compiled C to JavaScript full
   of such marks, asm.js (Mozilla, 2013) made the marks a subset an
   engine could compile ahead of time to plain machine arithmetic, and
   games written in C++ ran in a page at half their native speed. That
   subset, given a binary format of its own, is WebAssembly (2017).

   Not here: && || ?? (they do not always evaluate their right side:
   Js_eval's), typeof, in, instanceof (properties: Js_props).

   Reference: ECMA-262 5.1, sections 11.5 to 11.10 (the operators),
   11.9.3 (the abstract equality comparison), 9.5 (ToInt32). *)
(* ix: the author's mini-chrome's languages/javascript/values/Js_operators.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a == b *)
val loose_equal : Js_value.value -> Js_value.value -> bool

(* a number as the 32 bits the bitwise operators work on, and back *)
val to_int32 : Js_value.value -> int32
val of_int32 : int32 -> Js_value.value

(* [arithmetic op a b]: a op b, for the operators above *)
val arithmetic : string -> Js_value.value -> Js_value.value -> Js_value.value

(* the same with no shortcut for two numbers: the definition (what
 * [arithmetic] is with Mini_opti off, and what compiled code falls
 * back on: Js_compile) *)
val arithmetic_simple : string -> Js_value.value -> Js_value.value -> Js_value.value
