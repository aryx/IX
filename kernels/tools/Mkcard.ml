(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkcard: an SD card's image for a Raspberry Pi (plan_rio.md,
 * stage 3), made on the host. The card, in sectors of 512 bytes:
 *
 *     0             the MBR: four partitions' entries (two used), and
 *                   its signature
 *     2048 ..       the first partition, a FAT16: what the Pi's
 *                   firmware reads before any kernel runs (its own
 *                   files, config.txt, the kernels), and what a dossrv
 *                   serves afterwards
 *     then ..       the second partition, to the card's end: a file
 *                   system's image given as it is (-fs), or zeros: the
 *                   kernel's own file system's place
 *
 * The FAT16, the simplest that the firmware takes:
 *
 *     0             the boot sector: the geometry (BPB)
 *     1 ..          the FAT, twice: 16 bits a cluster (4 sectors), the
 *                   next one of its file, 0xffff at the end, 0 when free
 *     then          the root directory, 512 entries of 32 bytes: a name
 *                   (8 and 3 characters, capitals, padded with spaces),
 *                   a date, the first cluster, the length
 *     then          the clusters, numbered from 2
 *
 * Only what a card that is made once needs: files at the root, each in
 * consecutive clusters, names of 8.3 characters, each part in one case
 * (no long names, VFAT's: a name that does not fit is refused). The usage: [help].
 *
 * A file of three clusters starting at the fifth, in the table:
 *
 *     the directory's entry     KERNEL  IMG ... first cluster 5
 *     the FAT    index:   2    3    4    5    6    7     8
 *                        ...  ...  ...   6    7  0xffff  0
 *
 * The table is the file allocation table the format is named
 * after: one linked list a file, all the links in one place at the
 * disk's start, where xv6's format (mini-mkfs, and mini-xv6's Fs)
 * has a list of block numbers in each file's inode. Reading byte n
 * of a file follows n / 2048 links; a file has no number, only its
 * directory entry, so it cannot have two names.
 *
 * Where it stands: the Pi's boot. The processor that starts is the
 * VideoCore; its ROM reads the first FAT partition of the card for
 * bootcode.bin, which loads the GPU's firmware (start_cd.elf
 * here), which reads config.txt and loads the file named there as
 * the ARM's kernel (kernels/firmware has these files and says
 * where they are from). So a card must begin this way
 * whatever the kernel's own file system is; mini-9pi then serves
 * this partition by its dossrv and the second by its Kfs.
 *
 * cs-history:
 * The table is Marc McDonald's, for Microsoft's Standalone Disk
 * BASIC (1977), with 8 bits a cluster for floppy disks; Tim
 * Paterson took it with 12 bits for 86-DOS (1980), which became
 * MS-DOS. 16 bits came with the PC AT's hard disk (DOS 3.0, 1984),
 * 32 with Windows 95's second release (1996); the MBR's table of
 * four partitions is DOS 2.0's (1983), for the XT's 10 MB disk.
 * (Dates from memory.)
 *
 * why-win:
 * A format with no owner, no permissions, no links, names of eleven
 * capitals and a table that is lost with one bad sector is what
 * every camera, firmware and operating system reads, forty years
 * on: because it is the one a boot ROM can read in a few hundred
 * instructions, and the one everybody already read. UEFI's system
 * partition is a FAT for the same reason as the Pi's first.
 *
 * References: "Microsoft Extensible Firmware Initiative FAT32 File
 * System Specification" (version 1.03, 2000): the boot sector's
 * fields and the three FATs, the document every implementation
 * follows. The Raspberry Pi's documentation, "The boot folder" and
 * "config.txt". plan_rio.md, stage 3. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let help = {|usage: mini-mkcard [-m megabytes] [-fat megabytes] [-date seconds] [-fs image] out name=file...
An SD card's image for a Raspberry Pi: an MBR, a FAT16 partition with the files
given at its root (the firmware's, config.txt, the kernels), and a second
partition to the card's end (zeros, or -fs's image).
  mini-mkcard card.img bootcode.bin=firmware/pi1/bootcode.bin config.txt=config.txt kernel.img=kernel-pi1.img
                              a card of 64 MB, its FAT of 32 MB
  mini-mkcard -m 128 -fat 64 -fs fs.img card.img ...
                              128 MB, 64 for the FAT, fs.img in the second partition
-date: the files' date (seconds since 1970; the default 0 is 1980-01-01, FAT's first).
QEMU wants a card's megabytes a power of 2.
|}

