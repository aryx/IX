(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/js/Unit_js_utf16.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_utf16.mli *)

let run (s : string) : string =
  let t = Js_eval.create_with (fun _ -> ()) 1 (fun () -> 1_000_000_000_000.) in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

let tests =
  Testo.categorize "Js_utf16"
    [
      Testo.create "the module's table: bytes here, units there" (fun () ->
          let row s = (String.length s, Js_utf16.length s, List.init (Js_utf16.length s) (Js_utf16.unit s)) in
          Alcotest.(check (triple int int (list int))) "a letter" (1, 1, [ 97 ]) (row "a");
          Alcotest.(check (triple int int (list int))) "an accent" (2, 1, [ 233 ]) (row "é");
          Alcotest.(check (triple int int (list int))) "the Arabic zero" (2, 1, [ 1632 ]) (row "٠");
          Alcotest.(check (triple int int (list int))) "the euro" (3, 1, [ 8364 ]) (row "€");
          Alcotest.(check (triple int int (list int))) "an emoji: a pair of halves" (4, 2, [ 55357; 56832 ]) (row "😀");
          Alcotest.(check (list int)) "a unit's byte, a pair's second half after it" [ 0; 1; 5; 5; 6 ] (List.init 5 (Js_utf16.byte_of "a😀b"));
          Alcotest.(check (list int)) "and back" [ 0; 1; 3; 4 ] (List.map (Js_utf16.unit_of "a😀b") [ 0; 1; 5; 6 ]);
          Alcotest.(check bool) "ASCII is its own table" true (Js_utf16.ascii "plain" && not (Js_utf16.ascii "plaïn"));
          Alcotest.(check int) "a byte that starts no character is a unit of its own" 3 (Js_utf16.length "a\xff\x80"));
      Testo.create "halves: cut apart, and met again" (fun () ->
          let e = "a😀b" in
          Alcotest.(check string) "the pair whole" "😀" (Js_utf16.sub e 1 3);
          Alcotest.(check (list int)) "cut in two: its first half kept, three bytes" [ 97; 55357 ] (List.init 2 (Js_utf16.unit (Js_utf16.sub e 0 2)));
          Alcotest.(check string) "the two halves made the character again" e (Js_utf16.seam (Js_utf16.sub e 0 2) (Js_utf16.sub e 2 4));
          Alcotest.(check string) "units made a string" "é😀" (Js_utf16.of_units [ 233; 0xD83D; 0xDE00 ]);
          Alcotest.(check string) "two escapes side by side" "x😀" (Js_utf16.joined ("x" ^ Js_utf16.of_code_point 0xD83D ^ Js_utf16.of_code_point 0xDE00));
          Alcotest.(check (list int)) "its characters" [ 97; 0x1F600; 98 ] (Js_utf16.code_points e));
      Testo.create "a string counted and read: length, charCodeAt, an index" (fun () ->
          (* Gmail's table of zeros (CharMatcher.digit()): charCodeAt of each, checked to be in order *)
          check "the zeros of five scripts, in order" {|var z = "0٠۰߀०", c = []; for (var i = 0; i < z.length; i++) c.push(z.charCodeAt(i)); [z.length, c]|} "[5, [48, 1632, 1776, 1984, 2406]]";
          check "a text written as itself" {|var t = "0٠۰߀०𝟎x"; [t.length, t.charCodeAt(5), t.charCodeAt(6), t.charCodeAt(7), t.charCodeAt(9)]|} "[8, 55349, 57294, 120, NaN]";
          check "an emoji: two units, one code point" {|var e = "a😀b"; [e.length, e.charCodeAt(1), e.charCodeAt(2), e.codePointAt(1), e[0], e[3], e.charAt(3)]|} {|[4, 55357, 56832, 128512, "a", "b", "b"]|};
          check "an accent is one" {|["é€".length, "é".charCodeAt(0), String.fromCharCode(233) === "é", "naïve café".toUpperCase()]|} {|[2, 233, true, "NAÏVE CAFÉ"]|};
          check "a long one (a rope)" {|var big = ""; for (var i = 0; i < 3000; i++) big += "é"; [big.length, big.charCodeAt(2999), (big + "😀").length]|} "[3000, 233, 3002]");
      Testo.create "cut and searched" (fun () ->
          check "slice, substring, substr" {|var e = "a😀b"; [e.slice(1, 3) === "😀", e.substring(3), e.substr(-1), e.slice(-1), e.slice(0, 2).length, e.slice(0, 2) + e.slice(2) === e]|} {|[true, "b", "b", "b", 2, true]|};
          check "indexOf and its from, lastIndexOf" {|["a😀b".indexOf("b"), "日本語".indexOf("語"), "éaéa".indexOf("a", 2), "éaéa".lastIndexOf("a"), "x".indexOf("é")]|} "[3, 2, 3, 3, -1]";
          check "split, by nothing and with a limit; padStart; at" {|["é😀".split("").length, "aXbXc".split("X", 2), "é€😀".padStart(6, "é").length, "日本語".at(-1)]|} {|[3, ["a", "b"], 6, "語"]|};
          check "its characters, a pair as one" {|[[..."é😀"].length, Array.from("é€").join("|"), [..."é😀"].map(c => c.codePointAt(0))]|} {|[2, "é|€", [233, 128512]]|});
      Testo.create "made: fromCharCode, escapes, JSON" (fun () ->
          check "two halves are their character, however they meet"
            {|["😀" === "😀", String.fromCharCode(0xd83d, 0xde00) === "😀", String.fromCharCode(0xd83d) + String.fromCharCode(0xde00) === "😀", String.fromCodePoint(0x1F600) === "😀", "\ud83d".length]|}
            "[true, true, true, true, 1]";
          check "JSON's escapes; escape and unescape, a byte a character" {|[JSON.parse('"\\ud83d\\ude00"') === "😀", escape("é€"), unescape("%E9%u20AC") === "é€", encodeURIComponent("é😀")]|}
            {|[true, "%E9%u20AC", true, "%C3%A9%F0%9F%98%80"]|});
      Testo.create "a regular expression: characters, and indices in units" (fun () ->
          check "an index, lastIndex, a replacement's offset" {|var re = /\d/g, at = [], m; while ((m = re.exec("é1é22"))) at.push(m.index + ":" + re.lastIndex); [/b/.exec("a😀b").index, "a😀b".search(/b/), "a😀b".replace(/b/, (m, o) => "[" + o + "]"), at]|}
            {|[3, 3, "a😀[3]", ["1:2", "3:4", "4:5"]]|};
          check "a set is of characters: a range of them, one written as itself, a negation" {|[/^[٠-٩]+$/.test("٠١٢"), /[éà]/.test("à"), /[^\x00-\x7f]/.exec("abcé").index, "é€x".replace(/[^a-z]/g, "_"), /[一-鿿]{2}/.exec("x日本語")[0]]|}
            {|[true, true, 3, "__x", "日本"]|};
          check "what is repeated is the character, not its last byte; the dot takes one" {|[/é+/.exec("ééé")[0].length, /^.$/.test("é"), "é€x".match(/./g).length, "a b".split(/\s/).length]|} "[3, true, 3, 2]");
      Testo.create "case and order beyond ASCII" (fun () ->
          check "accented Latin, Greek, Cyrillic" {|["École".toLowerCase(), "straße à Zürich".toUpperCase(), "ΑΘΉΝΑ".toLowerCase(), "Москва".toUpperCase()]|} {|["école", "STRAßE À ZÜRICH", "αθήνα", "МОСКВА"]|};
          check "a dictionary's order: an accent counts last" {|["z", "é", "e", "a"].sort((a, b) => a.localeCompare(b)).join("")|} "aeéz");
    ]
