(* Wad: Doom's file of everything, "Where's All the Data?" -- the
 * levels, the pictures, the palette, the sounds, each a lump, a
 * name of eight letters and its bytes, in one file a directory ends:
 *
 *   0   "IWAD" (the game's own) or "PWAD" (a patch: lumps that replace
 *       or add to the game's), the number of lumps, where the
 *       directory is
 *   12  the lumps' bytes, one after the other
 *   ... the directory, 16 bytes a lump: where its bytes are, how
 *       many, its name (eight bytes, the rest zeros)
 *
 *   a level is a marker lump (E1M1, no bytes) and the ten after it,
 *   in this order: THINGS LINEDEFS SIDEDEFS VERTEXES SEGS SSECTORS
 *   NODES SECTORS REJECT BLOCKMAP; the flats are between F_START
 *   and F_END, the patches anywhere (PNAMES names them).
 *
 * Every number is little-endian, a short of 16 bits signed or an int
 * of 32. A name is looked up from the end: a PWAD loaded after the
 * IWAD wins (W_CheckNumForName's order), which is all Doom's mods were.
 *
 * Where it stands in mini-doom: what Level, Textures and Mkwad read and
 * Mkwad writes; nothing here knows what a lump means.
 *
 * history:
 * The format is id's, for Doom (1993); Quake's PAK and WAD2 (1996) are
 * its children, and so, by way of Doom's modders, every game's archive
 * of data since. *)

type lump = { name : string; data : string }

type t = { kind : string; lumps : lump array }

(* [parse bytes]: a WAD file's lumps; Failure if it is none *)
val parse : string -> t

(* [find wad name]: the last lump of that name (in capitals) *)
val find : t -> string -> lump option

(* [get wad name]: the same, Failure if there is none *)
val get : t -> string -> string

(* [index wad name]: where that lump is in [wad.lumps], the last one *)
val index : t -> string -> int option

(* [between wad first last]: the lumps after the marker [first] and
 * before [last] (F_START, F_END: the flats), markers inside left out *)
val between : t -> string -> string -> lump list

(* [write kind lumps]: a WAD file of them *)
val write : string -> lump list -> string

(* the numbers in a lump: an unsigned byte, a short (signed), an int
 * of 32 bits (signed: on a Pi1's 31-bit ints only small ones are
 * right, which every int of a WAD is), and a name of eight bytes at
 * an offset, its zeros cut, in capitals *)
val u8 : string -> int -> int
val short : string -> int -> int
val int32 : string -> int -> int
val name8 : string -> int -> string

(* the same, written into a Buffer *)
val add_short : Buffer.t -> int -> unit
val add_int32 : Buffer.t -> int -> unit
val add_name8 : Buffer.t -> string -> unit