let sector = 512
let per_cluster = 4                (* sectors: clusters of 2 KB *)
let root_entries = 512
let first = 2048                   (* the first partition's sector: 1 MB in *)


(* "kernel.img" as a directory has it, KERNEL  IMG, and the bits that
 * say which part was in small letters (Windows NT's: 0x08 the name,
 * 0x10 its extension); a part of both cases would want a long name *)
let name83 name =
  let base, ext = match String.rindex_opt name '.' with
    | Some k -> String.sub name 0 k, String.sub name (k + 1) (String.length name - k - 1)
    | None -> name, "" in
  let fits s n = String.length s <= n && String.for_all (fun c -> c > ' ' && c < '\127' && not (String.contains "\"*+,./:;<=>?[\\]|" c)) s in
  let one_case s = s = String.lowercase_ascii s || s = String.uppercase_ascii s in
  if base = "" || not (fits base 8) || not (fits ext 3) || not (one_case base) || not (one_case ext) then
    failwith (name ^ ": not a name of 8.3 characters, each part in one case");
  let pad s n = String.uppercase_ascii s ^ String.make (n - String.length s) ' ' in
  let small s bit = if s <> String.uppercase_ascii s then bit else 0 in
  pad base 8 ^ pad ext 3, small base 0x08 lor small ext 0x10

(* FAT's date and time: years from 1980, two seconds a unit *)
let dos_date t =
  let tm = Unix.gmtime (if t < 315532800.0 then 315532800.0 else t) in
  ((tm.Unix.tm_year - 80) lsl 9) lor ((tm.Unix.tm_mon + 1) lsl 5) lor tm.Unix.tm_mday,
  (tm.Unix.tm_hour lsl 11) lor (tm.Unix.tm_min lsl 5) lor (tm.Unix.tm_sec / 2)

(* an MBR's entry k: bootable or not, the type, the first sector, how
 * many (the cylinders, heads and sectors are not said: 0xfe 0xff 0xff,
 * "see the sectors' numbers") *)
let partition mbr k ~boot kind start sectors =
  let o = 446 + (16 * k) in
  Bytes.set mbr o (if boot then '\x80' else '\000');
  Bytes.blit_string "\xfe\xff\xff" 0 mbr (o + 1) 3;
  Bytes.set mbr (o + 4) (Char.chr kind);
  Bytes.blit_string "\xfe\xff\xff" 0 mbr (o + 5) 3;
  Binary.set_le32 mbr (o + 8) start;
  Binary.set_le32 mbr (o + 12) sectors

(* the FAT16 of [sectors] sectors with [files] (a name's 11 characters,
 * the bytes): its sectors before the clusters, as bytes, then the
 * files, each padded to whole clusters *)
let fat16 ~sectors ~date files =
  let root_sectors = root_entries * 32 / sector in
  (* the FAT's sectors: 2 bytes a cluster, and the clusters are what the two FATs leave *)
  let rec size fat = let clusters = (sectors - 1 - root_sectors - (2 * fat)) / per_cluster in
    if (clusters + 2) * 2 <= fat * sector then fat, clusters else size (fat + 1) in
  let fat_sectors, clusters = size 1 in
  if clusters < 4085 || clusters > 65524 then failwith "the FAT's size: not a FAT16's (8 to 128 MB with clusters of 2 KB)";
  let boot = Bytes.make sector '\000' in
  Bytes.blit_string "\xeb\x3c\x90mkfs.fat" 0 boot 0 11;
  Binary.set_le16 boot 11 sector; Bytes.set boot 13 (Char.chr per_cluster); Binary.set_le16 boot 14 1; Bytes.set boot 16 '\002';
  Binary.set_le16 boot 17 root_entries; Binary.set_le16 boot 19 (if sectors < 65536 then sectors else 0); Bytes.set boot 21 '\xf8';
  Binary.set_le16 boot 22 fat_sectors; Binary.set_le16 boot 24 32; Binary.set_le16 boot 26 64; Binary.set_le32 boot 28 first; Binary.set_le32 boot 32 (if sectors < 65536 then 0 else sectors);
  Bytes.set boot 36 '\x80'; Bytes.set boot 38 '\x29'; Binary.set_le32 boot 39 0x1b0a2026;
  Bytes.blit_string "NO NAME    FAT16   " 0 boot 43 19; (* (no label) *)
  Binary.set_le16 boot 510 0xaa55;
  let fat = Bytes.make (fat_sectors * sector) '\000' and root = Bytes.make (root_sectors * sector) '\000' in
  Binary.set_le16 fat 0 0xfff8; Binary.set_le16 fat 2 0xffff;
  let day, time = dos_date date in
  let next = ref 2 in
  List.iteri (fun k ((name, small), data) ->
    let n = (String.length data + (per_cluster * sector) - 1) / (per_cluster * sector) in
    if k >= root_entries || !next + n > clusters + 2 then failwith "the files do not fit in the FAT partition (-fat)";
    for c = !next to !next + n - 1 do Binary.set_le16 fat (2 * c) (if c = !next + n - 1 then 0xffff else c + 1) done;
    let o = 32 * k in
    Bytes.blit_string name 0 root o 11;
    Bytes.set root (o + 11) '\x20';
    Bytes.set root (o + 12) (Char.chr small);
    Binary.set_le16 root (o + 14) time; Binary.set_le16 root (o + 16) day; Binary.set_le16 root (o + 18) day; Binary.set_le16 root (o + 22) time; Binary.set_le16 root (o + 24) day;
    Binary.set_le16 root (o + 26) (if n = 0 then 0 else !next);
    Binary.set_le32 root (o + 28) (String.length data);
    next := !next + n) files;
  let padded data = data ^ String.make ((per_cluster * sector) - 1 - ((String.length data + (per_cluster * sector) - 1) mod (per_cluster * sector))) '\000' in
  Bytes.to_string boot ^ Bytes.to_string fat ^ Bytes.to_string fat ^ Bytes.to_string root, List.map (fun (_, data) -> padded data) files

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let megabytes = ref 64 and fat_megabytes = ref 32 and date = ref 0.0 and fs = ref None in
  let rec options = function
    | "-m" :: n :: rest when int_of_string_opt n <> None -> megabytes := int_of_string n; options rest
    | "-fat" :: n :: rest when int_of_string_opt n <> None -> fat_megabytes := int_of_string n; options rest
    | "-date" :: n :: rest when float_of_string_opt n <> None -> date := float_of_string n; options rest
    | "-fs" :: file :: rest -> fs := Some file; options rest
    | rest -> rest in
  match options (List.tl (Array.to_list argv)) with
  | args when List.mem "-h" args || List.mem "--help" args -> Console.print caps help; Exit.OK
  | out :: (_ :: _ as pairs) when out <> "" && out.[0] <> '-' -> (
      try
        let total = !megabytes * 2048 and fat_total = !fat_megabytes * 2048 in
        if first + fat_total >= total then failwith "the FAT partition does not fit in the card (-m, -fat)";
        let files = List.map (fun pair ->
          match String.index_opt pair '=' with
          | None -> failwith (pair ^ ": not name=file")
          | Some k -> name83 (String.sub pair 0 k), FS.read caps (Fpath.v (String.sub pair (k + 1) (String.length pair - k - 1)))) pairs in
        let head, datas = fat16 ~sectors:fat_total ~date:!date files in
        let second = first + fat_total in
        let image = match !fs with Some file -> FS.read caps (Fpath.v file) | None -> "" in
        if String.length image > (total - second) * sector then failwith "-fs's image does not fit in the second partition (-m)";
        let mbr = Bytes.make sector '\000' in
        partition mbr 0 ~boot:true 0x0e first fat_total;        (* a FAT16, its sectors by their numbers (LBA) *)
        partition mbr 1 ~boot:false 0xda second (total - second); (* "data, no file system known" *)
        Binary.set_le16 mbr 510 0xaa55;
        Fpath.v out |> FS.with_open_out caps (fun (chan : Chan.o) ->
          let oc = chan.oc in
          output_string oc (Bytes.to_string mbr);
          seek_out oc (first * sector);
          output_string oc head;
          List.iter (output_string oc) datas;
          seek_out oc (second * sector);
          output_string oc image;
          (* to the card's size: the rest a hole of zeros *)
          seek_out oc ((total * sector) - 1);
          output_char oc '\000');
        Exit.OK
      with Sys_error m | Failure m -> Console.eprint caps ("mini-mkcard: " ^ m ^ "\n"); Exit.Err m)
  | _ -> Console.eprint caps "usage: mini-mkcard [-m megabytes] [-fat megabytes] [-date seconds] [-fs image] out name=file...   (-h: how)\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
