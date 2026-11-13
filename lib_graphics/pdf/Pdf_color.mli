(* Pdf_color says what a colour's numbers mean: it turns the colour
   spaces of PDF into red, green and blue.

     DeviceGray   one number, from 0 for black to 1 for white
     DeviceRGB    three numbers
     DeviceCMYK   four numbers, for a printer's four inks: cyan,
                  magenta, yellow and black. They are made into RGB
                  the plain way, (1 - c)(1 - k)
     ICCBased     a profile, taken as the device space with as many
                  numbers (1, 3 or 4)
     Indexed      a palette: one number, which is the place of a
                  colour in a table of another space
     Separation,  one ink of a press (a spot colour) and how much of
     DeviceN      it, shown as that much black
     Pattern      not a colour, but a tiling (grey here) or a gradient
                  (Pdf_shading)

   The page's operators name a space, then give numbers in it ("cs",
   "sc"). For the three device spaces, one operator does both at once
   ("0.5 g", "1 0 0 rg", "0 0 0 1 k").

   wib:
   There is no colour management. A profile's numbers are shown as if
   they were the screen's, and CMYK is converted by arithmetic, not by
   an ink's measured colour. So a black that is "0 0 0 1 k" comes out
   pure black, where a viewer with profiles shows a dark grey.

   Reference: ISO 32000-1:2008, section 8.6. *)
(* ix: from mini-chrome's libs/pdf/Pdf_color.mli
 * (docs/plans/done/plan_pdf.md) *)

(* red, green, blue, each 0 to 255 *)
type rgb = float * float * float

type space = Gray | Rgb | Cmyk | Indexed of space * string | Tint | Pattern

(* [space pdf resources v] is the space that v names (looked up in the
 * page's /ColorSpace resources if it is not a device's) or that v
 * describes *)
val space : Pdf.t -> Pdf_object.t -> Pdf_object.t -> space

(* the colour that numbers mean in a space *)
val color : space -> float list -> rgb
