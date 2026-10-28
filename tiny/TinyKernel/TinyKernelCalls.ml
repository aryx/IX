(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelCalls.mli *)
open TinyMemory
open TinyKernelGraphics
open TinyKernelNetwork
open TinyKernelFS
open TinyKernelMemory
open TinyKernelMachine
open TinyKernelFiles
open TinyKernelProcs
open TinyKernelDevices
open TinyKernelIO

(*****************************************************************************)
(* The system calls *)
(*****************************************************************************)

(* a call that may wait: tried now, and until it finishes by the
 * scheduler, the process Waiting meanwhile *)
let block p attempt =
  if not (attempt ()) then (p.state <- Waiting attempt; p.since <- -1)

let result p v = set_reg p 1 v

(* A buffer in one piece is given to the device as it is: the user's
 * memory, at the kernel's address (every buffer, with partitions; asked
 * by mem_address, which allocates nothing: mem_pieces's list at each
 * read and write slowed the kernel enough to reorder the check's last
 * lines, an echo in the background before rc's prompt). One
 * in several pieces goes through the kernel's own, the bounce (640 KB
 * at 0xb60000, TinyKernel.mli's layout), which a device sees as one:
 * a write's bytes copied in before, a read's copied back after, at
 * each try (a call that waits is tried again, and the bounce is
 * another's meanwhile). At most the bounce's size, so a read or a
 * write may do less than asked, as Unix lets them. Linux and xv6 copy
 * every call's buffer that way (copy_from_user, copyin) *)
let bounce = 0xb60000
let bounce_size = 0xa0000

let sys_rw p rw reading =
  let f = fd p (reg p 1) and va = reg p 2 and n = reg p 3 in
  if reading && not (mem_writable p.mem va n) then raise Bad;
  let finish = function Some k -> result p k; true | None -> false in
  let a = mem_address p.mem va n in
  if a >= 0 then block p (fun () -> finish (rw f a n))
  else begin
    let n = min n bounce_size in
    block p (fun () ->
      if not reading then
        user_iter p va n (fun a off k -> row_copy (bounce + off) a k);
      let r = rw f bounce n in
      (match r with
       | Some k when reading && k > 0 ->
           user_iter p va k (fun a off k -> row_copy a (bounce + off) k)
       | _ -> ());
      finish r)
  end

(* its descriptors closed, its children orphans (the records of those
 * that ended dropped), the processes it traces let go, its end said to
 * its tracer; its slot and its memory free, its status a record for
 * its parent's wait (Procs.ended). The first process's end is the
 * machine's *)
let rec exit_proc p status =
  incr deaths;
  List.iter (fun (_, f) -> drop f) p.fds;
  p.fds <- [];
  List.iter (fun q ->
    match q.traced with
    | Some t when t.tracer = p.pid -> detach t
    | _ -> ()) !procs;
  (match p.traced with
   | Some t -> t.said <- t.said @ [ "exited " ^ string_of_int status ^ "\n" ]
   | None -> ());
  List.iter (fun q -> if q.parent = p.pid then q.parent <- 0) !procs;
  ended := List.filter (fun (parent, _, _) -> parent <> p.pid) !ended;
  if p.pid = 1 then halt status;
  if p.parent <> 0 then ended := !ended @ [ (p.parent, p.pid, status) ];
  release p

and release q =
  mem_release q.mem;
  procs := List.filter (fun r -> r.pid <> q.pid) !procs

(* fork: a new slot and a partition of the parent's size, the partition
 * and the frame copied (the child's r1 0), the descriptors shared; the
 * child has none of its parent's breakpoints, their words put back in
 * its copy. It is traced by its parent's tracer when the parent's
 * children are (f), stopping at its calls if the parent does: the
 * tracer's trace(pid) gives the descriptor, its stops kept till then *)
(* A call that needs a slot or a partition: done now or, when there is none,
 * waited for while another process can run (and end, freeing one):
 * what a build of several recipes at once runs into (tiny-build -j 6:
 * six compilers of 32 MB). When none can, -1 (old: -1 at once, and
 * rc said "not found"). Tried again when a process has ended, as a
 * wait (old: at each round, a walk of the slots: with a build's forks
 * waiting, a round was longer than a tick, every process entered with
 * its time already up, and none ran an instruction) *)
let with_room p f =
  try f () with No_room ->
    block p (fun () ->
      try f (); true with
      | No_room ->
          if List.exists (fun q ->
               q.pid <> p.pid && (match q.state with Ready -> true | _ -> false))
               !procs
          then false
          else (result p (-1); true)
      | Bad -> result p (-1); true);
    match p.state with Waiting _ -> p.since <- !deaths | _ -> ()

(* a child of p's, in slot s: its descriptors and directory p's; traced
 * when p's children are; its pid the next *)
let child p s = {
  slot = s; mem = mem_empty (); pid = !next_pid; state = Ready;
  parent = p.pid; fds = p.fds; cwd = p.cwd; since = -1; traced = None;
  core = -1; doomed = false;
}

(* the child made a process: its trace if p's children are traced, its
 * descriptors shared, its place at the end of the round, its pid p's
 * answer *)
let adopt p q =
  incr next_pid;
  (match p.traced with
   | Some t when t.follow ->
       q.traced <- Some { t with tpid = q.pid; stops = []; said = [];
                                 watchers = 0; call = -1; ret = -1;
                                 step = false; over = -1 }
   | _ -> ());
  List.iter (fun (_, f) -> share f) p.fds;
  procs := !procs @ [ q ];
  result p q.pid

let sys_fork p = with_room p (fun () ->
  let q = child p (free_slot ()) in
  mem_copy q.mem p.mem;
  k_copy (frame q.slot) (frame p.slot) 68;
  (match p.traced with
   | Some t -> List.iter (fun (a, w) -> mem_store q.mem a w) t.stops
   | None -> ());
  set_reg q 1 0;
  adopt p q)

(* A program's file is either a raw image, run in 1 MB, or an a.out: a
 * header of three words (a magic number, the image's size, the memory
 * the program asks for), then the image (tiny-linker -a), and maybe its
 * labels, for debug (-s), which are not loaded. With tiny-linker -n, a
 * fourth word, the text's size, and another magic number. This returns
 * where the image starts in the file, its size, the memory, and the
 * text's size (0: none). *)
let aout_magic = 0x7a0ce5
let aout_split = 0x7a0ce6
let header bytes =
  let word i =
    String.get_uint16_le bytes i
    + (String.get_uint16_le bytes (i + 2) lsl 16) in
  let n = String.length bytes in
  if n >= 12 && word 0 = aout_magic then Some (12, word 4, word 8, 0)
  else if n >= 16 && word 0 = aout_split then Some (16, word 4, word 8, word 12)
  else None

(* a file of the disk as a program's, to share its text (TinyKernelMemory's
 * key; its stamp is its date and size) *)
let disk_key r i = "disk " ^ string_of_int r ^ " " ^ string_of_int i

(* Loads a file's program into p, in a partition of the size it asks for
 * (rounded up to whole megabytes), from address 0. Its arguments are put
 * as tiny-cpu leaves them (the strings at the top, then argc, argv and
 * argv's pointers: start.tm's); every register is 0 but sp. Bad if it is
 * no program, or one that leaves no room for a stack, or if there is no
 * room for its partition; in that case p is left as it was. *)
let load_prog p node argv =
  (* (an image's file never changes; a file of memory is not shared) *)
  let key, date =
    match node with
    | Some (Rom (at, _)) -> "rom " ^ string_of_int at, ""
    | Some (Disk (r, i)) -> disk_key r i, string_of_int (fs_date r i)
    | _ -> "", "" in
  let node =
    match node with
    | Some (Disk (r, i)) -> Some (Data (data (fs_contents r i)))
    | _ -> node in
  let n =
    match node with
    | Some (Data d) -> d.dsize
    | Some (Rom (_, n)) -> n
    | _ -> raise Bad in
  let first =
    match node with
    | Some (Data d) -> Bytes.sub_string d.dbytes 0 (min n 16)
    | Some (Rom (at, _)) -> k_string at (min n 16)
    | _ -> "" in
  let skip, size, memory, tsize = match header first with
    | Some (h, size, memory, tsize)
      when size <= n - h && tsize <= size && tsize land 4095 = 0 ->
        h, size, (memory + part - 1) / part * part, tsize
    | _ -> 0, n, part, 0 in
  if size > memory - 0x10000 || memory > mem_high - mem_low then raise Bad;
  (* the text written only when it is not shared already *)
  let stamp = if date = "" then "" else date ^ " " ^ string_of_int n in
  let from = if mem_load p.mem key stamp tsize size memory then 0 else tsize in
  (* Only the image is written, its statics in it (tiny-linker writes a
   * .space as zeros); the rest of the
   * partition, the stack and the heap, is left as the last process to
   * have it left it, as no program reads a word it has not written
   * (the ML runtime's stack of values and heap, libc's heap a static
   * array). It is the same at each run, but it shows the bytes of
   * another process to this one: to revisit for security, as Plan 9
   * and Linux give a page zeroed at its first touch (they have pages;
   * tiny-machine a window). (old: k_zero of the whole partition, 32 MB
   * for ml, 35 million instructions an exec: a fifth of a small unit's
   * compile) *)
  (match node with
   | Some (Data d) ->
       mem_write p.mem from
         (Bytes.sub_string d.dbytes (skip + from) (size - from))
   | Some (Rom (at, _)) -> mem_blit p.mem from (at + skip + from) (size - from)
   | _ -> ());
  let top = ref memory and ptrs = ref [] in
  List.iter (fun s ->
    top := (!top - String.length s - 1) land lnot 3;
    mem_write p.mem !top s;
    (* (its end, a 0: old, the zeros of the partition, zeroed whole) *)
    mem_store_byte p.mem (!top + String.length s) 0;
    ptrs := !ptrs @ [ !top ]) argv;
  let sp = (!top - ((List.length argv + 3) * 4)) land lnot 7 in
  mem_store p.mem sp (List.length argv);
  mem_store p.mem (sp + 4) (sp + 8);
  ignore (List.fold_left (fun at a -> mem_store p.mem at a; at + 4) (sp + 8)
            !ptrs);
  k_zero (frame p.slot) 68;
  set_reg p 14 sp

(* exec's and spawn's (path, argv): the program's file, its arguments
 * (64 at most: a linker's line names its objects; old: 16) *)
let program p =
  let node = walk !top (names p.cwd (ustr p (reg p 1))) in
  let rec args i acc =
    if i >= 64 then raise Bad
    else
      let a = peek (user p (reg p 2 + (4 * i)) 4) in
      if a = 0 then List.rev acc else args (i + 1) (ustr p a :: acc) in
  node, args 0 []

(* exec(path, argv): the program and its arguments are all read before
 * the partition is changed, so a failed exec returns. A traced process
 * stops at its new program's first instruction, its breakpoints gone
 * with the old one *)
let sys_exec p =
  let node, argv = program p in
  with_room p (fun () ->
    load_prog p node argv;
    match p.traced with Some t -> t.stops <- []; stop p "exec" | None -> ())

(* spawn(path, argv): a fork and an exec in one, a child that starts
 * in the program; its pid, or -1. Nothing of the parent is copied: a
 * fork copies the parent's whole partition (16 MB for tiny-build, at
 * each recipe) for the exec to throw it away a moment later. What a
 * child does between the two (a dup, a close) the parent does around
 * the spawn: the child has the parent's descriptors at the spawn *)
let sys_spawn p =
  let node, argv = program p in
  with_room p (fun () ->
    let q = child p (free_slot ()) in
    load_prog q node argv;
    adopt p q)

(* wait(&status): a child's end, its record taken (the child itself
 * was freed when it ended); -1 without children, ended or not *)
let sys_wait p =
  let a = reg p 1 in
  if a <> 0 then ignore (user_out p a 4);
  block p (fun () ->
    match List.filter (fun (parent, _, _) -> parent = p.pid) !ended with
    | (_, pid, s) :: _ ->
        if a <> 0 then poke (user_out p a 4) s;
        ended := List.filter (fun (_, q, _) -> q <> pid) !ended;
        result p pid;
        true
    | [] ->
        if List.exists (fun q -> q.parent = p.pid) !procs then false
        else (result p (-1); true));
  (* (a shell waits most of its life: its call is retried when a process
   * ended, not at each turn) *)
  (match p.state with Waiting _ -> p.since <- !deaths | _ -> ())

let o_create = 0x200
let o_trunc = 0x400

let sys_open p =
  let ns = names p.cwd (ustr p (reg p 1)) and mode = reg p 2 in
  let writes = mode land 3 <> 0 in
  let node =
    match walk !top ns, dir_of ns with
    | Some n, _ -> n
    | None, Some (Dir d, last)
      when mode land o_create <> 0 && String.length last <= 64 ->
        let n = Data { (data "") with dtime = date () } in
        d := !d @ [ last, n ];
        n
    | None, Some (Disk (0, i), last)
      when mode land o_create <> 0 && String.length last <= 64 ->
        Disk (0, fs_create i last 2)
    | _ -> raise Bad in
  (* (a file of the image opened to be written is in memory from now on;
   * or a file of the disk, when its directory is there too: /bin's) *)
  let node =
    match node, dir_of ns with
    | Rom (at, n), Some (Disk (0, i), last) when writes ->
        let j = fs_create i last 2 in
        if mode land o_trunc = 0 then fs_write_at j 0 at n;
        Disk (0, j)
    | Rom (at, n), Some (Dir d, last) when writes ->
        let made =
          Data { (data (if mode land o_trunc <> 0 then "" else k_string at n))
                 with dtime = date () } in
        d := List.map (fun (name, old) ->
          if name = last then name, made else name, old) !d;
        made
    | _ -> node in
  (* (a file of the disk written: no exec shares the text it had) *)
  (match node with
   | Disk (r, i) when writes -> mem_forget (disk_key r i)
   | _ -> ());
  (* (a snapshot is read only) *)
  (match node with
   | Dir _ when writes -> raise Bad
   | Disk (r, i) when writes && (r <> 0 || fs_is_dir r i) -> raise Bad
   | Data d when mode land o_trunc <> 0 ->
       d.dbytes <- Bytes.make 0 ' '; d.dsize <- 0; d.dtime <- date ()
   | Disk (_, i) when writes && mode land o_trunc <> 0 -> fs_truncate i
   | _ -> ());
  result p (fdalloc p (match node with
    | Tty -> Console
    | Screen -> Draw { conn = connect screen font; refs = 1 }
    | Pointer -> Peek mouse
    | Speaker -> Voice { ahead = (played () + lead) land 0x3fffffff }
    | _ -> Open { node = node; off = 0; writes = writes; listing = None }))

let sys_close p =
  let k = reg p 1 in
  drop (fd p k);
  p.fds <- List.filter (fun (j, _) -> j <> k) p.fds;
  result p 0

(* pipe(fds) and box(fds): the two ends, a descriptor each, put in fds *)
let ends p r w =
  let a = user_out p (reg p 1) 4 and b = user_out p (reg p 1 + 4) 4 in
  let r = fdalloc p r in
  let w = fdalloc p w in
  poke a r;
  poke b w;
  result p 0

let sys_pipe p =
  let pi = { buf = ""; readers = 1; writers = 1 } in
  ends p (Reader pi) (Writer pi)

(* a box, its reading end and its writing end *)
let sys_box p =
  let b = { last = ""; fresh = false; posters = 1 } in
  ends p (Peek b) (Post b)

(* dial(address, port): a descriptor on a connection to the program
 * that listens on that port of the machine at that address
 * ("10.0.0.1"), when it has agreed; -1 when nothing does or nothing
 * answers. Port 0 is the echo: a link, made at once *)
let sys_dial p =
  let to_ = net_address (ustr p (reg p 1)) and port = reg p 2 in
  if to_ = "" || port < 0 || port > 0xffff || peek (net_dev + 12) = 0 then
    raise Bad;
  if port = 0 then begin
    let l = { peer = to_; lid = !next_link; asked = 0; heard = []; holders = 1 } in
    incr next_link;
    links := l :: !links;
    result p (fdalloc p (Link l))
  end
  else begin
    let c, sync = net_dial net to_ port !ticks in
    net_send sync;
    block p (fun () ->
      match c.il_at with
      | Il_established ->
          (try result p (fdalloc p (Call { il = c; callers = 1 }))
           with Bad -> il_done c; result p (-1));
          true
      | Il_closed -> result p (-1); true
      | _ -> false)
  end

(* listen(port): a descriptor on the next connection another machine
 * makes to that port of this one, which is listened on from the first
 * call (and stays so: a server is this call in a loop) *)
let sys_listen p =
  let port = reg p 1 in
  if port <= 0 || port > 0xffff || peek (net_dev + 12) = 0 then raise Bad;
  if not (List.mem port net.ns_ports) then
    net.ns_ports <- port :: net.ns_ports;
  block p (fun () ->
    match List.filter (fun c -> c.il_lport = port) net.ns_fresh with
    | c :: _ ->
        net.ns_fresh <-
          List.filter (fun d ->
            d.il_lport <> port || d.il_rport <> c.il_rport
            || d.il_peer <> c.il_peer) net.ns_fresh;
        (try result p (fdalloc p (Call { il = c; callers = 1 }))
         with Bad -> il_done c; result p (-1));
        true
    | [] -> false)

let sys_dup p = let f = fd p (reg p 1) in share f; result p (fdalloc p f)

let sys_mkdir p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk !top ns, dir_of ns with
  | None, Some (Dir d, last) when String.length last <= 64 ->
      d := !d @ [ last, Dir (ref []) ]; result p 0
  | None, Some (Disk (0, i), last) when String.length last <= 64 ->
      ignore (fs_create i last 1); result p 0
  | _ -> raise Bad

(* a name removed; a directory only if empty *)
let sys_unlink p =
  match dir_of (names p.cwd (ustr p (reg p 1))) with
  | Some (Dir d, last) ->
      (match List.assoc_opt last !d with
       | Some (Dir e) when !e <> [] -> raise Bad
       | Some (Disk _) -> raise Bad
       | Some _ -> d := List.filter (fun (n, _) -> n <> last) !d; result p 0
       | None -> raise Bad)
  | Some (Disk (0, i), last) ->
      (match fs_lookup 0 i last with
       | 0 -> raise Bad
       | j when fs_is_dir 0 j && fs_entries 0 j <> [] -> raise Bad
       | _ -> fs_unlink i last; result p 0)
  | _ -> raise Bad

(* link(old, new): a second name for a file, in the directory new is in:
 * the same node, so a write by either name is seen by the other (a file
 * of the image, Rom, is copied when it is first written, under the name
 * it is written by: then the names part). Not for a directory, as on
 * Unix: a directory with two parents would make the tree a graph *)
let sys_link p =
  let old = walk !top (names p.cwd (ustr p (reg p 1)))
  and ns = names p.cwd (ustr p (reg p 2)) in
  match old, walk !top ns, dir_of ns with
  | Some n, _, _ when is_dir n -> raise Bad
  | Some (Disk (0, j)), None, Some (Disk (0, i), last)
    when String.length last <= 64 ->
      fs_link i last j; result p 0
  | Some (Disk _), _, _ -> raise Bad
  | Some node, None, Some (Dir d, last) when String.length last <= 64 ->
      d := !d @ [ last, node ]; result p 0
  | _ -> raise Bad

(* getcwd(buf, n): the current directory's path, ended by a 0, in the n
 * bytes at buf; its length, -1 when it does not fit *)
let sys_getcwd p =
  let path =
    if p.cwd = [] then "/"
    else List.fold_left (fun acc n -> acc ^ "/" ^ n) "" p.cwd in
  let n = String.length path in
  if n + 1 > reg p 2 then raise Bad;
  user_write p (reg p 1) (path ^ "\000");
  result p n

(* rawcons(on): the console raw for this process, while it lives (on
 * 1), or not (on 0). An editor's C-x C-c: ^C a key like the others.
 * Plan 9's rawon, written to /dev/consctl (which also stops the echo
 * and the line editing: tiny-kernel's console has neither) *)
let sys_rawcons p = raw := (if reg p 1 <> 0 then p.pid else 0); result p 0

(* kill(pid): its process ended as a fault ends one, its status -1; on
 * another core, at its next trap, which the cores' interrupt makes
 * now (its partition is not another's before) *)
let kill q =
  if q.core > 0 then (q.doomed <- true; poke ipi_dev q.core)
  else exit_proc q (-1)
let sys_kill p =
  match List.filter (fun q -> q.pid = reg p 1) !procs with
  | [ q ] -> kill q; result p 0
  | _ -> raise Bad

(* trace(pid): a descriptor on a process, for its tracer (debug): what is
 * written to it a command, what is read the answers and the process's
 * stops (command, stop). trace(0): the caller traced by its parent from
 * now on, so that it stops at its next exec, the way a debugger starts
 * a program; the parent's trace(pid) gives the descriptor, before or
 * after. Not for the first process, the caller itself, or a process
 * another one traces *)
let sys_trace p =
  let make q tracer =
    let t =
      { tpid = q.pid; tracer = tracer; stops = []; said = []; watchers = 0;
        calls = false; call = -1; ret = -1; step = false; over = -1;
        follow = false } in
    q.traced <- Some t;
    t in
  if reg p 1 = 0 then begin
    (match p.traced with
     | Some t -> if t.tracer <> p.parent then raise Bad
     | None -> if p.parent = 0 then raise Bad else ignore (make p p.parent));
    result p 0
  end
  else
    match List.filter (fun q ->
      q.pid = reg p 1 && q.pid <> p.pid && q.pid <> 1) !procs with
    | [ q ] ->
        let t =
          match q.traced with
          | Some t when t.tracer = p.pid -> t
          | None -> make q p.pid
          | _ -> raise Bad in
        let given () =
          let k = fdalloc p (Trace t) in
          t.watchers <- t.watchers + 1;
          result p k in
        (* on another core: called back (a traced process stays on core
         * 0), the descriptor given when it is back, its frame then its
         * registers *)
        if q.core > 0 then
          (poke ipi_dev q.core; block p (fun () -> q.core <= 0 && (given (); true)))
        else given ()
    | _ -> raise Bad

(* seek(fd, n, whence): a file's offset at n from its start (0), from
 * where it is (1) or from its end (2), as Plan 9's; the new offset *)
let sys_seek p =
  match fd p (reg p 1) with
  | Open o ->
      let size =
        match o.node with
        | Rom (_, n) -> n
        | Data d -> d.dsize
        | Disk (r, i) -> let _, n, _ = fs_kind r i in n
        | n -> String.length (contents n) in
      let off =
        reg p 2
        + (match reg p 3 with
           | 0 -> 0
           | 1 -> o.off
           | 2 -> size
           | _ -> raise Bad) in
      if off < 0 then raise Bad;
      o.off <- off;
      result p off
  | _ -> raise Bad

(* stat(path, buf): the path's entry, as its directory has it (80 bytes,
 * user.h's dirent), at buf: 0, or -1 when it is not there (old: none, a
 * program read the whole directory for one name: ls -l of /bin, three
 * times a name, 1.7 billion instructions) *)
let sys_stat p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk !top ns with
  | Some node ->
      let e = entry (match List.rev ns with n :: _ -> n | [] -> "/") node in
      user_write p (reg p 2) e;
      result p 0
  | None -> raise Bad

let sys_chdir p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk !top ns with
  | Some n when is_dir n -> p.cwd <- ns; result p 0
  | _ -> raise Bad

(* ready(fds, n, until): the first of n descriptors (32 at most) that a
 * read would not wait on; -1 when the clock reaches until (0: no
 * limit; with no descriptor, a sleep). What a program with a mouse, a
 * keyboard and a picture to move waits on: one closure, as any wait *)
let sys_ready p =
  let n = reg p 2 and until = reg p 3 in
  if n < 0 || n > 32 then raise Bad;
  let rec list i =
    if i >= n then []
    else
      (let k = peek (user p (reg p 1 + (4 * i)) 4) in k, fd p k)
      :: list (i + 1) in
  let l = list 0 in
  block p (fun () ->
    match List.filter (fun (_, f) -> readable f) l with
    | (k, _) :: _ -> result p k; true
    | [] ->
        if until > 0 && !ticks >= until then (result p (-1); true)
        else
          (if until > 0 && (!alarm = 0 || until < !alarm) then alarm := until;
           false))

(* by their numbers, the machine's sys n: exit, write and read first,
 * tiny-cpu's own (libc's). A call that changed the disk is committed
 * when it ends, but a write: a file's writes are committed by the next
 * call that is not one, its close at the latest (TinyKernelFS.mli) *)
let syscall p n =
  (try
    match n with
    | 0 -> exit_proc p (reg p 1)
    | 1 -> sys_rw p write false
    | 2 -> sys_rw p read true
    | 3 -> sys_fork p
    | 4 -> sys_exec p
    | 5 -> sys_wait p
    | 6 -> result p p.pid
    | 7 -> sys_open p
    | 8 -> sys_close p
    | 9 -> sys_pipe p
    | 10 -> sys_dup p
    | 11 -> sys_mkdir p
    | 12 -> sys_unlink p
    | 13 -> sys_chdir p
    | 14 -> sys_kill p
    | 15 -> sys_ready p
    | 16 -> result p !ticks
    | 17 -> sys_box p
    | 18 -> sys_dial p
    | 19 -> sys_listen p
    | 20 -> sys_getcwd p
    | 21 -> sys_link p
    | 22 -> sys_rawcons p
    | 23 -> sys_trace p
    | 24 -> sys_seek p
    | 25 -> result p (date ())
    | 26 -> sys_stat p
    (* the seed: the machine's, or the clock when it has none, so that a
     * game is another each time *)
    | 27 -> result p (match peek seed_dev with 0 -> !ticks | s -> s)
    | 28 -> sys_spawn p
    | _ -> result p (-1)
  with Bad | No_room -> result p (-1) | Disk_full -> result p (-1));
  if n <> 1 then fs_commit ()

(* A traced process that stops at its calls (trace) stops before each,
 * its tracer told the call's number and its first three registers,
 * and after it, told its result: at once, or when it ends if it waits
 * (runnable). An exit has no after (its end is said), and an exec's is
 * its stop at its new program's first instruction. *)
let returned p n =
  pause p ("ret " ^ string_of_int n ^ " " ^ string_of_int (reg p 1))
let called p n =
  syscall p n;
  match p.traced, p.state with
  | _ when not (List.exists (fun q -> q.pid = p.pid) !procs) -> ()
  | Some t, Ready when t.calls -> returned p n
  | Some t, Ready when t.step -> stop p "step"
  | Some t, Waiting _ when t.calls -> t.ret <- n
  | _ -> ()
let call p n =
  match p.traced with
  | Some t when t.call >= 0 -> t.call <- -1; called p n
  | Some t when t.calls ->
      t.call <- n;
      pause p ("call " ^ String.concat " " (List.map string_of_int
                                             [ n; reg p 1; reg p 2; reg p 3 ]))
  | _ -> syscall p n

(* a traced process whose wait ended, stopped if its tracer asked for
 * the call's end or a step *)
let waited p =
  match p.traced with
  | Some t when t.ret >= 0 -> let n = t.ret in t.ret <- -1; returned p n; true
  | Some t when t.step -> stop p "step"; true
  | _ -> false
