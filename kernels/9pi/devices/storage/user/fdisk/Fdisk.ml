(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-fdisk: Plan 9's fdisk (principia's
 * kernel/devices/storage/user/386/prep/fdisk.c), its -p only: a disk's
 * partitions, read in its first sector (the MBR: four entries of 16
 * bytes at 446, each a type, a first sector, a number of sectors),
 * printed as the lines the disk's driver takes:
 *
 *     fdisk -p /dev/sdM0/data > /dev/sdM0/ctl
 *
 * and /dev/sdM0/dos is the FAT's partition, for dossrv. The kernel
 * knows nothing of partition tables: a program reads them and tells
 * it. A name is the type's (dos for a FAT, plan9, linux, other...),
 * with a number when it is taken (dos1; plan9.1).
 *
 * Not fdisk's editor (its other 1,000 lines), nor the partitions
 * inside an extended one.
 *
 *     the first sector, 512 bytes
 *     0     the boot code                        446 bytes
 *     446   entry 0 | entry 1 | entry 2 | entry 3    16 each
 *     510   55 aa   the mark of a table (read here as 0xaa55)
 *
 *     an entry
 *     0  active?   1-3  first sector, as cylinder, head, sector
 *     4  type      5-7  last sector, the same way
 *     8  first sector, by number (4 bytes, the low first)
 *     12 how many sectors (4 bytes)
 *
 *     an entry of type 0c, first sector 8192, 524288 sectors,
 *     prints   part dos 8192 532480
 *
 * The three numbers a disk had to be given to find a sector
 * (cylinder, head, sector) are not read: every disk since takes a
 * sector's number.
 *
 * cs-history:
 * This table is the IBM PC's, from PC DOS 2.0 (1983), when the XT
 * got a hard disk that several systems might share: four entries
 * because that is what fitted after the boot code, a type a byte
 * (a list no one owns: 0x39 is Plan 9's), 32 bits for a sector's
 * number, so 2 TB at most with sectors of 512 bytes. Its
 * replacement, GPT, came with EFI; SD cards, and so a Raspberry Pi's
 * firmware, still use this one, which is why ix reads it and
 * nothing else. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

(* a type's name; "" for an empty entry and for what holds other partitions *)
let name_of kind =
  match kind with
  | 0x01 | 0x04 | 0x06 | 0x0b | 0x0c | 0x0e -> "dos"
  | 0x07 -> "ntfs"
  | 0x39 -> "plan9"
  | 0x82 -> "linuxswap"
  | 0x83 -> "linux"
  | 0x8e -> "linuxlvm"
  | 0xa5 -> "bsd386"
  | 0xa9 -> "netbsd"
  | 0xda -> "other"
  | 0xee -> "efiprotect"
  | 0xef -> "efi"
  | _ -> ""


let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | [ "-p"; disk ] -> (
      match FS.open_in_fd caps disk with
      | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "fdisk: opendisk %s: %s\n" disk (Unix.error_message e)); Exit.Err "opendisk"
      | fd ->
          let b = Bytes.create 512 in
          let n = try Unix.read fd b 0 512 with Unix.Unix_error _ -> 0 in
          Unix.close fd;
          let mbr = Bytes.to_string b in
          if n < 512 || Binary.le16 mbr 510 <> 0xaa55 then begin Console.eprint caps (Printf.sprintf "fdisk: %s: no partition table\n" disk); Exit.Err "table" end
          else begin
            let taken = ref [] in
            for k = 0 to 3 do
              let o = 446 + (16 * k) in
              let name = name_of (Char.code mbr.[o + 4]) and start = Binary.le32 mbr (o + 8) and size = Binary.le32 mbr (o + 12) in
              if name <> "" && size > 0 then begin
                (* (not names like plan90) *)
                let sep = match name.[String.length name - 1] with '0' .. '9' -> "." | _ -> "" in
                let rec unique i = let n = if i = 0 then name else name ^ sep ^ string_of_int i in if List.mem n !taken then unique (i + 1) else n in
                let name = unique 0 in
                taken := name :: !taken;
                (* a line a write: the driver's ctl file takes one command at a time *)
                Console.print caps (Printf.sprintf "part %s %d %d\n" name start (start + size));
                flush (Console.stdout caps)
              end
            done;
            Exit.OK
          end)
  | _ -> Console.eprint caps "usage: fdisk -p disk   (the partitions, as lines for the disk's ctl file)\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
