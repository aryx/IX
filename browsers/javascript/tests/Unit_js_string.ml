(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/js/Unit_js_utf16.ml (its 8af888e), for strings as bytes since (Js_string) (docs/plans/plan_browser.md) *)

(* See Unit_js_string.mli *)

let run (s : string) : string =
  let t = Js_eval.create_with (fun _ -> ()) 1 (fun () -> 1_000_000_000_000.) in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

let tests =
  Testo.categorize "Js_string"
    [
      Testo.create "a string is its UTF-8 bytes: length, charCodeAt, an index" (fun () ->
          check "counted in bytes" {|["a".length, "é".length, "€".length, "😀".length, "aé".charCodeAt(1), "a".charCodeAt(5)]|} "[1, 2, 3, 4, 195, NaN]";
          check "searched and cut in bytes: a piece found is whole" {|var s = "日本語"; [s.indexOf("語"), s.slice(s.indexOf("本"), s.indexOf("語")), "a,é,b".split(","), "éaéa".lastIndexOf("a")]|} {|[6, "本", ["a", "é", "b"], 5]|});
      Testo.create "whole characters where a script asks for them" (fun () ->
          check "for-of, Array.from, a pattern's dot" {|[[..."é😀"].length, Array.from("é€").join("|"), /^.$/.test("é"), "é€x".match(/./g).length]|} {|[2, "é|€", true, 3]|};
          check "made and escaped" {|[String.fromCharCode(233) === "é", String.fromCodePoint(0x1F600) === "😀", JSON.parse('"\\u00e9"') === "é", encodeURIComponent("é")]|} {|[true, true, true, "%C3%A9"]|});
      Testo.create "case: ASCII's letters alone" (fun () ->
          check "upper and lower" {|["naïve café".toUpperCase(), "ÉCOLE".toLowerCase()]|} {|["NAïVE CAFé", "École"]|});
    ]
