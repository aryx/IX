(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex_names.mli *)

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
