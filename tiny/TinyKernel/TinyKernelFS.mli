(* Tiny file system: TinyKernel.ml's part that keeps files on the disk,
 * as TinyKernelGraphics.ml is its part that draws. The kernel mounts it
 * on /usr; the rest of the tree stays in memory and is lost at the
 * halt. Like the other parts, it is written in tiny-ml's ML, which is
 * also OCaml, so it is tested on the host first:
 *
 *     tiny-ml -o kernel.tm memory.ml ... TinyKernelFS.ml TinyKernel.ml   (TinyKernel/Makefile)
 *     dune build ./tiny/tests/TinyKernelFS_tests/Host.exe                    (TinyKernelFS_test.sh)
 *
 * It needs two things from the machine: TinyMemory's bytes, and a way
 * to move a block between the disk and memory ([fs_io]).
 *
 * {b The classic layout.} The disk is made of blocks of 1 KB. A file is
 * an inode: its type, its size, its number of links, and the numbers of
 * its blocks. The first 11 blocks are listed in the inode itself; after
 * them comes an indirect block (256 more numbers), then a double
 * indirect one (256 blocks of 256 numbers). A directory is a file whose
 * contents are entries, each a name and an inode's number. This is the
 * file system of Unix since 1971, and of xv6.
 *
 * {b What is different: nothing is ever written over.} A classic file
 * system changes a block where it is. If the machine stops in the middle
 * of a change that touches several blocks (a new file is an inode, a
 * directory entry and a block of data), the disk is left inconsistent.
 * Unix then needed fsck at the next boot, and later file systems added a
 * log (xv6 has one). Here, a block that the last commit uses is never
 * changed. A change writes a copy of the block, which changes the
 * pointer to it, so the block holding that pointer is copied too, and so
 * on up to the root:
 *
 *      before the write             after it, before the commit
 *
 *      superblock                   superblock (in memory)
 *          |                             |
 *       root inode                   root inode'
 *          |                             |
 *      inode block                  inode block'    (the file's inode,
 *          |                             |           its new size)
 *      data block                   data block'     (the new bytes)
 *
 *      the disk still has the whole tree on the left; the commit writes
 *      the superblock, one block, and the disk has the tree on the right
 *
 * For this to work, inodes cannot sit at a fixed place on the disk, as
 * in Unix: they live in a file, the inode file, and the root of
 * everything is the inode of that file, in the superblock. Changing an
 * inode is then just a write to that file. The commit is the write of
 * block 0. Whenever the machine stops, the disk holds either the old
 * tree or the new one, never half of each, and the boot needs no fsck.
 *
 * A block written since the last commit (a fresh one) may be written
 * again in place: no commit refers to it. So a file written 1 KB at a
 * time copies its path to the root once per commit, not once per write.
 * The kernel commits after each system call that changed the disk,
 * except write: a file's writes are committed by the next call that is
 * not a write, its close at the latest.
 *
 * {b Free blocks are found by a collector.} Nothing tracks which blocks
 * become free when they are replaced. Instead, when no block is free (and
 * at the mount), the file system marks the blocks that the trees use and
 * takes the others back: a mark-and-sweep collector for the disk, as
 * TinyML's runtime is a collector for the heap. The trees are the live
 * one, the snapshots, and the last commit's tree on the disk. This
 * replaces Unix's map of free blocks, which a crash could also leave
 * wrong.
 *
 * {b Snapshots come for free.} Since an old tree is never written over,
 * keeping it costs only its root. At each boot, the tree that the last
 * boot left is kept as a snapshot (14 at most, the oldest dropped). The
 * kernel shows them as /dump/N, the files as they were at the end of
 * boot N, read only. A file deleted by mistake can be copied back from
 * there.
 *
 * cs-history:
 * The inode, the direct and indirect blocks, and directories as files of
 * (name, number) are from the first Unix file system (Thompson and
 * Ritchie, 1971-1974), and xv6 keeps them. Writing nothing in place is
 * the idea of shadow paging (Lorie, System R, 1977). NetApp's WAFL (Hitz,
 * Lau and Malcolm, 1994) built a file system on it, with the inode file
 * and snapshots as here; ZFS (2005) and btrfs (2007) followed. Plan 9's
 * dump (Quinlan, 1991; then Venti and Fossil, 2002) kept every day's
 * file system under /n/dump/2026/1018, which is where /dump comes from.
 * The log-structured file system (Rosenblum and Ousterhout, 1991) also
 * writes only new blocks, and also needs a cleaner, its collector.
 *
 * design:
 * A classic file system with a log (xv6's) writes each change twice,
 * once to the log and once in place, and needs code to replay the log at
 * the boot. Copying on write writes each change once, at a new place,
 * and the commit is a single block. What it costs instead is the copies
 * up to the root (a few blocks per commit) and the collector. In ML both
 * are short: the copy is one recursive function ([fs_store]), the
 * collector another ([fs_mark]).
 *
 * wib:
 * - The collector reads every inode and indirect block of every tree.
 *   That is quick on tiny-machine's disk of 8 MB, where a transfer is
 *   instant, but a real file system keeps reference counts or a space
 *   map instead (ZFS's).
 * - There is no cache: every access reads its blocks again from the
 *   disk, as t6 does. That is fine only because the disk is instant.
 * - Directories are searched in order, and a removal rewrites the
 *   directory. That is fine for directories of a few dozen names.
 * - A file removed while a program still has it open is freed at once
 *   (Unix keeps it until the last close), and its inode may be reused.
 *)

(* the transfer of block b to memory at a (command 1) or from memory to
 * the block (2): the kernel's disk device, or the test's bytes *)
val fs_io : (int -> int -> int -> unit) ref

(* raised by a write when no block is free, even after a collection *)
exception Disk_full

(* [fs_mount n]: the file system of a disk of n blocks, made when the
 * disk is blank; the last boot's tree becomes a snapshot *)
val fs_mount : int -> unit

(* the changes since the last commit, written to the disk as a whole
 * (nothing to do when there are none) *)
val fs_commit : unit -> unit

(* the snapshots: each one's tree number and the boot it was left by *)
val fs_snapshots : unit -> (int * int) list

(* the free blocks, counted after a collection *)
val fs_free : unit -> int

(* A file is an inode's number in a tree: tree 0 is the live one, which
 * can be changed, trees 1 to 14 the snapshots. Inode 1 is the root
 * directory. The types are 1 for a directory and 2 for a file, as in
 * the entries the kernel gives to ls. *)

(* [fs_kind r n]: inode n's type, size and links *)
val fs_kind : int -> int -> int * int * int
val fs_is_dir : int -> int -> bool

(* [fs_lookup r d name]: the inode under name in directory d (0: none) *)
val fs_lookup : int -> int -> string -> int

(* the names and inodes of a directory, in the order they were made *)
val fs_entries : int -> int -> (string * int) list

(* [fs_read_at r n off a len]: up to len bytes of the file from off, to
 * memory at a; how many there were *)
val fs_read_at : int -> int -> int -> int -> int -> int

(* the whole file, as a string *)
val fs_contents : int -> int -> string

(* [fs_write_at n off a len]: len bytes from memory at a, to the live
 * file n at off (Disk_full when there is no room) *)
val fs_write_at : int -> int -> int -> int -> unit

(* the file emptied *)
val fs_truncate : int -> unit

(* [fs_create d name typ]: a new file (2) or directory (1) under name in
 * d; its inode *)
val fs_create : int -> string -> int -> int

(* [fs_link d name n]: a second name for file n, in d *)
val fs_link : int -> string -> int -> unit

(* [fs_unlink d name]: the name removed from d, and the inode with its
 * last name *)
val fs_unlink : int -> string -> unit
