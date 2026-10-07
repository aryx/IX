# mini-singularity, a tutorial

A walk through the system by its own files: a program, two processes,
a contract, a block that changes hands, a driver, and what is refused.
Every piece of code below is in this directory, as it is run; the
[README](README.md) says what the system is and how it is built, the
[plan](../../docs/plans/done/plan_system_singularity.md) why.

## 1. The shell

    ./mini-pi mini-singularity      (from ix's root; Ctrl-A x quits)

    mini-singularity
    mini-singularity's shell (help: what it knows)
    sing> ps
     0 init       waiting
     1 console    waiting
     2 shell      running
    sing> hello
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    hello ended with 3

Three processes at the start. `init` started the two others and waits
for the shell's end. `console` is the driver of the serial line.
`shell` reads a line and, if it is a program's name, starts a process
of it and waits for it. All of them, and the kernel, are in one
address space, at one privilege: there is no page table for a process
and no trap to call the kernel.

## 2. A program

`programs/hello/Main.ml`, whole but its header:

    let runs = ref 0

    let rec sum (n : int) (acc : int) : int =
      if n = 0 then acc else sum (n - 1) (acc + List.length (List.init 100 (fun i -> i + n)))

    let () =
      incr runs;
      print_string "hello: a process in the kernel's address space\n";
      Printf.printf "hello: run %d, %d cells\n" !runs (sum 10000 0);
      exit 3

An OCaml program as any other. It does not know where it runs: the
standard library's `print_string` ends as a call of the kernel's debug
line, `exit` as the process's end. Its million list cells are in **its
own heap** (two halves of 256k words), collected by **its own
collector**: each program is linked with its own run-time system.

To add one: a directory in `programs/` with its `Main.ml`, its name in
the mkfile's `PROGRAMS`, and `mini-mk`. What the build does with it:

1. `mini-singml -safe` reads the source and refuses what could reach
   another's memory (section 7);
2. mini-ml compiles it; mini-ld links it at its own address, 16 MB
   from the next program's;
3. its image is put in the kernel's, as data.

When a process of it is started, the kernel copies that image to the
address it was linked for and calls it. Run `hello` twice: it says
"run 1" both times, each process starting from the pristine copy. One
process of a program at a time: its memory is at one place.

## 3. Processes together

`programs/tick/Main.ml` (and `tock`, the same with its name):

    let () =
      for i = 1 to 3 do
        print_string (Printf.sprintf "tick %d\n" i);
        flush stdout;
        Sip.yield ()
      done;
      exit 1

`Sip` is what a program asks of the kernel beyond the standard
library. The system is cooperative: a process runs until it calls the
kernel, here to let the others run. `programs/selftest/Main.ml`
starts both and waits for them:

    let tick = spawn "tick" in          (* Sip.create, then Sip.start *)
    let tock = spawn "tock" in
    ...
    let a = Sip.join tick in
    let b = Sip.join tock in

    sing> selftest
    tick 1
    tock 1
    tick 2
    ...
    selftest: tick ended with 1, tock with 2

`tick` here is a **handle**: a small number that means something to
this process only, an index in a table the kernel keeps for it. A
process holds children, endpoints and blocks by handles, and nothing
else of the kernel.

## 4. A contract

Two processes talk by a **channel** and in no other way: they share no
memory. A channel has two endpoints, the importing (the client's) and
the exporting (the server's), and a **contract**: its messages, and a
state machine that says when each may be sent.
`contracts/Console.contract`, what the console's driver serves:

    type request = Write of Sip.block * int | Read
    type reply = Written of Sip.block | Key of int

    let rec serve = function
      | Write _ -> send Written; serve
      | Read -> send Key; serve

It is read from the server's side: in state `serve` a `Write` or a
`Read` is received; after a `Write`, `Written` is sent and the state
is `serve` again. mini-singml makes a module `Console` of it when the
image is built (see `_mk/7/kernel/singularity/Console.mli`;
`contracts/Pong.ml` is such a module written by hand, to be read):

    type imp                            (* the client's end *)
    type exp                            (* the server's *)
    val channel : unit -> imp * exp
    module Imp : sig
      val write : imp -> Sip.block -> int -> unit
      val read : imp -> unit
      val receive : imp -> reply
      ...
    module Exp : sig
      val written : exp -> Sip.block -> unit
      val key : exp -> int -> unit
      val receive : exp -> request
      ...

The server, `programs/console/Main.ml`:

    let e = Console.Exp.of_endpoint (Given.endpoint 0) in
    let rec serve () =
      (match Console.Exp.receive e with
       | Write (b, n) ->
           for i = 0 to n - 1 do put (Sip.get b i) done;
           Console.Exp.written e b
       | Read -> Console.Exp.key e (key ()));
      serve ()
    in
    try serve () with Sip.Closed -> exit 0

A client, `programs/shell/Main.ml`:

    let key () : char =
      Console.Imp.read console;
      match Console.Imp.receive console with Key c -> Char.chr c | Written _ -> ' '

And who connects them, `programs/init/Main.ml`: it makes the channel,
and gives an end to each before it starts.

    let client, server = Console.channel () in
    let console = create "console" in
    let shell = create "shell" in
    Sip.give console (Console.Exp.endpoint server);
    Sip.give shell (Console.Imp.endpoint client);
    Sip.start console;
    Sip.start shell;

A process finds what its parent gave it as `Given.endpoint 0`, 1...;
`of_endpoint` asks the kernel whether it is an end of that contract.
An endpoint may also travel in a message (`contracts/Intro.contract`:
`Meet of Pong.imp`): that is how a process is handed a service it was
not started with.

## 5. A block that changes hands

A message carries a tag, one integer, and maybe a **block of the
exchange heap**: bytes that are in no process's heap. A block has one
owner. Sent, it is the receiver's: nothing is copied, whatever its
size. The shell lends its one block to the driver at each write, and
has it back:

    let buffer = ref (Sip.alloc 256)

    let rec print (s : string) : unit =
      ...
        Sip.write !buffer 0 (String.sub s 0 n);
        Console.Imp.write console !buffer n;
        (match Console.Imp.receive console with Written b -> buffer := b | Key _ -> ());

Its owner reads and writes a block where it is (`Sip.get`, `set`,
`sub`, `write`), with no call of the kernel. Once sent, the sender's
handle is no longer one: `programs/ping/Main.ml` tries,

    Pong.Imp.text pong b (String.length s);
    (try say (Printf.sprintf "ping: still reads its block: %c\n" (Sip.get b 0))
     with Sip.Not_held -> say "ping: the block is no longer its own\n");

and prints the second line.

## 6. A driver

A driver is a process. What it may touch of the machine is what its
**manifest** asks, `programs/console/Main.manifest`:

    let uart = registers 0x201000 0x1000
    let keys = interrupt 57

The kernel gives it those two at its start, and mini-singml makes the
program's module `Given`, where they are by their names
(`Given.uart : Sip.registers`, `Given.keys : Sip.interrupt`). The
driver, again:

    let put (c : char) : unit =
      while Sip.io_read Given.uart fr land txff <> 0 do () done;
      Sip.io_write Given.uart dr (Char.code c)

    let rec key () : int =
      if Sip.io_read Given.uart fr land rxfe <> 0 then begin Sip.wait Given.keys; key () end
      else Sip.io_read Given.uart dr land 0xff

`Sip.io_read` takes a `Sip.registers` and an offset in it: there is
no way to say another address. A program with no manifest has no
registers at all. While every process waits (the shell for a key, the
driver for its interrupt), the kernel stops the processor until an
interrupt comes.

## 7. What is refused, and when

**When the program is compiled**, by OCaml's types: a message of the
other end's, or with the wrong argument. `Console.Exp.read` is no
value; `Console.Imp.write console "text" 4` has no type.

**When the image is built**, by `mini-singml -safe`: code that could
make an address or take a value for what it is not.

    programs/tick/Main.ml:13: module Obj is not one a process may name

No `external`, no `Obj`, `Marshal` or `Unix`, no `unsafe_` name, no
extension; the modules a program may name are a list
(`singml/Safe.ml`). And a contract that is not well made (a state
where both ends may send, a message no state names) is refused when
its module is made.

**When the program runs**, by the kernel: a message its contract does
not allow in the channel's state. `programs/rogue/Main.ml` sends a
second `Ping` before the first's `Pong`:

    Pong.Imp.ping pong 1;
    Pong.Imp.ping pong 2;

    mini-singularity: rogue ended: Pong.Ping is not allowed in state Serve/Ping.
    pong: the channel is closed
    selftest: rogue ended with 255, pong with 0

It compiles; the kernel ends it at the second; its server sees the
channel closed, and the system goes on. So for a block used after it
was sent (section 5), and for a program that fails by itself:

    sing> crash
    crash: about to fail
    Fatal error: uncaught exception Failure("hd")
    crash ended with 2
    sing>

Singularity's compiler finds the last two kinds before the system
runs. Here they are found when they happen: that is this system's
loss against the original, and why its checks (`mini-mk check`) run
programs that break the rules.

## 8. Your own

- **A program**: `programs/name/Main.ml`; its name in the mkfile's
  `PROGRAMS`; `mini-mk`; its name typed at the shell.
- **A contract**: `contracts/Name.contract` (`mini-singml -h` says
  the syntax); its name in the mkfile's `CONTRACTS` and `MADE`. Every
  program is linked with every contract.
- **A server and its client**: a third program makes the channel and
  gives an end to each (`init`, or `selftest` for Pong).
- **A driver**: `programs/name/Main.manifest`. The kernel knows one
  interrupt today, the serial line's (57).

What there is not yet: arguments for a program, several processes of
one program, a message of more than one integer, a name service (a
process must be given its endpoints by its parent), files.
