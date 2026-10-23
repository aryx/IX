(* Game: the server's frame and what the client is given to draw and
 * play (Quake's sv_main.c and sv_phys.c's SV_Physics, host.c's frame;
 * cl_main.c's entities; QuakeC's StartFrame and PlayerPreThink).
 *
 *   each frame:
 *     the player's weapon (Weapons: the attack key, the weapon asked)
 *     every entity (Physics.run: its move by its movetype, its think
 *       when its time came: a monster's frame, a grenade's fuse); a
 *       missile's trail from where it was to where it is
 *     the triggers the player is in (a backpack), the items it is on
 *     the effects made (Edict's) become particles
 *
 * The world's state is Edict's; this is its frame and its spawning:
 * the map's monster_* by Monsters (but with nomonsters), the player's
 * start: 100 health, the axe and the shotgun, 25 shells (client.qc's
 * SetNewParms).
 *
 * Where it stands in mini-quake: Quake.ml makes one, calls [frame]
 * after Play's, [draw] after Render's world, plays the [sounds].
 *
 * What is ours: this folder, game/, is what Quake did not write in C.
 * Quake's engine (the renderer, the sound, the network, the traces and
 * moves of server/) knew nothing of a monster, a weapon or a door; all
 * of that was QuakeC, a language of its own, compiled to progs.dat and
 * run by the engine in a virtual machine. Here it is OCaml, compiled
 * with the rest: no compiler of QuakeC, no progs.dat, no VM. Each
 * module says which .qc it was written from (ai.qc, combat.qc,
 * grunt.qc ...), to read beside LibreQuake's qcsrc/ or id's.
 *
 * cs-history:
 * Doom (1993) had its game in C, in the engine: its monsters were
 * info.c's tables of states, compiled into the executable (mini-doom's
 * Info). Players changed them anyway, by patching the executable's
 * tables with DeHackEd; a new monster's behaviour, a new weapon, could
 * not be written, only numbers changed. For Quake (1996) John Carmack
 * made the game a program apart: QuakeC, a small C-like language
 * (floats, vectors, strings, entities, functions; no integers, no
 * structures, no pointers), compiled by id's qcc to progs.dat, a
 * bytecode of a few dozen instructions, each three addresses in a
 * table of globals, run by the engine's interpreter (pr_exec.c). The
 * engine gave it builtins (pr_cmds.c: traceline, sound, walkmove,
 * aim ...), and it gave the engine the functions to call
 * (StartFrame, PlayerPreThink, an entity's think and touch).
 *
 * design:
 * Why a VM, in 1996: Quake ran on DOS, which had no libraries loaded
 * at run time, so a mod could not be native code without a new
 * executable; a progs.dat ran the same on DOS, Windows, Linux and the
 * other ports, built once; and it could not crash the engine nor reach
 * the machine, only the builtins, so anyone could download a mod.
 * Mods were what Carmack wanted from it: Team Fortress, capture the
 * flag and the bots of 1996-97 were QuakeC. The price was speed (an
 * interpreter, every number a float) and a weak language.
 *
 * evolution:
 * Quake II (1997) took the other road: its game a native library
 * (gamex86.dll), plain C, fast, and trusted as the engine is. Quake III
 * (1999) came back to a VM, of its own bytecode (QVM), but compiled
 * from C by a modified lcc (q3lcc, Fraser and Hanson's retargetable
 * compiler) and q3asm, and turned into native code at load on x86
 * (a JIT): C's language, the VM's safety and portability, nearly
 * native speed. lcc is Quake III's, not Quake's: Quake's compiler was
 * id's own qcc.
 *
 * comeback:
 * The game's logic in a language the engine runs, safe and portable,
 * is everywhere since: UnrealScript (1998), Lua in World of Warcraft's
 * interface and in many engines, and now WebAssembly, a VM of a few
 * instructions again, compiled to native code at load as Quake III's.
 *
 * wib:
 * Why not here: ix's games are read to learn how they work, and one
 * language from the engine to the monster is one thing to read; a
 * QuakeC compiler and its VM would be a plan of their own (ix has
 * interpreters to learn from already: mini-rc's, Scheme's, Forth's),
 * and on a Pi an interpreter under mini-ml's code would cost the
 * frames. OCaml's types also catch what QuakeC found at run time (an
 * entity's field misspelled is a new field). What it costs: no mod
 * without recompiling mini-quake, and no progs.dat of anyone's can
 * run; the game is Quake's as far as these modules wrote it. *)

type t = {
  world : Edict.world;
  particles : Particles.t;
  things : Things.thing list; (* the items standing *)
}

(* [create level play models things monsters ways]: the world, its
 * monsters spawned if asked; [ways] the playground's AI (ai=ways) *)
val create :
  Model.t ->
  Play.t ->
  (string -> Alias.t option) ->
  Things.thing list ->
  bool ->
  bool ->
  t

(* [give_all g]: impulse 9: every weapon, ammunition *)
val give_all : t -> unit

(* [frame g dt attack impulse]: the game's dt seconds (after Play's) *)
val frame : t -> float -> bool -> int -> unit

(* [draw g v]: the entities' models, the particles, the weapon in hand,
 * into v after the world *)
val draw : t -> View.t -> unit

(* the sounds made since the last call, in order *)
val sounds : t -> Edict.sound list

(* the player dead, and for how long *)
val dead_for : t -> float option

(* the status line: health, armor, ammunition, kills *)
val status : t -> string
