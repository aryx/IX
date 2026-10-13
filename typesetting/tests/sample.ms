.TL
A Paper to Try the Macros of ms(6) On
.AU
Claude Code
.AI
The IX Project
.AB
This is the abstract: set in from both sides, under its word.
It says in two sentences what the paper is for.
.AE
.NH
Paragraphs
.PP
A paragraph starts with its first line indented, and is long enough here to be put on several lines, so that one sees where the others start.\(dg
.FS
\(dg A footnote, said in the middle of a paragraph and written at the sheet's foot.
.FE
The sentence after the footnote's mark is in the same paragraph.
.LP
A paragraph with no indent, with a word in
.I italic ,
one in
.B bold ,
one
.CW typed
and a
.I "(parenthesis" ) (
done by the third argument.
.IP (1) 5
An indented paragraph hangs from its tag.
.IP (2)
The width stays for the next.
.RS
.IP \(bu
One level further right.
.RE
.QP
A quotation is set in from both sides, as the abstract was, for as long as the paragraph lasts.
.NH 2
A Subsection
.LP
Its number has two parts.
.NH 2
Another
.LP
And the second part counts.
.NH
Displays
.LP
A display keeps its lines:
.DS
one line
    and another, indented
.DE
A program is in its own font:
.P1
int	main(void)
{
	return 0;
}
.P2
.KS
.LP
What is between a keep's two macros stays on one sheet.
.KE
.NH
A Table
.LP
In the middle, in a box, numbers under one another:
.TS
center, box;
c s s
l n r.
Table 1: three columns
_
context switch	39	fast
fork	1300.5	slow
a text	0.25	T{
A cell that is a text of several lines is filled in its column, with a word
.I italic
in it.
T}
.TE
.NH
A Picture
.LP
Boxes, an arrow, a curve, a macro:
.PS
define pair { box wid $1 "$2"; arrow; box wid $1 "$3" }
A: [ pair(0.8, readers, Doc.t) ]
E: ellipse "layout" with .n at A.s + (0, -0.3)
spline -> from A.e right 0.3 then down 0.5 then to E.e
line <- from E.w left 0.4 "words" above
circle rad 0.1 at 0.5 <A.sw, E.w>
.PE
.SH
A Heading with No Number
.LP
.I
Italic from here on,
.R
and roman again.
.SM SMALL
words and
.LG
larger ones
.NL
and normal ones.
