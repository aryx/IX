(* 11c5d5f0^, tiny/TinyMachine.ml and TinyLibMachine.ml: a ^C typed by
 * the signal's handler into the console's queue, which console_poll
 * replaced with what it had just read: a key typed right after the ^C,
 * and the ^C was lost *)
type console = { mutable queue : string; mutable next : int; mutable opened : bool }

let console_type (k : console) (s : string) : unit =
  k.queue <- String.sub k.queue k.next (String.length k.queue - k.next) ^ s;
  k.next <- 0

let console_read (k : console) : int =
  if k.next < String.length k.queue then (k.next <- k.next + 1; Char.code k.queue.[k.next - 1])
  else 0xffff

let console_open (k : console) : unit =
  if not k.opened then begin
    k.opened <- true;
    Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> console_type k "\003"))
  end

let console_poll (k : console) : unit =
  if k.next >= String.length k.queue then
    match Unix.select [ Unix.stdin ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 256 in
        let n = Unix.read Unix.stdin b 0 256 in
        k.queue <- Bytes.sub_string b 0 n;
        k.next <- 0
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()

let () =
  let k = { queue = ""; next = 0; opened = false } in
  console_open k;
  while true do console_poll k; ignore (console_read k) done
