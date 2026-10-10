(* mini-singml: a program's manifest read (decision 5 of
 * kernels/singularity's plan_system_singularity.md): what it needs of
 * the machine, which the kernel gives it at its start and no more. A
 * manifest is a file in OCaml's syntax beside the program's Main.ml,
 * Main.manifest, a name a resource:
 *
 *   let uart = registers 0x201000 0x1000    a device's registers: where
 *                                           among the peripherals', how many bytes
 *   let keys = interrupt 57                 an interrupt, by its number
 *
 * From it, two texts: the program's module Given, where each name is
 * the resource (a Sip.registers, a Sip.interrupt), with the endpoints
 * its parent gave it; and the kernel's list of what to give.
 *
 * design:
 * A driver that can only touch what it declared. In Unix a driver
 * is kernel code and may write any register and any memory; what it
 * uses is known by reading it. Here the declaration is data, read
 * before the program runs, and the program has no other way to a
 * device (Safe refuses the rest): the console's driver holds the
 * UART's page of registers and interrupt 57, and a mistake in it
 * cannot reach the timer. Singularity went further with the same
 * data: the system checked at installation that no two drivers
 * asked for the same registers.
 *
 * others:
 * A phone's application manifest (Android's permissions) and a
 * container's or a WebAssembly component's declared imports are the
 * same move: what a program may reach, said outside its code, and
 * enforced by who starts it.
 *
 * References: Hunt and Larus (2007), on manifest-based programs;
 * Spear, Roeder, Hodson, Hunt and Levi, "Solving the Starting
 * Problem: Device Drivers as Self-Describing Artifacts" (EuroSys
 * 2006). *)

type resource =
  | Registers of int * int
  | Interrupt of int

(* the line, the message *)
exception Error of int * string

(* a manifest's resources, each with its name, in order ([] for no manifest) *)
val read : Ast.structure -> (string * resource) list

(* Given's two files' text; source is the manifest's file, named in their first line *)
val ml : string -> (string * resource) list -> string
val mli : string -> (string * resource) list -> string
(* the kernel's: an OCaml list of Programs.grant *)
val grants : (string * resource) list -> string
