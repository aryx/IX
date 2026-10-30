(* [to_string ~format ~delay frames]: an FLC (default) or FLI file of
   these pictures, of at most 256 colors: FLC with DELTA_FLC, FLI with LC;
   the palette once, first; a frame that didn't change is a frame of no
   chunks. *)
val to_string : ?format:Fli.format -> delay:float -> Rgba_image.t list -> string
