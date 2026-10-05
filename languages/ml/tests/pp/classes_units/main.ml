(* mlpp's classes across units: the dictionaries are the class's unit's
 * (Classy.show_list) and the type's (Point.show_point), whatever is
 * open here *)
open Classy

let () =
  print [ 1; 2 ];
  print Point.origin;
  print [ Point.origin; { Point.x = 1; y = 2 } ];
  print_endline (String.concat " " (List.map show [ 3; 4 ]))
