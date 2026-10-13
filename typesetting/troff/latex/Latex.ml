(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex.mli *)

(* ---------------------------------------------------------------- *)
(* The state *)
(* ---------------------------------------------------------------- *)

(* What is being read: a file, a macro's text put in its place, an
 * argument read apart ([stop]: the reading ends with it). *)
type frame = { s : string; mutable i : int; stop : bool; file : string; mutable line : int; counts : bool }

type macro = { args : int; default : string option; body : string }

(* what a group gives back at its end *)
type look = { style : Doc.style; caps : bool; center : bool }

(* what is being made: the blocks, the last first, and the paragraph
 * being filled, its last piece first, with its footnotes *)
type out = { mutable blocks : Doc.block list; mutable line : Doc.inline list; mutable feet : Doc.block list }

type env = {
  name : string;
  (* where its blocks go at its end, when it gathers them *)
  outer : out option;
  saved : look;
  (* a list: an item was begun, its tag, how many there were *)
  mutable started : bool;
  mutable tag : Doc.inline list;
  mutable count : int;
  mutable caption : Doc.inline list option;
  (* a defined one: the text of its end, to be read before it ends *)
  mutable after : string option;
}

(* What the first reading learns for the second: a reference is before
 * what it names, a table of contents before the chapters. *)
