(* a loop over floats: lib_audio's sine instrument (Instrument.sine's
 * fill), a block of samples of a note, its gate's ramp and its volume *)
type voice = { mutable phase : float; mutable gate : float; mutable volume : float; mutable last_volume : float }

let rate = 44100

let fill (s : voice) (left : float array) (right : float array) (frequency : float) : unit =
  let n = Array.length left in
  let target = 1. and step = 1. /. 220. in
  let dphase = frequency /. float_of_int rate in
  for i = 0 to n - 1 do
    s.gate <- (if s.gate < target then Float.min target (s.gate +. step) else Float.max target (s.gate -. step));
    let volume = s.last_volume +. ((s.volume -. s.last_volume) *. float_of_int (i + 1) /. float_of_int n) in
    let x = volume *. s.gate *. sin (2. *. Float.pi *. s.phase) in
    left.(i) <- x;
    right.(i) <- x;
    s.phase <- Float.rem (s.phase +. dphase) 1.
  done;
  s.last_volume <- s.volume

let () =
  let s = { phase = 0.; gate = 0.; volume = 0.5; last_volume = 0.5 } in
  let left = Array.make 512 0. and right = Array.make 512 0. in
  let sum = ref 0 in
  for k = 1 to 20 do
    fill s left right (220. +. float_of_int k);
    Array.iter (fun (x : float) -> sum := (!sum * 31 + int_of_float (x *. 1000.)) land 0xffffff) left
  done;
  print_int !sum;
  print_newline ()
