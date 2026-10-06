(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Latin1.mli *)

(* latin1.h's table, as it is there: what must be typed first (one
 * character or two), then for each last character typed (the second
 * string's) the character made (the third's, at the same place). A
 * row whose start begins another's comes after it. *)
let table = [
  " ", " i", "␣ı";
  "!~", "-=~", "≄≇≉";
  "!", "!<=>?bmp", "¡≮≠≯‽⊄∉⊅";
  "\"*", "IUiu", "ΪΫϊϋ";
  "\"", "\"AEIOUYaeiouy", "¨ÄËÏÖÜŸäëïöüÿ";
  "$*", "fhk", "ϕϑϰ";
  "$", "BEFHILMRVaefglopv", "ℬℰℱℋℐℒℳℛƲɑℯƒℊℓℴ℘ʋ";
  "'\"", "Uu", "Ǘǘ";
  "'", "'ACEILNORSUYZacegilnorsuyz", "´ÁĆÉÍĹŃÓŔŚÚÝŹáćéģíĺńóŕśúýź";
  "*", "*ABCDEFGHIKLMNOPQRSTUWXYZabcdefghiklmnopqrstuwxyz", "∗ΑΒΞΔΕΦΓΘΙΚΛΜΝΟΠΨΡΣΤΥΩΧΗΖαβξδεφγθικλμνοπψρστυωχηζ";
  "+", "-O", "±⊕";
  ",", ",ACEGIKLNORSTUacegiklnorstu", "¸ĄÇĘĢĮĶĻŅǪŖŞŢŲąçęģįķļņǫŗşţų";
  "-*", "l", "ƛ";
  "-", "+-2:>DGHILOTZbdghiltuz~", "∓­ƻ÷→ÐǤĦƗŁ⊖ŦƵƀðǥℏɨłŧʉƶ≂";
  ".", ".CEGILOZceglz", "·ĊĖĠİĿ⊙Żċėġŀż";
  "/", "Oo", "Øø";
  "1", ".234568", "․½⅓¼⅕⅙⅛";
  "2", "-.35", "ƻ‥⅔⅖";
  "3", ".458", "…¾⅗⅜";
  "4", "5", "⅘";
  "5", "68", "⅚⅝";
  "7", "8", "⅞";
  ":", "()-=", "☹☺÷≔";
  "<!", "=~", "≨⋦";
  "<", "-<=>~", "←«≤≶≲";
  "=", ":<=>OV", "≕⋜≡⋝⊜⇒";
  ">!", "=~", "≩⋧";
  ">", "<=>~", "≷≥»≳";
  "?", "!?", "‽¿";
  "@'", "'", "ъ";
  "@@", "'EKSTYZekstyz", "ьЕКСТЫЗекстыз";
  "@C", "Hh", "ЧЧ";
  "@E", "Hh", "ЭЭ";
  "@K", "Hh", "ХХ";
  "@S", "CHch", "ЩШЩШ";
  "@T", "Ss", "ЦЦ";
  "@Y", "AEOUaeou", "ЯЕЁЮЯЕЁЮ";
  "@Z", "Hh", "ЖЖ";
  "@c", "h", "ч";
  "@e", "h", "э";
  "@k", "h", "х";
  "@s", "ch", "щш";
  "@t", "s", "ц";
  "@y", "aeou", "яеёю";
  "@z", "h", "ж";
  "@", "ABDFGIJLMNOPRUVXabdfgijlmnopruvx", "АБДФГИЙЛМНОПРУВХабдфгийлмнопрувх";
  "A", "E", "Æ";
  "C", "ACU", "⋂ℂ⋃";
  "Dv", "Zz", "Ǆǅ";
  "D", "-e", "Ð∆";
  "G", "-", "Ǥ";
  "H", "-H", "Ħℍ";
  "I", "-J", "ƗĲ";
  "L", "&-Jj|", "⋀ŁǇǈ⋁";
  "M", "#48bs", "♮♩♪♭♯";
  "N", "JNj", "Ǌℕǋ";
  "O", "*+-./=EIcoprx", "⊛⊕⊖⊙⊘⊜ŒƢ©⊚℗®⊗";
  "P", "P", "ℙ";
  "Q", "Q", "ℚ";
  "R", "R", "ℝ";
  "S", "123S", "¹²³§";
  "T", "-u", "Ŧ⊨";
  "V", "=", "⇐";
  "Y", "R", "Ʀ";
  "Z", "-ACSZ", "Ƶℤ";
  "^", "ACEGHIJOSUWYaceghijosuwy", "ÂĈÊĜĤÎĴÔŜÛŴŶâĉêĝĥîĵôŝûŵŷ";
  "_\"", "AUau", "ǞǕǟǖ";
  "_,", "Oo", "Ǭǭ";
  "_.", "Aa", "Ǡǡ";
  "_", "AEIOU_aeiou", "ĀĒĪŌŪ¯āēīōū";
  "`\"", "Uu", "Ǜǜ";
  "`", "AEIOUaeiou", "ÀÈÌÒÙàèìòù";
  "a", "ben", "↔æ∠";
  "b", "()+-0123456789=bknpqru", "₍₎₊₋₀₁₂₃₄₅₆₇₈₉₌♝♚♞♟♛♜•";
  "c", "$Oagu", "¢©∩≅∪";
  "dv", "z", "ǆ";
  "d", "-adegz", "ð↓‡°†ʣ";
  "e", "$lmns", "€⋯—–∅";
  "f", "a", "∀";
  "g", "$-r", "¤ǥ∇";
  "h", "-v", "ℏƕ";
  "i", "-bfjps", "ɨ⊆∞ĳ⊇∫";
  "l", "\"$&'-jz|", "“£∧‘łǉ⋄∨";
  "m", "iou", "µ∈×";
  "n", "jo", "ǌ¬";
  "o", "AOUaeiu", "Å⊚Ůåœƣů";
  "p", "Odgrt", "℗∂¶∏∝";
  "r", "\"'O", "”’®";
  "s", "()+-0123456789=abnoprstu", "⁽⁾⁺⁻⁰ⁱ⁲⁳⁴⁵⁶⁷⁸⁹⁼ª⊂ⁿº⊃√ß∍∑";
  "t", "-efmsu", "ŧ∃∴™ς⊢";
  "u", "-AEGIOUaegiou", "ʉĂĔĞĬŎŬ↑ĕğĭŏŭ";
  "v\"", "Uu", "Ǚǚ";
  "v", "ACDEGIKLNORSTUZacdegijklnorstuz", "ǍČĎĚǦǏǨĽŇǑŘŠŤǓŽǎčďěǧǐǰǩľňǒřšťǔž";
  "w", "bknpqr", "♗♔♘♙♕♖";
  "x", "O", "⊗";
  "y", "$", "¥";
  "z", "-", "ƶ";
  "|", "Pp|", "Þþ¦";
  "~!", "=", "≆";
  "~", "-=AINOUainou~", "≃≅ÃĨÑÕŨãĩñõũ≈";
]

