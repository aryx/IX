(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: mini-chrome's libs/fonts/Glyph_names.ml (docs/plans/plan_pdf.md) *)

(* See Glyph_names.mli *)

(* Adobe's standard encoding: a code's glyph, "" where it has none *)
let standard_encoding : string array =
  [|
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    "space"; "exclam"; "quotedbl"; "numbersign"; "dollar"; "percent"; "ampersand"; "quoteright";
    "parenleft"; "parenright"; "asterisk"; "plus"; "comma"; "hyphen"; "period"; "slash";
    "zero"; "one"; "two"; "three"; "four"; "five"; "six"; "seven";
    "eight"; "nine"; "colon"; "semicolon"; "less"; "equal"; "greater"; "question";
    "at"; "A"; "B"; "C"; "D"; "E"; "F"; "G";
    "H"; "I"; "J"; "K"; "L"; "M"; "N"; "O";
    "P"; "Q"; "R"; "S"; "T"; "U"; "V"; "W";
    "X"; "Y"; "Z"; "bracketleft"; "backslash"; "bracketright"; "asciicircum"; "underscore";
    "quoteleft"; "a"; "b"; "c"; "d"; "e"; "f"; "g";
    "h"; "i"; "j"; "k"; "l"; "m"; "n"; "o";
    "p"; "q"; "r"; "s"; "t"; "u"; "v"; "w";
    "x"; "y"; "z"; "braceleft"; "bar"; "braceright"; "asciitilde"; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; "exclamdown"; "cent"; "sterling"; "fraction"; "yen"; "florin"; "section";
    "currency"; "quotesingle"; "quotedblleft"; "guillemotleft"; "guilsinglleft"; "guilsinglright"; "fi"; "fl";
    ""; "endash"; "dagger"; "daggerdbl"; "periodcentered"; ""; "paragraph"; "bullet";
    "quotesinglbase"; "quotedblbase"; "quotedblright"; "guillemotright"; "ellipsis"; "perthousand"; ""; "questiondown";
    ""; "grave"; "acute"; "circumflex"; "tilde"; "macron"; "breve"; "dotaccent";
    "dieresis"; ""; "ring"; "cedilla"; ""; "hungarumlaut"; "ogonek"; "caron";
    "emdash"; ""; ""; ""; ""; ""; ""; "";
    ""; ""; ""; ""; ""; ""; ""; "";
    ""; "AE"; ""; "ordfeminine"; ""; ""; ""; "";
    "Lslash"; "Oslash"; "OE"; "ordmasculine"; ""; ""; ""; "";
    ""; "ae"; ""; ""; ""; "dotlessi"; ""; "";
    "lslash"; "oslash"; "oe"; "germandbls"; ""; ""; ""; "";
  |]

(* a code's character, in Windows' encoding (code page 1252) and in the Macintosh's *)
let win_ansi : int array =
  [|
    0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000;
    0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000;
    0x0020; 0x0021; 0x0022; 0x0023; 0x0024; 0x0025; 0x0026; 0x0027; 0x0028; 0x0029; 0x002a; 0x002b; 0x002c; 0x002d; 0x002e; 0x002f;
    0x0030; 0x0031; 0x0032; 0x0033; 0x0034; 0x0035; 0x0036; 0x0037; 0x0038; 0x0039; 0x003a; 0x003b; 0x003c; 0x003d; 0x003e; 0x003f;
    0x0040; 0x0041; 0x0042; 0x0043; 0x0044; 0x0045; 0x0046; 0x0047; 0x0048; 0x0049; 0x004a; 0x004b; 0x004c; 0x004d; 0x004e; 0x004f;
    0x0050; 0x0051; 0x0052; 0x0053; 0x0054; 0x0055; 0x0056; 0x0057; 0x0058; 0x0059; 0x005a; 0x005b; 0x005c; 0x005d; 0x005e; 0x005f;
    0x0060; 0x0061; 0x0062; 0x0063; 0x0064; 0x0065; 0x0066; 0x0067; 0x0068; 0x0069; 0x006a; 0x006b; 0x006c; 0x006d; 0x006e; 0x006f;
    0x0070; 0x0071; 0x0072; 0x0073; 0x0074; 0x0075; 0x0076; 0x0077; 0x0078; 0x0079; 0x007a; 0x007b; 0x007c; 0x007d; 0x007e; 0x007f;
    0x20ac; 0x0000; 0x201a; 0x0192; 0x201e; 0x2026; 0x2020; 0x2021; 0x02c6; 0x2030; 0x0160; 0x2039; 0x0152; 0x0000; 0x017d; 0x0000;
    0x0000; 0x2018; 0x2019; 0x201c; 0x201d; 0x2022; 0x2013; 0x2014; 0x02dc; 0x2122; 0x0161; 0x203a; 0x0153; 0x0000; 0x017e; 0x0178;
    0x00a0; 0x00a1; 0x00a2; 0x00a3; 0x00a4; 0x00a5; 0x00a6; 0x00a7; 0x00a8; 0x00a9; 0x00aa; 0x00ab; 0x00ac; 0x00ad; 0x00ae; 0x00af;
    0x00b0; 0x00b1; 0x00b2; 0x00b3; 0x00b4; 0x00b5; 0x00b6; 0x00b7; 0x00b8; 0x00b9; 0x00ba; 0x00bb; 0x00bc; 0x00bd; 0x00be; 0x00bf;
    0x00c0; 0x00c1; 0x00c2; 0x00c3; 0x00c4; 0x00c5; 0x00c6; 0x00c7; 0x00c8; 0x00c9; 0x00ca; 0x00cb; 0x00cc; 0x00cd; 0x00ce; 0x00cf;
    0x00d0; 0x00d1; 0x00d2; 0x00d3; 0x00d4; 0x00d5; 0x00d6; 0x00d7; 0x00d8; 0x00d9; 0x00da; 0x00db; 0x00dc; 0x00dd; 0x00de; 0x00df;
    0x00e0; 0x00e1; 0x00e2; 0x00e3; 0x00e4; 0x00e5; 0x00e6; 0x00e7; 0x00e8; 0x00e9; 0x00ea; 0x00eb; 0x00ec; 0x00ed; 0x00ee; 0x00ef;
    0x00f0; 0x00f1; 0x00f2; 0x00f3; 0x00f4; 0x00f5; 0x00f6; 0x00f7; 0x00f8; 0x00f9; 0x00fa; 0x00fb; 0x00fc; 0x00fd; 0x00fe; 0x00ff;
  |]

let mac_roman : int array =
  [|
    0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000;
    0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000; 0x0000;
    0x0020; 0x0021; 0x0022; 0x0023; 0x0024; 0x0025; 0x0026; 0x0027; 0x0028; 0x0029; 0x002a; 0x002b; 0x002c; 0x002d; 0x002e; 0x002f;
    0x0030; 0x0031; 0x0032; 0x0033; 0x0034; 0x0035; 0x0036; 0x0037; 0x0038; 0x0039; 0x003a; 0x003b; 0x003c; 0x003d; 0x003e; 0x003f;
    0x0040; 0x0041; 0x0042; 0x0043; 0x0044; 0x0045; 0x0046; 0x0047; 0x0048; 0x0049; 0x004a; 0x004b; 0x004c; 0x004d; 0x004e; 0x004f;
    0x0050; 0x0051; 0x0052; 0x0053; 0x0054; 0x0055; 0x0056; 0x0057; 0x0058; 0x0059; 0x005a; 0x005b; 0x005c; 0x005d; 0x005e; 0x005f;
    0x0060; 0x0061; 0x0062; 0x0063; 0x0064; 0x0065; 0x0066; 0x0067; 0x0068; 0x0069; 0x006a; 0x006b; 0x006c; 0x006d; 0x006e; 0x006f;
    0x0070; 0x0071; 0x0072; 0x0073; 0x0074; 0x0075; 0x0076; 0x0077; 0x0078; 0x0079; 0x007a; 0x007b; 0x007c; 0x007d; 0x007e; 0x007f;
    0x00c4; 0x00c5; 0x00c7; 0x00c9; 0x00d1; 0x00d6; 0x00dc; 0x00e1; 0x00e0; 0x00e2; 0x00e4; 0x00e3; 0x00e5; 0x00e7; 0x00e9; 0x00e8;
    0x00ea; 0x00eb; 0x00ed; 0x00ec; 0x00ee; 0x00ef; 0x00f1; 0x00f3; 0x00f2; 0x00f4; 0x00f6; 0x00f5; 0x00fa; 0x00f9; 0x00fb; 0x00fc;
    0x2020; 0x00b0; 0x00a2; 0x00a3; 0x00a7; 0x2022; 0x00b6; 0x00df; 0x00ae; 0x00a9; 0x2122; 0x00b4; 0x00a8; 0x2260; 0x00c6; 0x00d8;
    0x221e; 0x00b1; 0x2264; 0x2265; 0x00a5; 0x00b5; 0x2202; 0x2211; 0x220f; 0x03c0; 0x222b; 0x00aa; 0x00ba; 0x03a9; 0x00e6; 0x00f8;
    0x00bf; 0x00a1; 0x00ac; 0x221a; 0x0192; 0x2248; 0x2206; 0x00ab; 0x00bb; 0x2026; 0x00a0; 0x00c0; 0x00c3; 0x00d5; 0x0152; 0x0153;
    0x2013; 0x2014; 0x201c; 0x201d; 0x2018; 0x2019; 0x00f7; 0x25ca; 0x00ff; 0x0178; 0x2044; 0x20ac; 0x2039; 0x203a; 0xfb01; 0xfb02;
    0x2021; 0x00b7; 0x201a; 0x201e; 0x2030; 0x00c2; 0x00ca; 0x00c1; 0x00cb; 0x00c8; 0x00cd; 0x00ce; 0x00cf; 0x00cc; 0x00d3; 0x00d4;
    0xf8ff; 0x00d2; 0x00da; 0x00db; 0x00d9; 0x0131; 0x02c6; 0x02dc; 0x00af; 0x02d8; 0x02d9; 0x02da; 0x00b8; 0x02dd; 0x02db; 0x02c7;
  |]

(* CFF's 391 standard strings: the names a font need not spell *)
let cff_strings : string array =
  [|
    ""; "space"; "exclam"; "quotedbl"; "numbersign"; "dollar"; "percent"; "ampersand";
    "quoteright"; "parenleft"; "parenright"; "asterisk"; "plus"; "comma"; "hyphen"; "period";
    "slash"; "zero"; "one"; "two"; "three"; "four"; "five"; "six";
    "seven"; "eight"; "nine"; "colon"; "semicolon"; "less"; "equal"; "greater";
    "question"; "at"; "A"; "B"; "C"; "D"; "E"; "F";
    "G"; "H"; "I"; "J"; "K"; "L"; "M"; "N";
    "O"; "P"; "Q"; "R"; "S"; "T"; "U"; "V";
    "W"; "X"; "Y"; "Z"; "bracketleft"; "backslash"; "bracketright"; "asciicircum";
    "underscore"; "quoteleft"; "a"; "b"; "c"; "d"; "e"; "f";
    "g"; "h"; "i"; "j"; "k"; "l"; "m"; "n";
    "o"; "p"; "q"; "r"; "s"; "t"; "u"; "v";
    "w"; "x"; "y"; "z"; "braceleft"; "bar"; "braceright"; "asciitilde";
    "exclamdown"; "cent"; "sterling"; "fraction"; "yen"; "florin"; "section"; "currency";
    "quotesingle"; "quotedblleft"; "guillemotleft"; "guilsinglleft"; "guilsinglright"; "fi"; "fl"; "endash";
    "dagger"; "daggerdbl"; "periodcentered"; "paragraph"; "bullet"; "quotesinglbase"; "quotedblbase"; "quotedblright";
    "guillemotright"; "ellipsis"; "perthousand"; "questiondown"; "grave"; "acute"; "circumflex"; "tilde";
    "macron"; "breve"; "dotaccent"; "dieresis"; "ring"; "cedilla"; "hungarumlaut"; "ogonek";
    "caron"; "emdash"; "AE"; "ordfeminine"; "Lslash"; "Oslash"; "OE"; "ordmasculine";
    "ae"; "dotlessi"; "lslash"; "oslash"; "oe"; "germandbls"; "onesuperior"; "logicalnot";
    "mu"; "trademark"; "Eth"; "onehalf"; "plusminus"; "Thorn"; "onequarter"; "divide";
    "brokenbar"; "degree"; "thorn"; "threequarters"; "twosuperior"; "registered"; "minus"; "eth";
    "multiply"; "threesuperior"; "copyright"; "Aacute"; "Acircumflex"; "Adieresis"; "Agrave"; "Aring";
    "Atilde"; "Ccedilla"; "Eacute"; "Ecircumflex"; "Edieresis"; "Egrave"; "Iacute"; "Icircumflex";
    "Idieresis"; "Igrave"; "Ntilde"; "Oacute"; "Ocircumflex"; "Odieresis"; "Ograve"; "Otilde";
    "Scaron"; "Uacute"; "Ucircumflex"; "Udieresis"; "Ugrave"; "Yacute"; "Ydieresis"; "Zcaron";
    "aacute"; "acircumflex"; "adieresis"; "agrave"; "aring"; "atilde"; "ccedilla"; "eacute";
    "ecircumflex"; "edieresis"; "egrave"; "iacute"; "icircumflex"; "idieresis"; "igrave"; "ntilde";
    "oacute"; "ocircumflex"; "odieresis"; "ograve"; "otilde"; "scaron"; "uacute"; "ucircumflex";
    "udieresis"; "ugrave"; "yacute"; "ydieresis"; "zcaron"; "exclamsmall"; "Hungarumlautsmall"; "dollaroldstyle";
    "dollarsuperior"; "ampersandsmall"; "Acutesmall"; "parenleftsuperior"; "parenrightsuperior"; "twodotenleader"; "onedotenleader"; "zerooldstyle";
    "oneoldstyle"; "twooldstyle"; "threeoldstyle"; "fouroldstyle"; "fiveoldstyle"; "sixoldstyle"; "sevenoldstyle"; "eightoldstyle";
    "nineoldstyle"; "commasuperior"; "threequartersemdash"; "periodsuperior"; "questionsmall"; "asuperior"; "bsuperior"; "centsuperior";
    "dsuperior"; "esuperior"; "isuperior"; "lsuperior"; "msuperior"; "nsuperior"; "osuperior"; "rsuperior";
    "ssuperior"; "tsuperior"; "ff"; "ffi"; "ffl"; "parenleftinferior"; "parenrightinferior"; "Circumflexsmall";
    "hyphensuperior"; "Gravesmall"; "Asmall"; "Bsmall"; "Csmall"; "Dsmall"; "Esmall"; "Fsmall";
    "Gsmall"; "Hsmall"; "Ismall"; "Jsmall"; "Ksmall"; "Lsmall"; "Msmall"; "Nsmall";
    "Osmall"; "Psmall"; "Qsmall"; "Rsmall"; "Ssmall"; "Tsmall"; "Usmall"; "Vsmall";
    "Wsmall"; "Xsmall"; "Ysmall"; "Zsmall"; "colonmonetary"; "onefitted"; "rupiah"; "Tildesmall";
    "exclamdownsmall"; "centoldstyle"; "Lslashsmall"; "Scaronsmall"; "Zcaronsmall"; "Dieresissmall"; "Brevesmall"; "Caronsmall";
    "Dotaccentsmall"; "Macronsmall"; "figuredash"; "hypheninferior"; "Ogoneksmall"; "Ringsmall"; "Cedillasmall"; "questiondownsmall";
    "oneeighth"; "threeeighths"; "fiveeighths"; "seveneighths"; "onethird"; "twothirds"; "zerosuperior"; "foursuperior";
    "fivesuperior"; "sixsuperior"; "sevensuperior"; "eightsuperior"; "ninesuperior"; "zeroinferior"; "oneinferior"; "twoinferior";
    "threeinferior"; "fourinferior"; "fiveinferior"; "sixinferior"; "seveninferior"; "eightinferior"; "nineinferior"; "centinferior";
    "dollarinferior"; "periodinferior"; "commainferior"; "Agravesmall"; "Aacutesmall"; "Acircumflexsmall"; "Atildesmall"; "Adieresissmall";
    "Aringsmall"; "AEsmall"; "Ccedillasmall"; "Egravesmall"; "Eacutesmall"; "Ecircumflexsmall"; "Edieresissmall"; "Igravesmall";
    "Iacutesmall"; "Icircumflexsmall"; "Idieresissmall"; "Ethsmall"; "Ntildesmall"; "Ogravesmall"; "Oacutesmall"; "Ocircumflexsmall";
    "Otildesmall"; "Odieresissmall"; "OEsmall"; "Oslashsmall"; "Ugravesmall"; "Uacutesmall"; "Ucircumflexsmall"; "Udieresissmall";
    "Yacutesmall"; "Thornsmall"; "Ydieresissmall"; "001.000"; "001.001"; "001.002"; "001.003"; "Black";
    "Bold"; "Book"; "Light"; "Medium"; "Regular"; "Roman"; "Semibold";
  |]

(* a glyph's name and its character: the part of Adobe's glyph list
 * that these encodings and the usual mathematics need *)
let named : (string * int) array =
  [|
    ("A", 0x0041); ("AE", 0x00c6); ("AEsmall", 0xf7e6); ("Aacute", 0x00c1); ("Aacutesmall", 0xf7e1);
    ("Acircumflex", 0x00c2); ("Acircumflexsmall", 0xf7e2); ("Acutesmall", 0xf7b4); ("Adieresis", 0x00c4); ("Adieresissmall", 0xf7e4);
    ("Agrave", 0x00c0); ("Agravesmall", 0xf7e0); ("Aring", 0x00c5); ("Aringsmall", 0xf7e5); ("Asmall", 0xf761);
    ("Atilde", 0x00c3); ("Atildesmall", 0xf7e3); ("B", 0x0042); ("Brevesmall", 0xf6f4); ("Bsmall", 0xf762);
    ("C", 0x0043); ("Caronsmall", 0xf6f5); ("Ccedilla", 0x00c7); ("Ccedillasmall", 0xf7e7); ("Cedillasmall", 0xf7b8);
    ("Circumflexsmall", 0xf6f6); ("Csmall", 0xf763); ("D", 0x0044); ("Delta", 0x2206); ("Dieresissmall", 0xf7a8);
    ("Dotaccentsmall", 0xf6f7); ("Dsmall", 0xf764); ("E", 0x0045); ("Eacute", 0x00c9); ("Eacutesmall", 0xf7e9);
    ("Ecircumflex", 0x00ca); ("Ecircumflexsmall", 0xf7ea); ("Edieresis", 0x00cb); ("Edieresissmall", 0xf7eb); ("Egrave", 0x00c8);
    ("Egravesmall", 0xf7e8); ("Esmall", 0xf765); ("Eth", 0x00d0); ("Ethsmall", 0xf7f0); ("Euro", 0x20ac);
    ("F", 0x0046); ("Fsmall", 0xf766); ("G", 0x0047); ("Gamma", 0x0393); ("Gravesmall", 0xf760);
    ("Gsmall", 0xf767); ("H", 0x0048); ("Hsmall", 0xf768); ("Hungarumlautsmall", 0xf6f8); ("I", 0x0049);
    ("Iacute", 0x00cd); ("Iacutesmall", 0xf7ed); ("Icircumflex", 0x00ce); ("Icircumflexsmall", 0xf7ee); ("Idieresis", 0x00cf);
    ("Idieresissmall", 0xf7ef); ("Igrave", 0x00cc); ("Igravesmall", 0xf7ec); ("Ismall", 0xf769); ("J", 0x004a);
    ("Jsmall", 0xf76a); ("K", 0x004b); ("Ksmall", 0xf76b); ("L", 0x004c); ("Lambda", 0x039b);
    ("Lslash", 0x0141); ("Lslashsmall", 0xf6f9); ("Lsmall", 0xf76c); ("M", 0x004d); ("Macronsmall", 0xf7af);
    ("Msmall", 0xf76d); ("N", 0x004e); ("Nsmall", 0xf76e); ("Ntilde", 0x00d1); ("Ntildesmall", 0xf7f1);
    ("O", 0x004f); ("OE", 0x0152); ("OEsmall", 0xf6fa); ("Oacute", 0x00d3); ("Oacutesmall", 0xf7f3);
    ("Ocircumflex", 0x00d4); ("Ocircumflexsmall", 0xf7f4); ("Odieresis", 0x00d6); ("Odieresissmall", 0xf7f6); ("Ogoneksmall", 0xf6fb);
    ("Ograve", 0x00d2); ("Ogravesmall", 0xf7f2); ("Omega", 0x2126); ("Omegagreek", 0x03a9); ("Oslash", 0x00d8);
    ("Oslashsmall", 0xf7f8); ("Osmall", 0xf76f); ("Otilde", 0x00d5); ("Otildesmall", 0xf7f5); ("P", 0x0050);
    ("Phi", 0x03a6); ("Psi", 0x03a8); ("Psmall", 0xf770); ("Q", 0x0051); ("Qsmall", 0xf771);
    ("R", 0x0052); ("Ringsmall", 0xf6fc); ("Rsmall", 0xf772); ("S", 0x0053); ("Scaron", 0x0160);
    ("Scaronsmall", 0xf6fd); ("Sigma", 0x03a3); ("Ssmall", 0xf773); ("T", 0x0054); ("Theta", 0x0398);
    ("Thorn", 0x00de); ("Thornsmall", 0xf7fe); ("Tildesmall", 0xf6fe); ("Tsmall", 0xf774); ("U", 0x0055);
    ("Uacute", 0x00da); ("Uacutesmall", 0xf7fa); ("Ucircumflex", 0x00db); ("Ucircumflexsmall", 0xf7fb); ("Udieresis", 0x00dc);
    ("Udieresissmall", 0xf7fc); ("Ugrave", 0x00d9); ("Ugravesmall", 0xf7f9); ("Usmall", 0xf775); ("V", 0x0056);
    ("Vsmall", 0xf776); ("W", 0x0057); ("Wsmall", 0xf777); ("X", 0x0058); ("Xsmall", 0xf778);
    ("Y", 0x0059); ("Yacute", 0x00dd); ("Yacutesmall", 0xf7fd); ("Ydieresis", 0x0178); ("Ydieresissmall", 0xf7ff);
    ("Ysmall", 0xf779); ("Z", 0x005a); ("Zcaron", 0x017d); ("Zcaronsmall", 0xf6ff); ("Zsmall", 0xf77a);
    ("a", 0x0061); ("aacute", 0x00e1); ("acircumflex", 0x00e2); ("acute", 0x00b4); ("adieresis", 0x00e4);
    ("ae", 0x00e6); ("agrave", 0x00e0); ("alpha", 0x03b1); ("ampersand", 0x0026); ("ampersandsmall", 0xf726);
    ("apple", 0xf8ff); ("approxequal", 0x2248); ("aring", 0x00e5); ("arrowdown", 0x2193); ("arrowleft", 0x2190);
    ("arrowright", 0x2192); ("arrowup", 0x2191); ("asciicircum", 0x005e); ("asciitilde", 0x007e); ("asterisk", 0x002a);
    ("asuperior", 0xf6e9); ("at", 0x0040); ("atilde", 0x00e3); ("b", 0x0062); ("backslash", 0x005c);
    ("bar", 0x007c); ("beta", 0x03b2); ("braceleft", 0x007b); ("braceright", 0x007d); ("bracketleft", 0x005b);
    ("bracketright", 0x005d); ("breve", 0x02d8); ("brokenbar", 0x00a6); ("bsuperior", 0xf6ea); ("bullet", 0x2022);
    ("c", 0x0063); ("caron", 0x02c7); ("ccedilla", 0x00e7); ("cedilla", 0x00b8); ("cent", 0x00a2);
    ("centinferior", 0xf6df); ("centoldstyle", 0xf7a2); ("centsuperior", 0xf6e0); ("circumflex", 0x02c6); ("colon", 0x003a);
    ("colonmonetary", 0x20a1); ("comma", 0x002c); ("commainferior", 0xf6e1); ("commasuperior", 0xf6e2); ("controlDEL", 0x007f);
    ("copyright", 0x00a9); ("currency", 0x00a4); ("d", 0x0064); ("dagger", 0x2020); ("daggerdbl", 0x2021);
    ("degree", 0x00b0); ("delta", 0x03b4); ("dieresis", 0x00a8); ("divide", 0x00f7); ("dollar", 0x0024);
    ("dollarinferior", 0xf6e3); ("dollaroldstyle", 0xf724); ("dollarsuperior", 0xf6e4); ("dotaccent", 0x02d9); ("dotlessi", 0x0131);
    ("dotlessj", 0xf6be); ("dsuperior", 0xf6eb); ("e", 0x0065); ("eacute", 0x00e9); ("ecircumflex", 0x00ea);
    ("edieresis", 0x00eb); ("egrave", 0x00e8); ("eight", 0x0038); ("eightinferior", 0x2088); ("eightoldstyle", 0xf738);
    ("eightsuperior", 0x2078); ("ellipsis", 0x2026); ("emdash", 0x2014); ("endash", 0x2013); ("epsilon", 0x03b5);
    ("equal", 0x003d); ("esuperior", 0xf6ec); ("eth", 0x00f0); ("exclam", 0x0021); ("exclamdown", 0x00a1);
    ("exclamdownsmall", 0xf7a1); ("exclamsmall", 0xf721); ("f", 0x0066); ("ff", 0xfb00); ("ffi", 0xfb03);
    ("ffl", 0xfb04); ("fi", 0xfb01); ("figuredash", 0x2012); ("five", 0x0035); ("fiveeighths", 0x215d);
    ("fiveinferior", 0x2085); ("fiveoldstyle", 0xf735); ("fivesuperior", 0x2075); ("fl", 0xfb02); ("florin", 0x0192);
    ("four", 0x0034); ("fourinferior", 0x2084); ("fouroldstyle", 0xf734); ("foursuperior", 0x2074); ("fraction", 0x2044);
    ("g", 0x0067); ("gamma", 0x03b3); ("germandbls", 0x00df); ("grave", 0x0060); ("greater", 0x003e);
    ("greaterequal", 0x2265); ("guillemotleft", 0x00ab); ("guillemotright", 0x00bb); ("guilsinglleft", 0x2039); ("guilsinglright", 0x203a);
    ("h", 0x0068); ("hungarumlaut", 0x02dd); ("hyphen", 0x002d); ("hypheninferior", 0xf6e5); ("hyphensuperior", 0xf6e6);
    ("i", 0x0069); ("iacute", 0x00ed); ("icircumflex", 0x00ee); ("idieresis", 0x00ef); ("igrave", 0x00ec);
    ("infinity", 0x221e); ("integral", 0x222b); ("isuperior", 0xf6ed); ("j", 0x006a); ("k", 0x006b);
    ("l", 0x006c); ("lambda", 0x03bb); ("less", 0x003c); ("lessequal", 0x2264); ("logicalnot", 0x00ac);
    ("longs", 0x017f); ("lozenge", 0x25ca); ("lslash", 0x0142); ("lsuperior", 0xf6ee); ("m", 0x006d);
    ("macron", 0x00af); ("minus", 0x2212); ("msuperior", 0xf6ef); ("mu", 0x00b5); ("multiply", 0x00d7);
    ("n", 0x006e); ("nbspace", 0x00a0); ("nine", 0x0039); ("nineinferior", 0x2089); ("nineoldstyle", 0xf739);
    ("ninesuperior", 0x2079); ("notequal", 0x2260); ("nsuperior", 0x207f); ("ntilde", 0x00f1); ("numbersign", 0x0023);
    ("o", 0x006f); ("oacute", 0x00f3); ("ocircumflex", 0x00f4); ("odieresis", 0x00f6); ("oe", 0x0153);
    ("ogonek", 0x02db); ("ograve", 0x00f2); ("omega", 0x03c9); ("one", 0x0031); ("onedotenleader", 0x2024);
    ("oneeighth", 0x215b); ("onefitted", 0xf6dc); ("onehalf", 0x00bd); ("oneinferior", 0x2081); ("oneoldstyle", 0xf731);
    ("onequarter", 0x00bc); ("onesuperior", 0x00b9); ("onethird", 0x2153); ("ordfeminine", 0x00aa); ("ordmasculine", 0x00ba);
    ("oslash", 0x00f8); ("osuperior", 0xf6f0); ("otilde", 0x00f5); ("p", 0x0070); ("paragraph", 0x00b6);
    ("parenleft", 0x0028); ("parenleftinferior", 0x208d); ("parenleftsuperior", 0x207d); ("parenright", 0x0029); ("parenrightinferior", 0x208e);
    ("parenrightsuperior", 0x207e); ("partialdiff", 0x2202); ("percent", 0x0025); ("period", 0x002e); ("periodcentered", 0x00b7);
    ("periodinferior", 0xf6e7); ("periodsuperior", 0xf6e8); ("perthousand", 0x2030); ("phi", 0x03c6); ("pi", 0x03c0);
    ("plus", 0x002b); ("plusminus", 0x00b1); ("product", 0x220f); ("q", 0x0071); ("question", 0x003f);
    ("questiondown", 0x00bf); ("questiondownsmall", 0xf7bf); ("questionsmall", 0xf73f); ("quotedbl", 0x0022); ("quotedblbase", 0x201e);
    ("quotedblleft", 0x201c); ("quotedblright", 0x201d); ("quoteleft", 0x2018); ("quoteright", 0x2019); ("quotesinglbase", 0x201a);
    ("quotesingle", 0x0027); ("r", 0x0072); ("radical", 0x221a); ("registered", 0x00ae); ("ring", 0x02da);
    ("rsuperior", 0xf6f1); ("rupiah", 0xf6dd); ("s", 0x0073); ("scaron", 0x0161); ("section", 0x00a7);
    ("semicolon", 0x003b); ("seven", 0x0037); ("seveneighths", 0x215e); ("seveninferior", 0x2087); ("sevenoldstyle", 0xf737);
    ("sevensuperior", 0x2077); ("sfthyphen", 0x00ad); ("sigma", 0x03c3); ("six", 0x0036); ("sixinferior", 0x2086);
    ("sixoldstyle", 0xf736); ("sixsuperior", 0x2076); ("slash", 0x002f); ("space", 0x0020); ("ssuperior", 0xf6f2);
    ("sterling", 0x00a3); ("summation", 0x2211); ("t", 0x0074); ("theta", 0x03b8); ("thorn", 0x00fe);
    ("three", 0x0033); ("threeeighths", 0x215c); ("threeinferior", 0x2083); ("threeoldstyle", 0xf733); ("threequarters", 0x00be);
    ("threequartersemdash", 0xf6de); ("threesuperior", 0x00b3); ("tilde", 0x02dc); ("trademark", 0x2122); ("tsuperior", 0xf6f3);
    ("two", 0x0032); ("twodotenleader", 0x2025); ("twoinferior", 0x2082); ("twooldstyle", 0xf732); ("twosuperior", 0x00b2);
    ("twothirds", 0x2154); ("u", 0x0075); ("uacute", 0x00fa); ("ucircumflex", 0x00fb); ("udieresis", 0x00fc);
    ("ugrave", 0x00f9); ("underscore", 0x005f); ("v", 0x0076); ("w", 0x0077); ("x", 0x0078);
    ("y", 0x0079); ("yacute", 0x00fd); ("ydieresis", 0x00ff); ("yen", 0x00a5); ("z", 0x007a);
    ("zcaron", 0x017e); ("zero", 0x0030); ("zeroinferior", 0x2080); ("zerooldstyle", 0xf730); ("zerosuperior", 0x2070);
  |]

let by_name : (string, int) Hashtbl.t = Hashtbl.create 512
let by_code : (int, string) Hashtbl.t = Hashtbl.create 512

let () =
  Array.iter
    (fun (name, code) ->
      Hashtbl.replace by_name name code;
      if not (Hashtbl.mem by_code code) then Hashtbl.replace by_code code name)
    named;
  (* where a character has several names, the one the standard encoding uses *)
  Array.iter (fun name -> match Hashtbl.find_opt by_name name with Some code -> Hashtbl.replace by_code code name | None -> ()) standard_encoding

(* a name's character: the list's, or one spelt out (uni0041, u1F600) *)
let unicode (name : string) : int option =
  let name = match String.index_opt name '.' with Some i when i > 0 -> String.sub name 0 i | _ -> name in
  match Hashtbl.find_opt by_name name with
  | Some code -> Some code
  | None ->
      let hex from = int_of_string_opt ("0x" ^ String.sub name from (String.length name - from)) in
      if String.length name = 7 && String.sub name 0 3 = "uni" then hex 3
      else if String.length name >= 5 && String.length name <= 7 && name.[0] = 'u' then hex 1
      else None

let name (code : int) : string option = Hashtbl.find_opt by_code code