type known = {
  labels : (string, string) Hashtbl.t;
  (* a heading's level, its number, its title as written *)
  mutable toc : (int * string * string) list;
  (* a chunk's name: the chunks that define it, and those that use it *)
  defs : (string, int list) Hashtbl.t;
  uses : (string, int list) Hashtbl.t;
  (* the keys cited, the last first *)
  mutable cites : string list;
  bibitems : (string, string) Hashtbl.t;
}

type t = {
  paper : bool;
  load : string -> string option;
  known : known;
  (* the second reading: what is said is said, the tables are read *)
  final : bool;
  mutable input : frame list;
  mutable out : out;
  mutable look : look;
  mutable groups : look list;
  mutable envs : env list;
  macros : (string, macro) Hashtbl.t;
  flags : (string, bool) Hashtbl.t;
  environments : (string, macro * string) Hashtbl.t;
  (* the environments whose text is as it is written *)
  verbatims : (string, bool) Hashtbl.t;
  (* \begin{document} was read: text is the document's *)
  mutable body : bool;
  mutable said : (int * string) list;
  unknown : (string, bool) Hashtbl.t;
  (* a report: it has chapters *)
  report : bool;
  mutable appendix : bool;
  mutable chapter : int;
  mutable section : int;
  mutable subsection : int;
  mutable subsubsection : int;
  mutable figure : int;
  mutable table : int;
  mutable notes : int;
  mutable chunk : int;
  (* what a \label here names *)
  mutable here : string;
  mutable title : string;
  mutable author : string;
  mutable date : string;
  (* a table's cell being read: how many columns it goes across *)
  mutable span : int;
  mutable cell_align : Doc.align option;
}

let fresh () : out = { blocks = []; line = []; feet = [] }

let mono_of (style : Doc.style) : Doc.style = { style with font = Doc.Mono }

(* the document's lengths are in ens, a source's in a terminal's
 * columns, ten to the inch: 1.44 ens of a text of 10 points *)
let cols (t : t) (n : float) : float = if t.paper then n *. 1.44 else n
let gap (t : t) : float = if t.paper then 0.3 else 1.

(* where the reading is: the file's frame nearest the top *)
let place (t : t) : string * int =
  let rec find (l : frame list) : string * int = match l with [] -> ("", 0) | f :: rest -> if f.counts then (f.file, f.line) else find rest in
  find t.input

let say (t : t) (what : string) =
  if t.final then begin
    let file, line = place t in
    t.said <- (line, (if file = "" then "" else file ^ ": ") ^ what) :: t.said
  end

(* (once: a book has the same command a thousand times) *)
let say_once (t : t) (what : string) =
  if not (Hashtbl.mem t.unknown what) then begin Hashtbl.replace t.unknown what true; say t what end

(* ---------------------------------------------------------------- *)
(* The input *)
(* ---------------------------------------------------------------- *)

let push (t : t) (s : string) = if s <> "" then t.input <- { s; i = 0; stop = false; file = ""; line = 1; counts = false } :: t.input

let rec peek (t : t) : char option =
  match t.input with
  | [] -> None
  | f :: rest -> if f.i < String.length f.s then Some f.s.[f.i] else if f.stop then None else begin t.input <- rest; peek t end

let advance (t : t) =
  match t.input with
  | f :: _ -> if f.i < String.length f.s then begin (if f.s.[f.i] = '\n' then f.line <- f.line + 1); f.i <- f.i + 1 end
  | [] -> ()

(* the character k after the next, in the same text *)
let ahead (t : t) (k : int) : char option =
  match t.input with f :: _ -> if f.i + k < String.length f.s then Some f.s.[f.i + k] else None | [] -> None

let looking (t : t) (what : string) : bool =
  match t.input with
  | f :: _ -> let n = String.length what in f.i + n <= String.length f.s && String.sub f.s f.i n = what
  | [] -> false

let skip (t : t) (n : int) = for _k = 1 to n do advance t done

let at_line_start (t : t) : bool = match t.input with f :: _ -> f.counts && (f.i = 0 || f.s.[f.i - 1] = '\n') | [] -> false

(* the rest of the line, and past its end *)
let rest_of_line (t : t) : string =
  match peek t, t.input with
  | Some _, f :: _ ->
      let e = match String.index_from_opt f.s f.i '\n' with Some e -> e | None -> String.length f.s in
      let l = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + 1);
      l
  | _ -> ""

let is_letter (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
let is_digit (c : char) : bool = c >= '0' && c <= '9'
let is_blank (c : char) : bool = c = ' ' || c = '\t' || c = '\n' || c = '\r'

let rec blanks (t : t) = match peek t with Some c when is_blank c -> advance t; blanks t | _ -> ()

(* the spaces after a command's name are not text: to the next line's
 * first letter, but not past a blank line, which ends a paragraph *)
let after_name (t : t) =
  let rec spaces () = match peek t with Some (' ' | '\t') -> advance t; spaces () | _ -> () in
  spaces ();
  if peek t = Some '\n' && ahead t 1 <> Some '\n' then begin
    let rec blank_next (k : int) : bool = match ahead t k with Some (' ' | '\t') -> blank_next (k + 1) | Some '\n' | None -> true | Some _ -> false in
    if not (blank_next 1) then begin advance t; spaces () end
  end

(* s.[from] is after a [[: where the code quoted ends, past its ]] (on
 * the same line: a [[ that is not noweb's is left alone) *)
let quoted (s : string) (from : int) : int =
  let n = String.length s in
  let rec go (j : int) : int =
    if j + 1 >= n || s.[j] = '\n' then from
    else if s.[j] = ']' && s.[j + 1] = ']' then (let rec more (k : int) : int = if k < n && s.[k] = ']' then more (k + 1) else k in more (j + 2))
    else go (j + 1) in
  go from

(* s.[from] is after an opening: where the closing [c] is; a comment,
 * a quoted code and what follows a backslash are not looked at *)
let closing (s : string) (from : int) (o : char) (c : char) : int =
  let n = String.length s in
  let rec go (j : int) (depth : int) : int =
    if j >= n then n
    else if s.[j] = '\\' then go (j + 2) depth
    else if s.[j] = '[' && j + 1 < n && s.[j + 1] = '[' then go (quoted s (j + 2)) depth
    else if s.[j] = '%' then (match String.index_from_opt s j '\n' with Some e -> go (e + 1) depth | None -> n)
    else if s.[j] = c && depth = 0 then j
    else if s.[j] = '{' then go (j + 1) (depth + 1)
    else if s.[j] = '}' then go (j + 1) (depth - 1)
    else if s.[j] = o then go (j + 1) (depth + 1)
    else if s.[j] = c then go (j + 1) (depth - 1)
    else go (j + 1) depth in
  go from 0

(* what is between the next character, an opening, and its closing *)
let between (t : t) (o : char) (c : char) : string =
  match t.input with
  | f :: _ ->
      let e = closing f.s (f.i + 1) o c in
      let inner = String.sub f.s (f.i + 1) (min e (String.length f.s) - f.i - 1) in
      skip t (e - f.i + 1);
      inner
  | [] -> ""

(* a command's name, the backslash read: letters, or one character *)
let name (t : t) : string =
  match t.input with
  | f :: _ ->
      let n = String.length f.s in
      let rec letters (j : int) : int = if j < n && (is_letter f.s.[j] || f.s.[j] = '@') then letters (j + 1) else j in
      let e = letters f.i in
      let e = if e = f.i then min n (f.i + 1) else e in
      let w = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i);
      w
  | [] -> ""

(* an argument as it is written: what is between braces, or a command,
 * or a character *)
let arg (t : t) : string =
  blanks t;
  match peek t with
  | Some '{' -> between t '{' '}'
  | Some '\\' -> advance t; "\\" ^ name t
  | Some c ->
      let n = if Char.code c < 0x80 then 1 else if Char.code c < 0xe0 then 2 else if Char.code c < 0xf0 then 3 else 4 in
      let b = Buffer.create 4 in
      for _k = 1 to n do (match peek t with Some c -> Buffer.add_char b c; advance t | None -> ()) done;
      Buffer.contents b
  | None -> ""

(* an argument that may not be there: [text] (not [[code]], which is
 * noweb's, nor [<name>]) *)
let opt (t : t) : string option =
  let rec first (k : int) : int = match ahead t k with Some (' ' | '\t') -> first (k + 1) | _ -> k in
  match peek t with
  | None -> None
  | Some _ ->
      let k = first 0 in
      if ahead t k = Some '[' && ahead t (k + 1) <> Some '[' && ahead t (k + 1) <> Some '<' then begin blanks t; Some (between t '[' ']') end else None

let star (t : t) : bool = if peek t = Some '*' then begin advance t; true end else false

(* ---------------------------------------------------------------- *)
(* The output *)
(* ---------------------------------------------------------------- *)

let text (t : t) (s : string) =
  if s <> "" && t.body then begin
    let style = if t.look.caps then { t.look.style with size = t.look.style.size - 2 } else t.look.style in
    let s = if t.look.caps then String.uppercase_ascii s else s in
    match t.out.line with
    | Doc.Text (st, p) :: rest when st = style -> t.out.line <- Doc.Text (st, p ^ s) :: rest
    | _ -> t.out.line <- Doc.Text (style, s) :: t.out.line
  end

let put (t : t) (i : Doc.inline) = if t.body then t.out.line <- i :: t.out.line

(* a space, unless the line is at its start or has one *)
let space (t : t) =
  match t.out.line with
  | [] | Doc.Break :: _ -> ()
  | Doc.Text (_, p) :: _ when p <> "" && p.[String.length p - 1] = ' ' -> ()
  | _ -> text t " "

let emit (t : t) (b : Doc.block) = if t.body then t.out.blocks <- b :: t.out.blocks

(* a block after a blank, when it is not the first *)
let block (t : t) (b : Doc.block) =
  if t.body then begin
    (match t.out.blocks with [] | Doc.Space _ :: _ | Doc.Heading _ :: _ -> () | _ -> emit t (Doc.Space (gap t)));
    emit t b
  end

let blank_line (l : Doc.inline list) : bool =
  List.for_all (fun (i : Doc.inline) -> match i with Doc.Text (_, s) -> String.trim s = "" | Doc.Break -> true) l

(* the paragraph being filled is ended *)
let par (t : t) =
  let l = match t.out.line with Doc.Text (st, p) :: rest when p <> "" && p.[String.length p - 1] = ' ' -> Doc.Text (st, String.sub p 0 (String.length p - 1)) :: rest | l -> l in
  t.out.line <- [];
  if not (blank_line l) then begin
    let p : Doc.par = { fill = true; first = 0.; short = 0.; tabs = []; center = t.look.center; body = List.rev l } in
    block t (Doc.Para p)
  end;
  t.out.blocks <- t.out.feet @ t.out.blocks;
  t.out.feet <- []

(* lines as they are, in the typed font: a display, a chunk *)
let lines_as_they_are (t : t) (size : int) (lines : Doc.inline list list) : Doc.block =
  let body = List.concat (List.mapi (fun k l -> if k > 0 then Doc.Break :: l else l) lines) in
  let stop = (if t.paper then 9.6 else 8.) *. float_of_int (10 + (if t.paper then size else 0)) /. 10. in
  let p : Doc.par = { fill = false; first = 0.; short = 0.; tabs = List.init 20 (fun k -> stop *. float_of_int (k + 1)); center = false; body } in
  Doc.Para p

let words (l : Doc.inline list) : string =
  String.concat "" (List.map (fun (i : Doc.inline) -> match i with Doc.Text (_, s) -> Doc.letters s | Doc.Break -> " ") l)

(* ---------------------------------------------------------------- *)
(* What a command's name is not enough to say *)
(* ---------------------------------------------------------------- *)

let sizes = [ ("tiny", -4); ("scriptsize", -3); ("footnotesize", -2); ("small", -1); ("normalsize", 0); ("large", 2); ("Large", 3); ("LARGE", 4); ("huge", 6); ("Huge", 8) ]

(* a command with a text is the declaration in a group: \emph{x} is {\em x} *)
let with_text = [ ("emph", "em"); ("textit", "it"); ("textbf", "bf"); ("texttt", "tt"); ("textsc", "sc"); ("textrm", "rm"); ("textsf", "rm"); ("textsl", "it"); ("textup", "rm"); ("textnormal", "rm"); ("mathit", "it"); ("mathrm", "rm"); ("mathbf", "bf"); ("mathtt", "tt"); ("text", "rm") ]

(* the commands that are a character, or a few *)
let symbols = [
  ("ldots", "\xe2\x80\xa6"); ("dots", "\xe2\x80\xa6"); ("cdots", "\xe2\x80\xa6"); ("LaTeX", "LaTeX"); ("TeX", "TeX"); ("copyright", "\xc2\xa9"); ("textasciitilde", "~");
  ("textbackslash", "\\"); ("textbar", "|"); ("textless", "<"); ("textgreater", ">"); ("textasciicircum", "^"); ("textunderscore", "_"); ("S", "\xc2\xa7"); ("P", "\xc2\xb6");
  ("dag", "\xe2\x80\xa0"); ("pounds", "\xc2\xa3"); ("ss", "\xc3\x9f"); ("o", "\xc3\xb8"); ("O", "\xc3\x98"); ("ae", "\xc3\xa6"); ("AE", "\xc3\x86"); ("textregistered", "\xc2\xae");
  ("texttrademark", "\xe2\x84\xa2"); ("textbullet", "\xe2\x80\xa2"); ("textquotedblleft", "\xe2\x80\x9c"); ("textquotedblright", "\xe2\x80\x9d"); ("textendash", "\xe2\x80\x93");
  ("textemdash", "\xe2\x80\x94"); ("slash", "/"); ("quad", "  "); ("qquad", "    "); ("hfill", "  "); ("and", "    "); ("i", "i");
  (* in mathematics, with what the PDF's fonts have *)
  ("times", "\xc3\x97"); ("cdot", "\xc2\xb7"); ("to", "->"); ("rightarrow", "->"); ("mapsto", "->"); ("leftarrow", "<-"); ("Rightarrow", "=>"); ("leq", "<="); ("le", "<=");
  ("geq", ">="); ("ge", ">="); ("neq", "!="); ("ne", "!="); ("approx", "~"); ("sim", "~"); ("equiv", "=="); ("pm", "\xc2\xb1"); ("div", "\xc3\xb7"); ("mu", "\xc2\xb5");
  ("infty", "infinity"); ("langle", "<"); ("rangle", ">"); ("ast", "*"); ("star", "*"); ("in", " in "); ("ll", "<<"); ("gg", ">>"); ("mid", "|"); ("vee", " or "); ("wedge", " and ");
  ("neg", "not "); ("cup", " U "); ("log", "log"); ("sin", "sin"); ("cos", "cos"); ("max", "max"); ("min", "min"); ("bmod", " mod "); ("ldotp", "."); ("prime", "'");
  ("alpha", "alpha"); ("beta", "beta"); ("gamma", "gamma"); ("delta", "delta"); ("epsilon", "epsilon"); ("lambda", "lambda"); ("pi", "pi"); ("sigma", "sigma"); ("theta", "theta");
  ("omega", "omega"); ("Delta", "Delta"); ("Sigma", "Sigma"); ("Omega", "Omega"); ("sum", "sum"); ("prod", "prod"); ("sqrt", "sqrt"); ("forall", "for all "); ("exists", "exists ");
  ("lfloor", "floor("); ("rfloor", ")"); ("lceil", "ceil("); ("rceil", ")"); ("emptyset", "{}"); ("subseteq", " in "); ("subset", " in "); ("circ", "o"); ("bullet", "\xe2\x80\xa2");
  ("tau", "tau"); ("phi", "phi"); ("rho", "rho"); ("leftrightarrow", "<->"); ("not", "not "); ("ln", "ln"); ("exp", "exp") ]

(* the commands that say nothing here, with what they take: m an
 * argument, o one that may not be there, * a star *)
let nothing = [
  ("usepackage", "om"); ("documentclass", "om"); ("noweboptions", "m"); ("hypersetup", "m"); ("setlength", "mm"); ("addtolength", "mm"); ("captionsetup", "om"); ("bibliographystyle", "m");
  ("patchcmd", "mmmmm"); ("hyphenation", "m"); ("pagestyle", "m"); ("thispagestyle", "m"); ("pagenumbering", "m"); ("setcounter", "mm"); ("addtocounter", "mm");
  ("newcounter", "mo"); ("newlength", "m"); ("geometry", "m"); ("definecolor", "mmm"); ("color", "m"); ("phantom", "m"); ("index", "m"); ("SetWatermarkText", "m"); ("linespread", "m");
  ("rule", "omm"); ("cleardoublepage", ""); ("makeatletter", ""); ("makeatother", ""); ("sloppy", ""); ("noindent", ""); ("indent", ""); ("raggedright", ""); ("raggedleft", "");
  ("relax", ""); ("protect", ""); ("endtrivlist", ""); ("null", ""); ("vfill", ""); ("vfil", ""); ("newpage", ""); ("clearpage", ""); ("pagebreak", "o"); ("nopagebreak", "o"); ("onecolumn", "");
  ("twocolumn", "o"); ("frontmatter", ""); ("mainmatter", ""); ("backmatter", ""); ("swdefs", "m"); ("swuses", "m"); ("nwdocspar", ""); ("nwendcode", ""); ("backref", ""); ("hline", "");
  ("toprule", ""); ("midrule", "o"); ("bottomrule", ""); ("otoprule", ""); ("cline", "m"); ("displaystyle", ""); ("left", ""); ("right", ""); ("limits", ""); ("nonumber", ""); ("fussy", "");
  ("selectfont", ""); ("fontsize", "mm"); ("normalfont", ""); ("vspace", "*m"); ("hspace", "*m"); ("smallskip", ""); ("label@", ""); ("tolerance", ""); ("flushbottom", ""); ("raggedbottom", "");
  ("listoffigures", ""); ("listoftables", ""); ("printindex", ""); ("makeindex", ""); ("nowebchunks", ""); ("thispagestyle", "m"); ("columnbreak", ""); ("balance", ""); ("minitoc", "");
  ("DeclareUnicodeCharacter", "mm"); ("mathbin", ""); ("-", ""); ("/", ""); ("!", ""); ("@", "") ]

let accents = [
  ("'a", "\xc3\xa1"); ("'e", "\xc3\xa9"); ("'i", "\xc3\xad"); ("'o", "\xc3\xb3"); ("'u", "\xc3\xba"); ("'E", "\xc3\x89"); ("`a", "\xc3\xa0"); ("`e", "\xc3\xa8"); ("`u", "\xc3\xb9");
  ("^a", "\xc3\xa2"); ("^e", "\xc3\xaa"); ("^i", "\xc3\xae"); ("^o", "\xc3\xb4"); ("^u", "\xc3\xbb"); ("\"a", "\xc3\xa4"); ("\"e", "\xc3\xab"); ("\"i", "\xc3\xaf"); ("\"o", "\xc3\xb6");
  ("\"u", "\xc3\xbc"); ("\"O", "\xc3\x96"); ("\"U", "\xc3\x9c"); ("~n", "\xc3\xb1"); ("~a", "\xc3\xa3"); ("~o", "\xc3\xb5"); ("cc", "\xc3\xa7"); ("cC", "\xc3\x87"); ("vs", "\xc5\xa1"); ("vz", "\xc5\xbe") ]

(* a length, in the document's ens: 1in, 3cm, 0.5\linewidth *)
let length (t : t) (width : float) (s : string) : float =
  let s = String.trim s in
  let n = String.length s in
  let rec number (i : int) : int = if i < n && (is_digit s.[i] || s.[i] = '.' || s.[i] = '-') then number (i + 1) else i in
  let e = number 0 in
  let v = if e = 0 then 1. else (match float_of_string_opt (String.sub s 0 e) with Some v -> v | None -> 1.) in
  let inch = if t.paper then 14.4 else 10. in
  match String.trim (String.sub s e (n - e)) with
  | "in" -> v *. inch
  | "cm" -> v *. inch /. 2.54
  | "mm" -> v *. inch /. 25.4
  | "pt" -> v *. inch /. 72.27
  | "em" -> v *. (if t.paper then 2. else 1.)
  | "ex" -> v *. 1.
  | "\\linewidth" | "\\textwidth" | "\\columnwidth" | "\\hsize" -> v *. width
  | _ -> 0.

(* text put for #1, #2...; ## is a # *)
let substitute (body : string) (args : string list) : string =
  let b = Buffer.create (String.length body + 16) in
  let n = String.length body in
  let rec go (i : int) =
    if i < n then
      if body.[i] = '#' && i + 1 < n && body.[i + 1] = '#' then begin Buffer.add_char b '#'; go (i + 2) end
      else if body.[i] = '#' && i + 1 < n && is_digit body.[i + 1] then begin
        (match List.nth_opt args (Char.code body.[i + 1] - Char.code '1') with Some a -> Buffer.add_string b a | None -> ());
        go (i + 2)
      end else begin Buffer.add_char b body.[i]; go (i + 1) end in
  go 0;
  Buffer.contents b

(* what a command names: \x, or {\x} *)
let named (s : string) : string =
  let s = String.trim s in
  if s <> "" && s.[0] = '\\' then String.sub s 1 (String.length s - 1) else s

let add_to (table : (string, int list) Hashtbl.t) (key : string) (n : int) =
  let l = match Hashtbl.find_opt table key with Some l -> l | None -> [] in
  if not (List.mem n l) then Hashtbl.replace table key (l @ [ n ])

let numbers (l : int list) : string = String.concat ", " (List.map string_of_int l)

(* ---------------------------------------------------------------- *)
(* The reading *)
(* ---------------------------------------------------------------- *)

(* a false branch passed over: to its \else (when [to_else]) or its
 * \fi, the conditionals inside it counted *)
let skip_branch (t : t) (to_else : bool) =
  match t.input with
  | [] -> ()
  | f :: _ ->
      let n = String.length f.s in
      let word (j : int) : int = let rec go (k : int) : int = if k < n && (is_letter f.s.[k] || f.s.[k] = '@') then go (k + 1) else k in go j in
      let rec go (j : int) (depth : int) : int =
        if j >= n then n
        else if f.s.[j] = '[' && j + 1 < n && f.s.[j + 1] = '[' then go (quoted f.s (j + 2)) depth
        else if f.s.[j] = '%' then (match String.index_from_opt f.s j '\n' with Some e -> go (e + 1) depth | None -> n)
        else if f.s.[j] <> '\\' then go (j + 1) depth
        else
          let e = word (j + 1) in
          let w = String.sub f.s (j + 1) (e - j - 1) in
          if w = "" then go (j + 2) depth
          else if w = "newif" then go (if e < n && f.s.[e] = '\\' then word (e + 1) else e) depth
          else if w = "fi" then (if depth = 0 then e else go e (depth - 1))
          else if w = "else" && depth = 0 && to_else then e
          else if String.length w > 2 && String.sub w 0 2 = "if" then go e (depth + 1)
          else go e depth in
      let e = go f.i 0 in
      skip t (e - f.i)

(* what is written to the \end of an environment, as it is; the
 * environments of the same name inside it counted when [nested] *)
let to_end (t : t) (env : string) (nested : bool) : string =
  match t.input with
  | [] -> ""
  | f :: _ ->
      let n = String.length f.s in
      let opening = "\\begin{" ^ env ^ "}" and ending = "\\end{" ^ env ^ "}" in
      let at (j : int) (w : string) : bool = j + String.length w <= n && String.sub f.s j (String.length w) = w in
      let rec go (j : int) (depth : int) : int =
        match String.index_from_opt f.s (min j n) '\\' with
        | None -> n
        | Some j -> if at j ending then (if depth = 0 then j else go (j + 1) (depth - 1)) else if nested && at j opening then go (j + 1) (depth + 1) else go (j + 1) depth in
      let e = go f.i 0 in
      let inner = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + String.length ending);
      inner

let rec run (t : t) =
  let going = ref true in
  while !going do
    match peek t with
    | None -> going := false
    | Some c -> step t c
  done

(* a text read apart, where it is written *)
and capture (t : t) (raw : string) =
  t.input <- { s = raw; i = 0; stop = true; file = ""; line = 1; counts = false } :: t.input;
  let groups = t.groups and envs = t.envs in
  run t;
  t.groups <- groups;
  t.envs <- envs;
  (match t.input with f :: rest when f.stop -> t.input <- rest | _ -> ())

(* a text read apart: its paragraph *)
and inlines_of (t : t) (raw : string) : Doc.inline list =
  let saved = t.out and look = t.look in
  t.out <- fresh ();
  capture t raw;
  let l = List.rev t.out.line in
  (* (a text of several paragraphs, where one is wanted: its words) *)
  let before = List.concat_map (fun (b : Doc.block) -> match b with Doc.Para p -> p.body @ [ Doc.Text (look.style, " ") ] | _ -> []) (List.rev t.out.blocks) in
  saved.feet <- t.out.feet @ List.filter (fun (b : Doc.block) -> match b with Doc.Footnote _ -> true | _ -> false) t.out.blocks @ saved.feet;
  t.out <- saved;
  t.look <- look;
  before @ l

and with_look (t : t) (look : look) (raw : string) : Doc.inline list =
  let saved = t.look in
  t.look <- look;
  let l = inlines_of t raw in
  t.look <- saved;
  l

and step (t : t) (c : char) =
  if at_line_start t && special_line t c then ()
  else
    match c with
    | '\\' -> advance t; command t (name t)
    | '{' -> advance t; t.groups <- t.look :: t.groups
    | '}' -> advance t; (match t.groups with l :: rest -> t.look <- l; t.groups <- rest | [] -> ())
    | '%' -> ignore (rest_of_line t); (let rec spaces () = match peek t with Some (' ' | '\t') -> advance t; spaces () | _ -> () in spaces ())
    | '~' -> advance t; text t "\xc2\xa0"
    | '$' ->
        advance t;
        if peek t = Some '$' then begin
          advance t;
          let raw = until t "$$" in
          display t raw
        end else math t (until t "$")
    | '[' when looking t "[[" ->
        skip t 2;
        let raw = until t "]]" in
        let rec more (s : string) : string = if peek t = Some ']' then begin advance t; more (s ^ "]") end else s in
        put t (Doc.Text (mono_of t.look.style, more raw))
    | '[' when looking t "[<" && (match t.input with f :: _ -> (match String.index_from_opt f.s f.i '\n', String.index_from_opt f.s f.i '>' with nl, Some gt -> (match nl with Some nl -> gt < nl | None -> true) && gt + 1 < String.length f.s && f.s.[gt + 1] = ']' | _ -> false) | [] -> false) ->
        skip t 2;
        put t (Doc.Text (mono_of t.look.style, until t ">]"))
    | '\n' ->
        advance t;
        let rec blank (k : int) : int option = match ahead t k with Some (' ' | '\t') -> blank (k + 1) | Some '\n' -> Some k | _ -> None in
        (match blank 0 with
         | Some _ when (match t.input with f :: _ -> f.i < String.length f.s | [] -> false) ->
             let rec all () = match blank 0 with Some k -> skip t (k + 1); all () | None -> () in
             all ();
             par t
         | _ -> space t)
    | ' ' | '\t' | '\r' -> advance t; space t
    | '-' when t.look.style.font <> Doc.Mono && looking t "---" -> skip t 3; text t "\xe2\x80\x94"
    | '-' when t.look.style.font <> Doc.Mono && looking t "--" -> skip t 2; text t "\xe2\x80\x93"
    | '`' when looking t "``" -> skip t 2; text t "\xe2\x80\x9c"
    | '\'' when looking t "''" -> skip t 2; text t "\xe2\x80\x9d"
    | _ ->
        (* (the letters to the next mark, at once) *)
        (match t.input with
         | f :: _ ->
             let n = String.length f.s in
             let plain (c : char) : bool = match c with '\\' | '{' | '}' | '%' | '~' | '$' | '[' | '\n' | ' ' | '\t' | '\r' | '-' | '`' | '\'' -> false | _ -> true in
             let rec go (j : int) : int = if j < n && plain f.s.[j] then go (j + 1) else j in
             let e = max (f.i + 1) (go f.i) in
             text t (String.sub f.s f.i (e - f.i));
             f.i <- e
         | [] -> ())

(* what is to the next [mark], and past it *)
and until (t : t) (mark : string) : string =
  match t.input with
  | f :: _ ->
      let n = String.length f.s and m = String.length mark in
      let rec find (j : int) : int = if j + m > n then n else if String.sub f.s j m = mark then j else find (j + 1) in
      let e = find f.i in
      let inner = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + m);
      inner
  | [] -> ""

(* A line that is not LaTeX's: a chunk of code (noweb), a file put
 * here (syncweb's #include), the author's notes to himself, which a
 * book does not show. *)
and special_line (t : t) (c : char) : bool =
  if c = '<' && looking t "<<" then begin
    let line = match t.input with f :: _ -> (match String.index_from_opt f.s f.i '\n' with Some e -> String.sub f.s f.i (e - f.i) | None -> String.sub f.s f.i (String.length f.s - f.i)) | [] -> "" in
    let line = String.trim line in
    let n = String.length line in
    if n > 5 && String.sub line (n - 3) 3 = ">>=" then begin
      ignore (rest_of_line t);
      chunk t (String.trim (String.sub line 2 (n - 5)));
      true
    end else false
  end
  else if c = '#' && looking t "#include" then begin
    let line = rest_of_line t in
    (match String.index_opt line '"' with
     | Some a -> (match String.index_from_opt line (a + 1) '"' with Some b -> file t (String.sub line (a + 1) (b - a - 1)) | None -> ())
     | None -> ());
    true
  end
  else if c = '\\' && (looking t "\\l " || looking t "\\t " || looking t "\\n " || looking t "\\l\n" || looking t "\\t\n" || looking t "\\n\n") then begin ignore (rest_of_line t); true end
  else if c = '@' && (looking t "@\n" || looking t "@ ") then begin ignore (rest_of_line t); true end
  else false

(* a file read where it is named *)
and file (t : t) (path : string) =
  match (match t.load path with Some s -> Some s | None -> t.load (path ^ ".tex")) with
  | Some s -> if List.length t.input > 100 then say t ("too many files inside each other: " ^ path) else t.input <- { s; i = 0; stop = false; file = Filename.basename path; line = 1; counts = true } :: t.input
  | None -> say t ("no file " ^ path)

(* A chunk: its name, in which chunk the name was first defined, and
 * its lines, the chunks it names in them said the same way; then
 * where it is used. *)
and chunk (t : t) (chunk_name : string) =
  par t;
  t.chunk <- t.chunk + 1;
  let me = t.chunk in
  if not t.final then add_to t.known.defs chunk_name me;
  let lines = ref [] in
  let going = ref true in
  while !going do
    match peek t with
    | None -> going := false
    | Some _ ->
        if looking t "@\n" || looking t "@ " || (match t.input with f :: _ -> f.i + 1 = String.length f.s && f.s.[f.i] = '@' | [] -> false) then begin ignore (rest_of_line t); going := false end
        else begin
          let ends_def = looking t "<<" && (match t.input with f :: _ -> (let e = match String.index_from_opt f.s f.i '\n' with Some e -> e | None -> String.length f.s in let l = String.trim (String.sub f.s f.i (e - f.i)) in String.length l > 5 && String.sub l (String.length l - 3) 3 = ">>=") | [] -> false) in
          if ends_def then going := false else lines := rest_of_line t :: !lines
        end
  done;
  let rec trim (l : string list) : string list = match l with "" :: rest -> trim rest | l -> l in
  let lines = List.rev (trim !lines) in
  let small : Doc.style = { font = Doc.Mono; size = -2; shift = 0 } in
  let italic : Doc.style = { font = Doc.Italic; size = -2; shift = 0 } in
  let roman : Doc.style = { font = Doc.Roman; size = -2; shift = 0 } in
  let first (n : string) : string = match Hashtbl.find_opt t.known.defs n with Some (d :: _) -> " " ^ string_of_int d | _ -> "" in
  let named (n : string) : Doc.inline list =
    [ Doc.Text (italic, "\xe2\x80\xb9") ] @ with_look t { style = italic; caps = false; center = false } n @ [ Doc.Text (italic, first n ^ "\xe2\x80\xba") ] in
  let line (l : string) : Doc.inline list =
    let n = String.length l in
    let rec go (i : int) (from : int) (acc : Doc.inline list) : Doc.inline list =
      let piece (upto : int) : Doc.inline list = if upto > from then [ Doc.Text (small, String.sub l from (upto - from)) ] else [] in
      if i + 1 >= n then acc @ piece n
      else if l.[i] = '@' && l.[i + 1] = '<' && i + 2 < n && l.[i + 2] = '<' then go (i + 3) (i + 1) (acc @ piece i)
      else if l.[i] = '<' && l.[i + 1] = '<' then begin
        let rec close (j : int) : int option = if j + 1 >= n then None else if l.[j] = '>' && l.[j + 1] = '>' then Some j else close (j + 1) in
        match close (i + 2) with
        | Some j ->
            let used = String.trim (String.sub l (i + 2) (j - i - 2)) in
            if not t.final then add_to t.known.uses used me;
            go (j + 2) (j + 2) (acc @ piece i @ named used)
        | None -> go (i + 2) from acc
      end else go (i + 1) from acc in
    go 0 0 [] in
  let defs = match Hashtbl.find_opt t.known.defs chunk_name with Some l -> l | None -> [ me ] in
  let is_first = (match defs with d :: _ -> d = me | [] -> true) in
  let head = named chunk_name @ [ Doc.Text (roman, if is_first then "=" else "+=") ] in
  let uses = match Hashtbl.find_opt t.known.uses chunk_name with Some l -> l | None -> [] in
  let notes =
    (if is_first && uses <> [] then [ "used in " ^ numbers uses ] else [])
    @ (if is_first && List.length defs > 1 then [ "more in " ^ numbers (List.tl defs) ] else []) in
  let head = if notes = [] then head else head @ [ Doc.Text (roman, "   (" ^ String.concat "; " notes ^ ")") ] in
  block t (lines_as_they_are t (-2) (head :: List.map line lines))

(* ---------------------------------------------------------------- *)
(* Mathematics, as far as words go *)
(* ---------------------------------------------------------------- *)

(* letters in italic, the rest as it is, what is raised and lowered a
 * size smaller; the symbols the PDF's fonts have, and words for the
 * others *)
and math (t : t) (raw : string) =
  let n = String.length raw in
  let italic (style : Doc.style) : Doc.style = { style with font = Doc.Italic } in
  let rec go (style : Doc.style) (i : int) : int =
    if i >= n then n
    else
      match raw.[i] with
      | ' ' | '\n' | '\t' -> go style (i + 1)
      | '}' -> i + 1
      | '{' -> go style (go style (i + 1))
      | '^' | '_' ->
          let small : Doc.style = { style with size = style.size - 2; shift = style.shift + (if raw.[i] = '^' then 1 else -1) } in
          if i + 1 < n && raw.[i + 1] = '{' then go style (go small (i + 2))
          else if i + 1 < n && raw.[i + 1] = '\\' then go style (one small (i + 1))
          else if i + 1 < n then begin put t (Doc.Text ((if is_letter raw.[i + 1] then italic small else small), String.make 1 raw.[i + 1])); go style (i + 2) end
          else n
      | '\\' -> go style (one style i)
      | c ->
          put t (Doc.Text ((if is_letter c then italic style else style), (match c with '<' | '>' | '=' | '+' -> " " ^ String.make 1 c ^ " " | '-' -> " \xe2\x80\x93 " | ',' -> ", " | c -> String.make 1 c)));
          go style (i + 1)
  (* a command, at raw.[i]: where the reading goes on *)
  and one (style : Doc.style) (i : int) : int =
    let rec letters (j : int) : int = if j < n && is_letter raw.[j] then letters (j + 1) else j in
    let e = letters (i + 1) in
    let e = if e = i + 1 then min n (i + 2) else e in
    let w = String.sub raw (i + 1) (e - i - 1) in
    if List.mem_assoc w with_text && e < n && raw.[e] = '{' then begin
      let c = closing raw (e + 1) '{' '}' in
      let look = t.look in
      t.look <- { look with style };
      List.iter (put t) (inlines_of t ("\\" ^ w ^ "{" ^ String.sub raw (e + 1) (c - e - 1) ^ "}"));
      t.look <- look;
      min n (c + 1)
    end else begin
      (match w with
       | " " | "," | ";" | ":" -> put t (Doc.Text (style, " "))
       | "{" | "}" | "%" | "_" | "&" | "#" | "$" -> put t (Doc.Text (style, w))
       | "frac" -> ()
       | _ ->
           (match List.assoc_opt w symbols with
            | Some s -> put t (Doc.Text (style, s))
            | None -> if not (List.mem_assoc w nothing) then begin say_once t ("\\" ^ w ^ " (in mathematics)"); put t (Doc.Text (style, w)) end));
      e
    end in
  ignore (go t.look.style 0)

(* mathematics on a line of its own *)
and display (t : t) (raw : string) =
  par t;
  let saved = t.look in
  t.look <- { saved with center = true };
  math t raw;
  par t;
  t.look <- saved

(* ---------------------------------------------------------------- *)
(* The commands *)
(* ---------------------------------------------------------------- *)

and expand (t : t) (m : macro) =
  let first = match m.default with Some d when m.args > 0 -> [ (match opt t with Some o -> o | None -> d) ] | _ -> [] in
  let rest = List.init (m.args - List.length first) (fun _ -> arg t) in
  if List.length t.input > 200 then say t "macros inside each other without end" else push t (substitute m.body (first @ rest))

and define (t : t) (replace : bool) =
  ignore (star t);
  let n = named (arg t) in
  let args = match opt t with Some k -> (match int_of_string_opt (String.trim k) with Some k -> k | None -> 0) | None -> 0 in
  let default = opt t in
  let body = arg t in
  if replace || not (Hashtbl.mem t.macros n) then Hashtbl.replace t.macros n { args; default; body }

and heading (t : t) (level : int) =
  let starred = star t in
  ignore (opt t);
  let raw = arg t in
  par t;
  let level = if t.report then level else max 1 level in
  let number =
    if starred || level > 3 then ""
    else begin
      (match level with
       | 0 -> t.chapter <- t.chapter + 1; t.section <- 0; t.subsection <- 0; t.subsubsection <- 0; t.figure <- 0; t.table <- 0
       | 1 -> t.section <- t.section + 1; t.subsection <- 0; t.subsubsection <- 0
       | 2 -> t.subsection <- t.subsection + 1; t.subsubsection <- 0
       | _ -> t.subsubsection <- t.subsubsection + 1);
      let chapter = if t.appendix then String.make 1 (Char.chr (64 + min 26 (max 1 t.chapter))) else string_of_int t.chapter in
      let parts = (if t.report then [ chapter ] else []) @ (if level >= 1 then [ string_of_int t.section ] else []) @ (if level >= 2 then [ string_of_int t.subsection ] else []) @ (if level >= 3 then [ string_of_int t.subsubsection ] else []) in
      String.concat "." parts
    end in
  if number <> "" then t.here <- number;
  if not t.final && t.body && not starred then t.known.toc <- (level, number, raw) :: t.known.toc;
  let size = match level with -1 -> 6 | 0 -> 6 | 1 -> 4 | 2 -> 2 | _ -> 0 in
  let style : Doc.style = { font = Doc.Bold; size; shift = 0 } in
  let title = with_look t { style; caps = false; center = false } raw in
  let label = if number = "" then [] else [ Doc.Text (style, (if level = 0 then (if t.appendix then "Appendix " else "Chapter ") ^ number ^ "\xc2\xa0\xc2\xa0" else number ^ "\xc2\xa0\xc2\xa0")) ] in
  if t.body then begin
    emit t (Doc.Space (if level <= 0 then 2. else if level = 1 then 1. else 0.6));
    emit t (Doc.Heading (1, label @ title));
    emit t (Doc.Space (if level <= 0 then 0.8 else 0.3))
  end

and begin_env (t : t) (env_name : string) =
  let gather (e : env) = t.envs <- e :: t.envs; (match e.outer with Some _ -> t.out <- fresh () | None -> ()) in
  let make (gathers : bool) : env = { name = env_name; outer = (if gathers then Some t.out else None); saved = t.look; started = false; tag = []; count = 0; caption = None; after = None } in
  match env_name with
  | "document" -> t.body <- true
  | "itemize" | "enumerate" | "description" | "thebibliography" ->
      if env_name = "thebibliography" then begin ignore (arg t); push t "\\section*{References}" ; run_pushed t end;
      par t; gather (make true)
  | "figure" | "figure*" | "table" | "table*" -> ignore (opt t); par t; gather (make true)
  | "center" | "flushright" | "flushleft" -> par t; gather (make false); if env_name = "center" then t.look <- { t.look with center = true }
  | "quote" | "quotation" | "verse" | "abstract" -> par t; gather (make true)
  | "minipage" -> ignore (opt t); ignore (arg t); par t; gather (make false); t.look <- { t.look with center = false }
  | "tabular" | "tabular*" | "tabularx" | "longtable" -> tabular t env_name
  | "tikzpicture" | "picture" -> ignore (to_end t env_name true); say t ("a picture drawn by commands (" ^ env_name ^ ")"); par t; block t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = [ Doc.Text (t.look.style, "[a picture]") ] })
  | "equation" | "equation*" | "displaymath" | "align" | "align*" | "eqnarray" | "eqnarray*" -> display t (to_end t env_name false)
  | _ ->
      (match Hashtbl.find_opt t.verbatims env_name, Hashtbl.find_opt t.environments env_name with
       | Some small, _ ->
           ignore (opt t);
           let raw = to_end t env_name false in
           verbatim t (if small then -1 else 0) raw
       | None, Some (m, after) ->
           let e = make false in
           e.after <- Some after;
           gather e;
           expand t m
       | None, None -> say_once t ("\\begin{" ^ env_name ^ "}"); gather (make false))

(* (a heading asked for by a text put in front: read before going on) *)
and run_pushed (t : t) =
  match t.input with
  | f :: _ when not f.counts && not f.stop -> let raw = String.sub f.s f.i (String.length f.s - f.i) in t.input <- List.tl t.input; capture t raw
  | _ -> ()

and verbatim (t : t) (size : int) (raw : string) =
  par t;
  let lines = String.split_on_char '\n' raw in
  let lines = match lines with "" :: rest -> rest | l -> l in
  let lines = match List.rev lines with l :: rest when String.trim l = "" -> List.rev rest | _ -> lines in
  let style : Doc.style = { font = Doc.Mono; size; shift = 0 } in
  block t (lines_as_they_are t size (List.map (fun l -> if l = "" then [] else [ Doc.Text (style, l) ]) lines))

(* a list's item is ended: it goes to the list's place *)
and end_item (t : t) (e : env) =
  par t;
  (match e.outer with
   | Some outer ->
       if e.started then begin
         let wide = cols t (match e.name with "itemize" -> 3. | "enumerate" -> 4. | _ -> 5.) in
         (match outer.blocks with [] | Doc.Space _ :: _ | Doc.Heading _ :: _ -> () | _ -> outer.blocks <- Doc.Space (gap t) :: outer.blocks);
         outer.blocks <- Doc.Tagged { tag = e.tag; width = wide; body = List.rev t.out.blocks } :: outer.blocks
       end;
       t.out <- fresh ()
   | None -> ())

and item (t : t) =
  let label = opt t in
  match List.find_opt (fun (e : env) -> e.outer <> None && (e.name = "itemize" || e.name = "enumerate" || e.name = "description" || e.name = "thebibliography")) t.envs with
  | None -> say_once t "\\item outside a list"
  | Some e ->
      (* (what was opened in the last item and not closed is closed) *)
      let rec close () = match t.envs with top :: _ when top != e -> end_env t top.name; close () | _ -> () in
      close ();
      end_item t e;
      e.started <- true;
      e.count <- e.count + 1;
      t.look <- e.saved;
      e.tag <-
        (match label, e.name with
         | Some l, _ -> with_look t { t.look with style = { t.look.style with font = Doc.Bold } } l
         | None, "enumerate" -> [ Doc.Text (t.look.style, string_of_int e.count ^ ".") ]
         | None, _ -> [ Doc.Text (t.look.style, "\xe2\x80\xa2") ])

and end_env (t : t) (env_name : string) =
  if env_name = "document" then begin par t; t.input <- [] end
  else
    match t.envs with
    | e :: rest when e.name = env_name ->
        (match e.after with
         | Some after -> e.after <- None; push t ("\\end{" ^ env_name ^ "}"); push t after
         | None ->
             (match e.outer with
              | None -> par t
              | Some outer ->
                  (match env_name with
                   | "itemize" | "enumerate" | "description" | "thebibliography" -> end_item t e; t.out <- outer
                   | _ ->
                       par t;
                       let body = List.rev t.out.blocks in
                       t.out <- outer;
                       (match env_name with
                        | "figure" | "figure*" | "table" | "table*" ->
                            let caption = match e.caption with Some c -> [ Doc.Space (gap t); Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = c } ] | None -> [] in
                            block t (Doc.Keep (body @ caption))
                        | "abstract" ->
                            block t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = [ Doc.Text ({ font = Doc.Bold; size = 0; shift = 0 }, "Abstract") ] });
                            block t (Doc.Indent (cols t 4., body))
                        | _ -> block t (Doc.Indent (cols t 4., body)))));
             t.look <- e.saved;
             t.envs <- rest)
    | _ ->
        if List.exists (fun (e : env) -> e.name = env_name) t.envs then begin
          (* (what was opened inside it and not closed is closed) *)
          let rec close () = match t.envs with top :: _ when top.name <> env_name -> end_env t top.name; close () | _ -> () in
          close ();
          end_env t env_name
        end else say_once t ("\\end{" ^ env_name ^ "} with no \\begin")

(* A table: its columns' sides, then its rows, cut at \\ and its
 * cells at &, as they are written; a rule is a row. *)
and tabular (t : t) (env_name : string) =
  let width = if t.paper then 86.4 else 60. in
  let asked = if env_name = "tabular*" || env_name = "tabularx" then length t width (arg t) else 0. in
  ignore asked;
  ignore (opt t);
  let spec = arg t in
  let raw = to_end t env_name true in
  (* the columns: a side, whether a text is filled in it, its width *)
  let columns : (Doc.align * bool * float) list =
    let n = String.length spec in
    let rec go (i : int) (acc : (Doc.align * bool * float) list) : (Doc.align * bool * float) list =
      if i >= n then List.rev acc
      else
        let braces (j : int) : string * int = if j < n && spec.[j] = '{' then (let e = closing spec (j + 1) '{' '}' in (String.sub spec (j + 1) (e - j - 1), e + 1)) else ("", j) in
        match spec.[i] with
        | 'l' -> go (i + 1) ((Doc.Left, false, 0.) :: acc)
        | 'c' -> go (i + 1) ((Doc.Center, false, 0.) :: acc)
        | 'r' -> go (i + 1) ((Doc.Right, false, 0.) :: acc)
        | 'X' -> go (i + 1) ((Doc.Left, true, 0.) :: acc)
        | 'p' | 'm' | 'b' -> let w, j = braces (i + 1) in go j ((Doc.Left, true, length t width w) :: acc)
        | '@' | '>' | '<' | '!' -> let _, j = braces (i + 1) in go (max j (i + 1)) acc
        | _ -> go (i + 1) acc in
    go 0 [] in
  let count = max 1 (List.length columns) in
  (* the rows and their cells, as written *)
  let n = String.length raw in
  let rows : string list list ref = ref [] and cells : string list ref = ref [] and from = ref 0 in
  let cell (upto : int) = cells := String.sub raw !from (upto - !from) :: !cells in
  let rec go (i : int) (depth : int) =
    if i >= n then begin cell n; rows := List.rev !cells :: !rows end
    else
      match raw.[i] with
      | '\\' when i + 1 < n && raw.[i + 1] = '\\' && depth = 0 ->
          cell i;
          rows := List.rev !cells :: !rows;
          cells := [];
          let j = if i + 2 < n && raw.[i + 2] = '*' then i + 3 else i + 2 in
          let j = if j < n && raw.[j] = '[' then (match String.index_from_opt raw j ']' with Some e -> e + 1 | None -> j) else j in
          from := j;
          go j depth
      | '\\' when i + 6 < n && String.sub raw i 7 = "\\begin{" -> go (i + 6) (depth + 1)
      | '\\' when i + 4 < n && String.sub raw i 5 = "\\end{" -> go (i + 4) (depth - 1)
      | '\\' -> go (i + 2) depth
      | '%' -> (match String.index_from_opt raw i '\n' with Some e -> go (e + 1) depth | None -> go n depth)
      | '{' -> go (i + 1) (depth + 1)
      | '}' -> go (i + 1) (depth - 1)
      | '[' when i + 1 < n && raw.[i + 1] = '[' -> (let rec close (j : int) : int = if j + 1 >= n then n else if raw.[j] = ']' && raw.[j + 1] = ']' then j + 2 else close (j + 1) in go (close (i + 2)) depth)
      | '&' when depth = 0 -> cell i; from := i + 1; go (i + 1) depth
      | _ -> go (i + 1) depth in
  go 0 0;
  let has (w : string) : bool = let m = String.length w in let rec at (i : int) : bool = i + m <= n && (String.sub raw i m = w || at (i + 1)) in at 0 in
  (* cells that are blocks (a display, chunks of code) are not a
   * table's here: one after the other *)
  if has "\\begin{minipage}" || has "\\VerbatimInput" || has "\\begin{verbatim}" then begin
    par t;
    let file, _ = place t in
    List.iter (fun (row : string list) ->
      List.iter (fun (cell : string) ->
        t.input <- { s = String.trim cell ^ "\n"; i = 0; stop = true; file; line = 1; counts = true } :: t.input;
        run t;
        (match t.input with f :: rest when f.stop -> t.input <- rest | _ -> ());
        par t) row) (List.rev !rows)
  end else
  let rules = [ "\\hline"; "\\toprule"; "\\midrule"; "\\bottomrule"; "\\otoprule" ] in
  let starts (s : string) (w : string) : bool = String.length s >= String.length w && String.sub s 0 (String.length w) = w in
  (* the rules a row begins with, and the row without them *)
  let rec ruled (s : string) (k : int) : int * string =
    let s = String.trim s in
    match List.find_opt (starts s) rules with
    | Some w -> ruled (String.sub s (String.length w) (String.length s - String.length w)) (k + 1)
    | None ->
        if starts s "\\cline" || starts s "\\cmidrule" then (match String.index_opt s '}' with Some e -> ruled (String.sub s (e + 1) (String.length s - e - 1)) k | None -> (k, s))
        else if starts s "%" then (match String.index_opt s '\n' with Some e -> ruled (String.sub s (e + 1) (String.length s - e - 1)) k | None -> (k, ""))
        else (k, s) in
  let made : (Doc.cell list option * int) list =
    List.map (fun (row : string list) ->
      match row with
      | [] -> (None, 0)
      | head :: rest ->
          let k, head = ruled head 0 in
          if rest = [] && String.trim head = "" then (None, k)
          else
            (Some (List.mapi (fun (col : int) (raw : string) ->
              let align, filled, _ = match List.nth_opt columns col with Some c -> c | None -> (Doc.Left, false, 0.) in
              t.span <- 1;
              t.cell_align <- None;
              let body = List.map (fun (i : Doc.inline) -> match i with Doc.Break -> Doc.Text (t.look.style, " ") | i -> i) (inlines_of t (String.trim raw)) in
              let c : Doc.cell = { align = (match t.cell_align with Some a -> a | None -> align); span = t.span; filled = filled && t.span = 1; body } in
              c) (head :: rest)), k)) (List.rev !rows) in
  (* a column of long texts is filled in what the line has left, when
   * the table would not fit on it *)
  let longest = Array.make count 0 in
  List.iter (fun ((r, _) : Doc.cell list option * int) ->
    match r with
    | Some cs -> ignore (List.fold_left (fun (k : int) (c : Doc.cell) -> (if c.span = 1 && k < count then longest.(k) <- max longest.(k) (Utf8.length (words c.body))); k + c.span) 0 cs)
    | None -> ()) made;
  let room = 60 in
  let total = Array.fold_left (fun s w -> s + w) (3 * (count - 1)) longest in
  let given (k : int) : float = match List.nth_opt columns k with Some (_, _, w) -> w | None -> 0. in
  let wants (k : int) : bool = match List.nth_opt columns k with Some (_, f, _) -> f | None -> false in
  let filled (k : int) : bool = given k = 0. && (wants k || total > room) && longest.(k) > room / (count + 1) in
  let long = ref 0 and short = ref (3 * (count - 1)) in
  Array.iteri (fun k w -> if filled k then incr long else short := !short + (if given k > 0. then int_of_float (given k /. cols t 1.) else w)) longest;
  let share = if !long = 0 then 0 else max 10 ((room - !short) / !long) in
  let widths = List.init count (fun k -> if given k > 0. then given k else if filled k then cols t (float_of_int share) else 0.) in
  let rows =
    List.concat_map (fun ((r, k) : Doc.cell list option * int) ->
      List.init (min k 1) (fun _ -> Doc.Rule)
      @ (match r with
         | Some cs -> [ Doc.Cells (snd (List.fold_left (fun ((k, acc) : int * Doc.cell list) (c : Doc.cell) -> (k + c.span, acc @ [ { c with filled = c.span = 1 && (filled k || given k > 0.); align = (if c.span = 1 && filled k then Doc.Left else c.align) } ])) (0, []) cs)) ]
         | None -> [])) made in
  par t;
  let table : Doc.table = { centered = true; boxed = false; widths; rows } in
  block t (Doc.Table table)

(* The references: the entries cited, in the order they were, each
 * with its number. *)
and bibliography (t : t) (files : string) =
  par t;
  let entries = List.concat_map (fun (f : string) ->
    let f = String.trim f in
    match (match t.load (f ^ ".bib") with Some s -> Some s | None -> t.load f) with
    | Some s -> Bib.read s
    | None -> say t ("no file " ^ f ^ ".bib"); []) (String.split_on_char ',' files) in
  push t (if t.report then "\\chapter*{References}" else "\\section*{References}");
  run_pushed t;
  let roman = t.look.style in
  let italic : Doc.style = { roman with font = Doc.Italic } in
  List.iteri (fun (k : int) (key : string) ->
    match List.find_opt (fun (e : Bib.entry) -> e.key = key) entries with
    | None -> say t ("\\cite{" ^ key ^ "}: not in the bibliography")
    | Some e ->
        let field (name : string) : string option = match List.assoc_opt name e.fields with Some v when String.trim v <> "" -> Some v | _ -> None in
        let part (style : Doc.style) (name : string) (after : string) : Doc.inline list =
          match field name with Some v -> with_look t { style; caps = false; center = false } v @ [ Doc.Text (roman, after) ] | None -> [] in
        let where = List.concat_map (fun (name : string) -> part roman name ", ") [ "booktitle"; "journal"; "publisher"; "institution"; "organization"; "howpublished"; "edition" ] in
        let body = part roman "author" ". " @ part italic "title" ". " @ where @ part roman "year" ". " @ part roman "note" "" in
        block t (Doc.Tagged { tag = [ Doc.Text (roman, "[" ^ string_of_int (k + 1) ^ "]") ]; width = cols t 5.; body = [ Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body } ] })) (List.rev t.known.cites)

and cite_label (t : t) (key : string) : string =
  match Hashtbl.find_opt t.known.bibitems key with
  | Some l -> l
  | None ->
      if not (List.mem key t.known.cites) then t.known.cites <- key :: t.known.cites;
      let order = List.rev t.known.cites in
      let rec index (l : string list) (k : int) : int = match l with [] -> 0 | x :: rest -> if x = key then k else index rest (k + 1) in
      string_of_int (index order 1)

and command (t : t) (w : string) =
  if w <> "" && is_letter w.[0] then after_name t;
  match Hashtbl.find_opt t.macros w with
  | Some m -> expand t m
  | None ->
      let n = String.length w in
      if n > 4 && String.sub w (n - 4) 4 = "true" && Hashtbl.mem t.flags (String.sub w 0 (n - 4)) then Hashtbl.replace t.flags (String.sub w 0 (n - 4)) true
      else if n > 5 && String.sub w (n - 5) 5 = "false" && Hashtbl.mem t.flags (String.sub w 0 (n - 5)) then Hashtbl.replace t.flags (String.sub w 0 (n - 5)) false
      else if n > 2 && String.sub w 0 2 = "if" && Hashtbl.mem t.flags (String.sub w 2 (n - 2)) then (if not (Hashtbl.find t.flags (String.sub w 2 (n - 2))) then skip_branch t true)
      else builtin t w

and builtin (t : t) (w : string) =
  let style = t.look.style in
  let font (f : Doc.font) = t.look <- { t.look with style = { style with font = f }; caps = false } in
  match w with
  (* the text's own characters *)
  | "&" | "%" | "$" | "#" | "_" | "{" | "}" -> text t w
  | " " | "," | ";" | ":" | "\n" -> text t " "
  | "\\" -> ignore (star t); ignore (opt t); if t.out.line <> [] then put t Doc.Break
  | "newline" | "linebreak" -> ignore (opt t); if t.out.line <> [] then put t Doc.Break
  | "'" | "`" | "^" | "\"" | "~" | "c" | "v" ->
      let a = arg t in
      (match List.assoc_opt (w ^ a) accents with Some s -> text t s | None -> text t a)
  | "xspace" -> (match peek t with Some ('.' | ',' | ':' | ';' | '!' | '?' | '\'' | ')' | ']' | '}' | '/' | '-' | '~' | ' ' | '\n' | '\t') | None -> () | Some _ -> text t " ")
  (* the looks *)
  | "em" -> font (if style.font = Doc.Italic then Doc.Roman else Doc.Italic)
  | "it" | "itshape" | "sl" -> font Doc.Italic
  | "bf" | "bfseries" -> font Doc.Bold
  | "tt" | "ttfamily" -> font Doc.Mono
  | "rm" | "rmfamily" | "sf" | "sffamily" | "upshape" | "mdseries" -> font Doc.Roman
  | "sc" | "scshape" -> t.look <- { t.look with caps = true }
  | "underline" | "mbox" | "fbox" | "centerline" | "hbox" | "uline" -> push t ("{" ^ arg t ^ "}")
  | "makebox" | "framebox" -> ignore (opt t); ignore (opt t); push t ("{" ^ arg t ^ "}")
  | "parbox" -> ignore (opt t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "resizebox" -> ignore (star t); ignore (arg t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "scalebox" | "textcolor" | "colorbox" | "raisebox" -> ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "multirow" -> ignore (arg t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "multicolumn" ->
      let k = arg t in
      let spec = arg t in
      t.span <- (match int_of_string_opt (String.trim k) with Some k -> max 1 k | None -> 1);
      t.cell_align <- Some (if String.contains spec 'c' then Doc.Center else if String.contains spec 'r' then Doc.Right else Doc.Left);
      push t ("{" ^ arg t ^ "}")
  | "ensuremath" -> math t (arg t)
  | "textcircled" -> push t ("({" ^ arg t ^ "})")
  (* the author's notes to himself, wherever on a line: not a book's *)
  | "l" | "t" | "n" -> ignore (rest_of_line t); space t
  | "centering" -> t.look <- { t.look with center = true }
  | "begingroup" | "bgroup" -> t.groups <- t.look :: t.groups
  | "endgroup" | "egroup" -> (match t.groups with l :: rest -> t.look <- l; t.groups <- rest | [] -> ())
  (* the text's parts *)
  | "part" -> heading t (-1)
  | "chapter" -> heading t 0
  | "section" -> heading t 1
  | "subsection" -> heading t 2
  | "subsubsection" -> heading t 3
  | "paragraph" | "subparagraph" -> ignore (star t); let raw = arg t in par t; push t ("{\\bf " ^ raw ^ "}\\ \\ ")
  | "appendix" -> t.appendix <- true; t.chapter <- 0; t.section <- 0
  | "addcontentsline" ->
      ignore (arg t);
      let kind = String.trim (arg t) in
      let raw = arg t in
      let level = match kind with "part" -> -1 | "chapter" -> 0 | "section" -> 1 | "subsection" -> 2 | _ -> 3 in
      if not t.final && t.body then t.known.toc <- ((if t.report then level else max 1 level), "", raw) :: t.known.toc
  | "par" -> par t
  | "bigskip" | "medskip" | "vskip" -> par t; emit t (Doc.Space (gap t))
  | "hrule" -> par t; block t (Doc.Picture { wide = 6.; high = 0.05; marks = [ Doc.Stroke [ (0., 0.02); (6., 0.02) ] ] })
  | "begin" -> begin_env t (arg t)
  | "end" -> end_env t (arg t)
  | "item" -> item t
  | "bibitem" ->
      let label = opt t in
      let key = arg t in
      (match List.find_opt (fun (e : env) -> e.name = "thebibliography") t.envs with
       | Some e ->
           let l = match label with Some l -> l | None -> string_of_int (e.count + 1) in
           if not t.final then Hashtbl.replace t.known.bibitems key l;
           push t ("\\item[{[" ^ l ^ "]}]")
       | None -> ())
  | "caption" ->
      ignore (star t);
      ignore (opt t);
      let raw = arg t in
      (match List.find_opt (fun (e : env) -> e.outer <> None && e.name <> "itemize" && e.name <> "enumerate" && e.name <> "description") t.envs with
       | Some e ->
           let is_table = String.length e.name >= 5 && String.sub e.name 0 5 = "table" in
           if is_table then t.table <- t.table + 1 else t.figure <- t.figure + 1;
           let number = (if t.report then string_of_int t.chapter ^ "." else "") ^ string_of_int (if is_table then t.table else t.figure) in
           t.here <- number;
           let look : look = { style = Doc.plain; caps = false; center = false } in
           e.caption <- Some (Doc.Text (Doc.plain, (if is_table then "Table " else "Figure ") ^ number ^ ": ") :: with_look t look raw)
       | None -> say_once t "\\caption outside a figure")
  | "footnote" | "thanks" ->
      ignore (opt t);
      let raw = arg t in
      t.notes <- t.notes + 1;
      let number = string_of_int t.notes in
      let saved = t.out in
      let inner = with_look t { style = Doc.plain; caps = false; center = false } raw in
      t.out <- saved;
      if t.body then t.out.feet <- Doc.Footnote [ Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body = Doc.Text (Doc.plain, number ^ ". ") :: inner } ] :: t.out.feet;
      put t (Doc.Text ({ style with size = style.size - 2; shift = style.shift + 1 }, number))
  (* what names another place *)
  | "label" -> let k = arg t in if not t.final then Hashtbl.replace t.known.labels k t.here
  | "ref" | "autoref" | "cref" | "Cref" | "eqref" ->
      let k = arg t in
      (match Hashtbl.find_opt t.known.labels k with
       | Some v -> text t v
       | None -> say t ("\\ref{" ^ k ^ "} (no such label)"); text t "??")
  | "pageref" -> ignore (arg t); say_once t "\\pageref (a page's number is not known here)"; text t "?"
  | "cite" | "citep" | "citet" | "nocite" ->
      let note = opt t in
      let keys = List.map String.trim (String.split_on_char ',' (arg t)) in
      let labels = List.map (cite_label t) keys in
      if w <> "nocite" then text t ("[" ^ String.concat ", " labels ^ (match note with Some n -> ", " ^ words (inlines_of t n) | None -> "") ^ "]")
  | "bibliography" -> bibliography t (arg t)
  | "url" | "path" | "nolinkurl" ->
      let raw = arg t in
      let b = Buffer.create (String.length raw) in
      String.iteri (fun i c -> if not (c = '\\' && i + 1 < String.length raw && (match raw.[i + 1] with '%' | '#' | '_' | '&' | '~' -> true | _ -> false)) then Buffer.add_char b c) raw;
      put t (Doc.Text (mono_of style, Buffer.contents b))
  | "href" -> ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "verb" ->
      ignore (star t);
      (match peek t with
       | Some d -> advance t; put t (Doc.Text (mono_of style, until t (String.make 1 d)))
       | None -> ())
  | "tableofcontents" ->
      par t;
      push t (if t.report then "\\chapter*{Contents}" else "\\section*{Contents}");
      run_pushed t;
      List.iter (fun ((level, number, raw) : int * string * string) ->
        if level <= 2 then begin
          let st : Doc.style = { font = (if level <= 0 then Doc.Bold else Doc.Roman); size = 0; shift = 0 } in
          let body = (if number = "" then [] else [ Doc.Text (st, number ^ "\xc2\xa0\xc2\xa0") ]) @ with_look t { style = st; caps = false; center = false } raw in
          let p = Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body } in
          if level <= 0 then emit t (Doc.Space (gap t));
          emit t (if level <= 0 then p else Doc.Indent (cols t (float_of_int (3 * level)), [ p ]))
        end) (List.rev t.known.toc);
      emit t (Doc.Space 1.)
  | "nowebindex" ->
      par t;
      let names = List.sort compare (Hashtbl.fold (fun (k : string) (_ : int list) (acc : string list) -> k :: acc) t.known.defs []) in
      let italic : Doc.style = { font = Doc.Italic; size = -1; shift = 0 } in
      List.iter (fun (n : string) ->
        let defs = match Hashtbl.find_opt t.known.defs n with Some l -> l | None -> [] in
        let body = [ Doc.Text (italic, "\xe2\x80\xb9") ] @ with_look t { style = italic; caps = false; center = false } n @ [ Doc.Text (italic, "\xe2\x80\xba"); Doc.Text ({ italic with font = Doc.Roman }, "  " ^ numbers defs) ] in
        emit t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body })) names
  | "includegraphics" ->
      ignore (opt t);
      let f = arg t in
      say t ("a picture from a file (" ^ f ^ ")");
      put t (Doc.Text (style, "[picture: " ^ Filename.basename f ^ "]"))
  | "VerbatimInput" | "verbatiminput" | "lstinputlisting" ->
      ignore (opt t);
      let f = arg t in
      (match t.load f with Some s -> verbatim t (-1) s | None -> say t ("no file " ^ f))
  | "input" | "include" -> file t (String.trim (arg t))
  (* the title *)
  | "title" -> t.title <- arg t
  | "author" -> t.author <- arg t
  | "date" -> t.date <- arg t
  | "maketitle" ->
      par t;
      push t ("\\begin{center}{\\Large\\bf " ^ t.title ^ "\\par}\\bigskip{" ^ t.author ^ "\\par}" ^ (if String.trim t.date = "" then "" else "\\bigskip{" ^ t.date ^ "\\par}") ^ "\\end{center}\\bigskip ")
  (* what is defined *)
  | "newcommand" | "renewcommand" | "DeclareRobustCommand" -> define t true
  | "providecommand" -> define t false
  | "def" | "gdef" | "edef" ->
      blanks t;
      if peek t = Some '\\' then begin
        advance t;
        let n = name t in
        let pattern = match t.input with f :: _ -> (let e = match String.index_from_opt f.s f.i '{' with Some e -> e | None -> String.length f.s in let p = String.sub f.s f.i (e - f.i) in skip t (e - f.i); p) | [] -> "" in
        let args = String.fold_left (fun k c -> if c = '#' then k + 1 else k) 0 pattern in
        if String.exists (fun c -> not (c = '#' || is_digit c || is_blank c)) pattern then say t ("\\def\\" ^ n ^ " with a pattern");
        Hashtbl.replace t.macros n { args; default = None; body = arg t }
      end
  | "let" ->
      blanks t;
      let a = named (arg t) in
      blanks t;
      if peek t = Some '=' then advance t;
      let b = named (arg t) in
      (match Hashtbl.find_opt t.macros b with Some m -> Hashtbl.replace t.macros a m | None -> ())
  | "newif" ->
      blanks t;
      let n = named (arg t) in
      if String.length n > 2 then Hashtbl.replace t.flags (String.sub n 2 (String.length n - 2)) false
  | "newenvironment" | "renewenvironment" ->
      let n = arg t in
      let args = match opt t with Some k -> (match int_of_string_opt (String.trim k) with Some k -> k | None -> 0) | None -> 0 in
      let default = opt t in
      let body = arg t in
      let after = arg t in
      Hashtbl.replace t.environments n ({ args; default; body }, after)
  | "DefineVerbatimEnvironment" -> let n = arg t in ignore (arg t); ignore (arg t); Hashtbl.replace t.verbatims n true
  | "iftrue" -> ()
  | "iffalse" -> skip_branch t true
  | "else" -> skip_branch t false
  | "fi" -> ()
  | "(" -> math t (until t "\\)")
  | "[" -> display t (until t "\\]")
  | _ ->
      (match List.assoc_opt w sizes, List.assoc_opt w with_text, List.assoc_opt w symbols, List.assoc_opt w nothing with
       | Some size, _, _, _ -> t.look <- { t.look with style = { style with size } }
       | None, Some declaration, _, _ -> push t ("{\\" ^ declaration ^ " " ^ arg t ^ "}")
       | None, None, Some s, _ -> text t s
       | None, None, None, Some takes ->
           String.iter (fun c -> match c with 'm' -> ignore (arg t) | 'o' -> ignore (opt t) | _ -> ignore (star t)) takes;
           if w = "vspace" || w = "smallskip" then par t
       | None, None, None, None ->
           if String.length w > 2 && String.sub w 0 2 = "if" then begin say_once t ("\\" ^ w ^ " (a condition not declared: taken as false)"); skip_branch t true end
           else say_once t ("\\" ^ w))

(* ---------------------------------------------------------------- *)
(* A document *)
(* ---------------------------------------------------------------- *)

let once (paper : bool) (load : string -> string option) (known : known) (final : bool) (source : string) : Doc.block list * (int * string) list =
  let contains (s : string) (w : string) : bool =
    let n = String.length s and m = String.length w in
    let rec go (i : int) : bool = i + m <= n && (String.sub s i m = w || go (i + 1)) in
    go 0 in
  let t = {
    paper; load; known; final; input = [ { s = source; i = 0; stop = false; file = ""; line = 1; counts = true } ]; out = fresh ();
    look = { style = Doc.plain; caps = false; center = false }; groups = []; envs = []; macros = Hashtbl.create 64; flags = Hashtbl.create 16; environments = Hashtbl.create 8;
    verbatims = Hashtbl.create 8; body = not (contains source "\\begin{document}"); said = []; unknown = Hashtbl.create 16; report = contains source "{report}" || contains source "{book}";
    appendix = false; chapter = 0; section = 0; subsection = 0; subsubsection = 0; figure = 0; table = 0; notes = 0; chunk = 0; here = ""; title = ""; author = ""; date = "";
    span = 1; cell_align = None } in
  List.iter (fun (n : string) -> Hashtbl.replace t.verbatims n false) [ "verbatim"; "verbatim*"; "Verbatim"; "lstlisting"; "alltt" ];
  Hashtbl.replace t.verbatims "vdiagram" true;
  run t;
  par t;
  (* (what was opened and not closed is closed) *)
  List.iter (fun (e : env) -> if List.memq e t.envs then end_env t e.name) t.envs;
  (List.rev t.out.blocks, List.rev t.said)

let read (paper : bool) (load : string -> string option) (source : string) : Doc.t * (int * string) list =
  let known = { labels = Hashtbl.create 64; toc = []; defs = Hashtbl.create 64; uses = Hashtbl.create 64; cites = []; bibitems = Hashtbl.create 16 } in
  ignore (once paper load known false source);
  let body, said = once paper load known true source in
  ({ header = ("", "", ""); width = (if paper then 86.4 else 60.); margin = 0.; sub = 0.; body }, said)
