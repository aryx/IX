(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's shell (plan_system_singularity.md, decision 8):
 * a line read from the console, by the console's driver (the Console
 * contract, at the endpoint its parent gave it); its first word a
 * command of its own, or a program's name: the program is started and
 * waited for. What a program prints goes by the kernel's debug line,
 * not through here. *)

let console = Console.Imp.of_endpoint (Given.endpoint 0)

(* one block, lent to the driver at each write and had back *)
let buffer = ref (Sip.alloc 256)

let rec print (s : string) : unit =
  let n = min (String.length s) 256 in
  if n > 0 then begin
    Sip.write !buffer 0 (String.sub s 0 n);
    Console.Imp.write console !buffer n;
    (match Console.Imp.receive console with Written b -> buffer := b | Key _ -> ());
    print (String.sub s n (String.length s - n))
  end

let key () : char =
  Console.Imp.read console;
  match Console.Imp.receive console with Key c -> Char.chr c | Written _ -> ' '

(* a line, shown as it is typed; backspace takes a character back *)
let read_line () : string =
  let b = Buffer.create 80 in
  let rec loop () : string =
    match key () with
    | '\r' | '\n' -> print "\n"; Buffer.contents b
    | '\b' | '\127' ->
        if Buffer.length b > 0 then begin Buffer.truncate b (Buffer.length b - 1); print "\b \b" end;
        loop ()
    | c -> Buffer.add_char b c; print (String.make 1 c); loop ()
  in
  loop ()

(* what the kernel says of itself, through a block *)
let info (programs : bool) : string =
  let b = Sip.alloc 4096 in
  let s = Sip.info b programs in
  Sip.free b;
  s

let run (name : string) : unit =
  match Sip.create name with
  | None -> print (name ^ ": no such program, or it runs already\n")
  | Some p ->
      Sip.start p;
      let status = Sip.join p in
      if status <> 0 then print (Printf.sprintf "%s ended with %d\n" name status)

let () =
  print "mini-singularity's shell (help: what it knows)\n";
  let rec loop () : unit =
    print "sing> ";
    match List.filter (fun (w : string) -> w <> "") (String.split_on_char ' ' (read_line ())) with
    | [] -> loop ()
    | [ "exit" ] -> ()
    | [ "help" ] ->
        print "ps: the processes; exit: the end; or a program's name, one of:\n";
        print (info true);
        loop ()
    | [ "ps" ] -> print (info false); loop ()
    | [ name ] -> run name; loop ()
    | _ -> print "a command is one word\n"; loop ()
  in
  loop ();
  exit 0
