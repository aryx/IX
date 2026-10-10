(* Pdf_color: what a colour's numbers mean -- the spaces of PDF made
   red, green and blue.

     DeviceGray   one number, 0 black to 1 white
     DeviceRGB    three
     DeviceCMYK   four inks, a printer's: cyan, magenta, yellow, black
                  -- made RGB the plain way, (1 - c)(1 - k)
     ICCBased     a profile: taken as the device space of as many
                  numbers (1, 3 or 4)
     Indexed      a palette: one number, the place of a colour in a
                  table of another space
     Separation,  one ink of a press (a spot colour) and how much of
     DeviceN      it: shown as that much black
     Pattern      not a colour: a tiling (grey here) or a gradient
                  (Pdf_shading)

   The page's operators say a space, then numbers in it ("cs", "sc");
   or both at once for the three device spaces ("0.5 g", "1 0 0 rg",
   "0 0 0 1 k").

   wib:
   No colour management: a profile's numbers are shown as the
   screen's, CMYK is converted by arithmetic, not by an ink's
   measured colour. A black that is "0 0 0 1 k" comes out pure black
   where a viewer with profiles shows a dark grey.

   Reference: ISO 32000-1:2008, section 8.6. *)
(* ix: mini-chrome's libs/pdf/Pdf_color.mli (docs/plans/plan_pdf.md) *)

(* red, green, blue, each 0 to 255 *)
type rgb = float * float * float

type space = Gray | Rgb | Cmyk | Indexed of space * string | Tint | Pattern

(* [space pdf resources v]: a space by its name (looked up in the
 * page's /ColorSpace resources if it is not a device's) or its
 * description *)
val space : Pdf.t -> Pdf_object.t -> Pdf_object.t -> space

(* the colour of numbers in a space *)
val color : space -> float list -> rgb
