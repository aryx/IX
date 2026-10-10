(* Glyph_unicode: a letter beyond ASCII, drawn with the pen of a font
   that has none -- "é" as an e and a stroke above it.

   Hershey's Roman simplex (Hershey.mli) has the ninety-five printable
   characters of ASCII. A page in French, German or Polish, or one in
   English with the quotes and dashes a word processor puts in, has
   others, and each was a "?".

   cs-history:
   That a letter with an accent is a letter and an accent is how they
   were made before there were fonts: on a typewriter a "dead key"
   printed the accent and did not move the carriage, and the letter was
   struck under it; ASCII (1967) kept ` ^ and ~ for the same use over a
   backspace. TeX (1978) composes them still, \'e placing the acute by
   the letter's height. Character sets then gave each combination a
   number of its own (ISO 8859-1, 1987: "é" is 233), and Unicode kept
   both views: U+00E9 is "é", and so is "e" followed by U+0301, a
   combining acute; its tables say which letter and which mark each of
   the first is made of (the canonical decomposition, UAX #15). This
   module is that table for the Latin letters of Europe, and the marks
   as a few strokes of the pen.

   So a character is, in order:

     ASCII                 Hershey's glyph
     a letter with a mark  the letter's glyph and the mark's strokes,
                           above a small letter (over its x-height) or
                           a capital, or below (a cedilla, an ogonek),
                           or across (a stroke): Latin-1 (À to ÿ) and
                           Latin Extended-A (Ā to ž): Western and
                           Central Europe, the Baltic, Turkish
     a ligature            two glyphs side by side, closer: æ œ ß
     what looks like ASCII the curly quotes as the straight ones, the
                           dashes (an em dash twice as long), the
                           no-break space, … as three dots, « and »,
                           × and ÷
     a few signs drawn     ° · • € £ ¥ ¢ ¡ ¿ © ® ™ the arrows, ✓
     of no width           the soft hyphen, the zero-width spaces
     anything else         Hershey's "?": Greek, Cyrillic (Hershey
                           drew them: their faces are not in lib_graphics)
                           and every other script

       É   the acute over a capital         é   over a small letter
           (-1,-14) to (3,-17)                  (-1,-7) to (3,-10)
       ç   the cedilla, under the baseline  ø   the stroke, across

   The width of a letter with a mark is its letter's: an accent takes
   no room in the line. Worked example (Unit_glyph_unicode):
   "é" is as wide as "e" and has one stroke more; "…" is three "."
   wide; "—" is one stroke, twice a "-"; U+0394 (Δ) is the "?".

   modern:
   All of Unicode is another order of thing: over 150,000 characters in
   over 160 scripts, and a page may hold any of them. No font has them all (a
   font file addresses 65,535 glyphs at most), so a browser has none
   that is "the" font. For each character it asks the font the page
   named whether it has it (the font's cmap table, code point to
   glyph); if not, the next of the page's list; then the system's
   fonts, by the character's script -- font *fallback* -- down to a
   font kept for the purpose (Google's Noto, 2012, is named for it:
   "no tofu", tofu being the empty box drawn when everything fails,
   our "?"). And a glyph for each character is not enough either:

     a letter and its mark   "e" then U+0301: the mark is placed by the
                             font's own table of anchors (GPOS), not
                             by a rule as here
     shaping                 Arabic's letters change form by their
                             neighbours and join; Devanagari's
                             reorder and fuse. A *shaper* (HarfBuzz,
                             2006: Chrome's and Firefox's) turns a run of
                             characters into the glyphs and their
                             places, by the font's substitution
                             tables (GSUB)
     direction               Hebrew and Arabic run right to left, and
                             mix with Latin on one line: the Unicode
                             bidirectional algorithm (UAX #9)
     what is one character   "é" as two code points, a flag as two, a
                             family emoji as seven: what a caret steps
                             over is a grapheme cluster (UAX #29)
     where a line may break  not only at spaces: between any two
                             Chinese characters, never before a
                             closing bracket (UAX #14)
     colour                  an emoji is a small picture in the font

   To take this module further, in the order of what it would give:
   Greek and Cyrillic, which Hershey drew (his other faces are in the
   same format, to add to lib_graphics beside this one) and his
   mathematical and cartographic signs; the combining marks (U+0300 to
   U+036F) put over the letter before them with [above], which is
   this module read the other way; then, for everything else, a
   fallback of the same kind as a browser's -- a bitmap font that has
   the whole Basic Multilingual Plane (GNU Unifont: a glyph of 8 or 16
   by 16 dots for each of its 57,000 characters) drawn where the pen
   has nothing. Shaping and direction are not a table but an
   algorithm each, and the real work.

   Reference: The Unicode Standard, chapter 7 (Latin) and Annex #15
   (normalization: the decompositions); ISO/IEC 8859-1 (1987); A. V.
   Hershey, "Calligraphy for Computers" (1967). On the rest: Behdad
   Esfahbod's HarfBuzz (harfbuzz.github.io, "What is text shaping?");
   Unicode Annexes #9 (bidirectional), #14 (line breaking), #29
   (segmentation); the OpenType specification (cmap, GSUB, GPOS). *)

(* the glyph of a character given as its UTF-8 bytes (one of
 * Browser_text.characters') *)
val glyph : string -> Hershey.glyph

(* whether it has one of its own: not the "?" given for what is unknown *)
val known : string -> bool
