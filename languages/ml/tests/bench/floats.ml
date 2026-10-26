(* loops over floats: mini-virtuaracing's Render, its corners turned
 * by the eye's three vectors into arrays (Render.draw), the rows a
 * face covers by two refs (Render.fill's ymin and ymax), and a sum in
 * a ref: the three ways a float is boxed (plan_ml_floats.md) *)

let turn (xs : float array) (ys : float array) (zs : float array)
    (vx : float array) (vy : float array) (vz : float array) (k : float) :
    unit =
  let rx = 0.8 and ry = 0.1 *. k and rz = 0.6 in
  let ux = 0.1 and uy = 0.9 and uz = -0.2 *. k in
  let ax = -0.6 and ay = 0.2 and az = 0.8 in
  for i = 0 to Array.length xs - 1 do
    let x = xs.(i) -. 3. and y = ys.(i) -. 1.5 and z = zs.(i) +. k in
    vx.(i) <- (x *. rx) +. (y *. ry) +. (z *. rz);
    vy.(i) <- (x *. ux) +. (y *. uy) +. (z *. uz);
    vz.(i) <- (x *. ax) +. (y *. ay) +. (z *. az)
  done

let rows (vy : float array) : float =
  let ymin = ref vy.(0) and ymax = ref vy.(0) in
  for i = 1 to Array.length vy - 1 do
    ymin := Float.min !ymin vy.(i);
    ymax := Float.max !ymax vy.(i)
  done;
  !ymax -. !ymin

let sum (vz : float array) : float =
  let s = ref 0. in
  for i = 0 to Array.length vz - 1 do
    s := !s +. (vz.(i) *. vz.(i))
  done;
  !s

let () =
  let n = 1000 in
  let xs = Array.init n (fun (i : int) -> float_of_int (i mod 37))
  and ys = Array.init n (fun (i : int) -> float_of_int (i mod 11) *. 0.5)
  and zs = Array.init n (fun (i : int) -> float_of_int (i mod 23) *. 2.) in
  let vx = Array.make n 0. and vy = Array.make n 0. and vz = Array.make n 0. in
  let check = ref 0 in
  for k = 1 to 20 do
    turn xs ys zs vx vy vz (float_of_int k);
    let r = rows vy and s = sum vz in
    check := ((!check * 31) + int_of_float (r *. 100.) + int_of_float s)
             land 0xffffff
  done;
  print_int !check;
  print_newline ()
