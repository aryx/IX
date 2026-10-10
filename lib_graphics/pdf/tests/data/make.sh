#!/bin/sh
# The files of tests/pdf: small PDF files written by others' programs,
# and what poppler (pdftoppm) draws of each page at 72 dots an inch --
# the picture ours must be near. Run once, by hand, in this directory,
# on a machine with TeX, Python's cairo, Chrome, LibreOffice and
# poppler; its outputs are kept in the repository.
#
#   shapes    cairo: filled and stroked paths, a clip, transparency, a
#             picture, three gradients; text in a TrueType font
#   tex       pdfTeX: Type 1 fonts (Computer Modern), mathematics; its
#             objects packed in streams, its table of objects a stream
#   bitmap    pdfTeX with T1 encoding and no outline font installed:
#             Type 3 fonts, each glyph a small picture
#   cff       cairo with OpenType fonts: CFF (Type 1C) fonts
#   browser   Chrome's print to PDF: TrueType fonts by glyph number
#             (Type 0, Identity-H), rounded boxes, a circle
#   office    LibreOffice: TrueType fonts in Windows' encoding
#   standard  written by hand: Helvetica and Times named, not embedded
set -e
python3 - <<'PY'
import cairo, math
s=cairo.PDFSurface('shapes.pdf', 400, 300); c=cairo.Context(s)
c.set_source_rgb(1,1,0.8); c.paint()
c.set_source_rgb(0.8,0.1,0.1); c.rectangle(20,20,100,60); c.fill()
c.set_source_rgb(0,0.3,0.7); c.set_line_width(6); c.arc(180,50,30,0,2*math.pi); c.stroke()
c.save(); c.rectangle(240,20,60,60); c.clip(); c.set_source_rgb(0,0.6,0.2); c.arc(270,50,40,0,2*math.pi); c.fill(); c.restore()
c.set_source_rgba(0.5,0,0.5,0.5); c.move_to(20,150); c.curve_to(60,100,100,220,150,160); c.line_to(150,200); c.line_to(20,200); c.close_path(); c.fill()
c.set_source_rgb(0,0,0); c.select_font_face('DejaVu Sans'); c.set_font_size(22); c.move_to(20,120); c.show_text('Hello, PDF')
img=cairo.ImageSurface(cairo.FORMAT_RGB24,8,8); ic=cairo.Context(img)
for y in range(8):
    for x in range(8):
        ic.set_source_rgb(x/7,y/7,0.5); ic.rectangle(x,y,1,1); ic.fill()
c.save(); c.translate(320,20); c.scale(7,7); c.set_source_surface(img,0,0); c.paint(); c.restore()
g=cairo.LinearGradient(170,0,290,0); g.add_color_stop_rgb(0,1,0,0); g.add_color_stop_rgb(0.5,1,1,0); g.add_color_stop_rgb(1,0,0,1)
c.set_source(g); c.rectangle(170,140,120,60); c.fill()
r=cairo.RadialGradient(340,170,4,340,170,36); r.add_color_stop_rgb(0,1,1,1); r.add_color_stop_rgb(1,0,0.4,0)
c.set_source(r); c.arc(340,170,36,0,2*math.pi); c.fill()
g2=cairo.LinearGradient(0,220,0,280); g2.add_color_stop_rgb(0,0.2,0.2,0.2); g2.add_color_stop_rgb(1,0.9,0.9,1)
c.set_source(g2); c.move_to(20,280); c.line_to(200,220); c.line_to(380,280); c.close_path(); c.fill()
s.finish()
s=cairo.PDFSurface('cff.pdf', 320, 110); c=cairo.Context(s)
c.set_source_rgb(0,0,0); c.select_font_face('URW Bookman'); c.set_font_size(24); c.move_to(16,40); c.show_text('Bookman, a CFF font')
c.select_font_face('Latin Modern Roman'); c.move_to(16,84); c.show_text('Latin Modern: fi fl')
s.finish()
PY
tmp=$(mktemp -d)
cat > $tmp/tex.tex <<'TEX'
\documentclass{article}\pagestyle{empty}\usepackage[paperwidth=10cm,paperheight=5cm,margin=8mm]{geometry}
\begin{document}\noindent Hello, PDF: \emph{italic} and mathematics,\par\noindent $e^{i\pi} + 1 = 0$ and $\int_0^1 x^2\,dx = \frac{1}{3}$.\par\noindent\rule{4cm}{1pt}
\newpage\noindent Second page: fi fl ff.
\end{document}
TEX
sed 's/\\pagestyle{empty}/\\pagestyle{empty}\\usepackage[T1]{fontenc}/; s/and mathematics,.*dx = \\frac{1}{3}\$\./in bitmap letters./' $tmp/tex.tex > $tmp/bitmap.tex
(cd $tmp && pdflatex -interaction=batchmode tex.tex > /dev/null && pdflatex -interaction=batchmode bitmap.tex > /dev/null)
cp $tmp/tex.pdf $tmp/bitmap.pdf .
cat > $tmp/browser.html <<'HTML'
<html><head><style>@page { size: 4in 3in; margin: 0.3in }</style></head><body style="font-family: DejaVu Sans; margin: 0"><h2>Hello, PDF</h2><p>Printed by a browser: <i>italic</i>, <b>bold</b>.</p>
<div style="width:150px;height:40px;background:#fc0;border:3px solid #036;border-radius:10px"></div><p style="color:#c00">red words</p></body></html>
HTML
google-chrome --headless --disable-gpu --no-pdf-header-footer --print-to-pdf=browser.pdf $tmp/browser.html > /dev/null 2>&1
soffice --headless --convert-to pdf --outdir $tmp/office $tmp/browser.html > /dev/null 2>&1 && cp $tmp/office/browser.pdf office.pdf
rm -r $tmp
# a file written by hand: its table of objects left out, for the reader to rebuild
cat > standard.pdf <<'PDF'
%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 300 120] >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >> endobj
4 0 obj << /Length 118 >>
stream
BT /F1 20 Tf 20 80 Td (Helvetica, not embedded) Tj ET
BT /F2 16 Tf 20 40 Td [(Times: an of)-20(fice)] TJ ET
endstream
endobj
5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
6 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >> endobj
trailer << /Root 1 0 R >>
PDF
for f in shapes tex bitmap cff browser office standard; do
  pdftoppm -r 72 -png $f.pdf $f
done