(* a string's characters (UTF-8), by their numbers *)
let runes s =
  let rec go o =
    if o >= String.length s then []
    else begin
      let b = Char.code s.[o] in
      let n = if b < 0x80 then 1 else if b < 0xe0 then 2 else if b < 0xf0 then 3 else 4 in
      let r = ref (if n = 1 then b else b land (0xff lsr (n + 1))) in
      for i = 1 to n - 1 do r := (!r lsl 6) lor (Char.code s.[o + i] land 0x3f) done;
      !r :: go (o + n)
    end in
  go 0

(* the number written by hexadecimal digits (latin1.c's unicode), -1 when one is not *)
let unicode digits =
  List.fold_left (fun c r ->
    let d = if r >= 0x30 && r <= 0x39 then r - 0x30 else if r >= 0x61 && r <= 0x66 then r - 0x61 + 10
      else if r >= 0x41 && r <= 0x46 then r - 0x41 + 10 else -1 in
    if c < 0 || d < 0 then -1 else (c * 16) + d) 0 digits

let rec take n = function x :: more when n > 0 -> x :: take (n - 1) more | _ -> []

let latin1 k =
  let n = List.length k in
  match k with
  | [] -> -1
  (* X and 4 digits, x and 8: a character by its number *)
  | 0x58 :: digits -> if n >= 5 then unicode (take 4 digits) else -5
  | 0x78 :: digits -> if n >= 9 then unicode (take 8 digits) else -9
  | k0 :: rest ->
      let rec find = function
        | [] -> -1
        | (ld, si, so) :: more when Char.code ld.[0] = k0 ->
            (* the last key chooses among the row's characters *)
            let choose c =
              let rec at i = function
                | [] -> -1
                | r :: more -> if i < String.length si && Char.code si.[i] = c then r else at (i + 1) more in
              at 0 (runes so) in
            if n = 1 then -2
            else if String.length ld = 1 then choose (List.nth rest 0)
            else if Char.code ld.[1] <> List.nth rest 0 then find more
            else if n = 2 then -3
            else choose (List.nth rest 1)
        | _ :: more -> find more in
      find table
