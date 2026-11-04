(* 11c5d5f0: the handler sets a flag, the loop types the ^C; a bool
 * written by both is a flag, which a handler run where the program waits
 * does not race *)
type console = { mutable queue : string; mutable next : int; mutable opened : bool }

let interrupted = ref false

let console_type (k : console) (s : string) : unit =
  k.queue <- String.sub k.queue k.next (String.length k.queue - k.next) ^ s;
  k.next <- 0

let console_open (k : console) : unit =
  if not k.opened then begin
    k.opened <- true;
    Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> interrupted := true))
  end

let console_poll (k : console) : unit =
  if !interrupted then (interrupted := false; console_type k "\003");
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
  while true do console_poll k done
