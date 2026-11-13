(* Tiny file system is the part of the kernel that keeps files on a
 * disk, as KGraphics is the part that draws. The first disk is the
 * root, in a union with the boot image's files (see "The files" in
 * TinyKernel.mli).
 *
 * It needs two things from the machine: KRaw's bytes, and a way to
 * move a block between the disk and memory (the io function given to
 * [fs_mount]).
 *
 * {b The classic layout.} The disk is made of blocks of 1 KB. A file is
 * an inode: its type, its size, its number of links, the date of its
 * last write, and the numbers of its blocks. The first 10 blocks are
 * listed in the inode itself; after them comes an indirect block (256
 * more numbers), then a double indirect one (256 blocks of 256
 * numbers). A directory is a file whose contents are entries, each a
 * name of up to 64 bytes and an inode's number. This is the file system
 * of Unix since 1971, and of xv6.
 *
 * twin:
 * The twin is mini-9pi's disk device, '#x' (Kfs in kernels/9pi/), which
 * is built on Xv6fs in lib_xv6fs. That is xv6's file system (xv6's
 * fs.c, also in ix's mini-xv6 as kernels/xv6's Fs) running in the
 * kernel, with a bitmap of free blocks and, as here, no log and no
 * cache. We kept from it the inode with its direct then indirect
 * blocks, the directory as a file of (name, number) pairs, and names
 * longer than xv6's 14 bytes (an ix extension there).
 * Plan 9 itself has no disk file system in its kernel (principia's
 * kernel/filesystems/ has devfs.c, with dossrv and ramfs as programs):
 * a disk is served by a user program, as Kdos explains. Here, as in
 * mini-9pi's Kfs and in Unix, the kernel calls the file system as
 * functions.
 *
 * dropped:
 * xv6's buffer cache and its locks on inodes and buffers are dropped,
 * because a call runs to its end on core 0, and every transfer is
 * instant, so no process ever waits in the middle of the file system. A
 * slow disk would need both back. A directory has no entries for . and
 * .. (the kernel resolves .. by the path's text), and a file is a
 * directory or data, with no kind for a device such as xv6's mknod
 * makes.
 *
 * twist:
 * Unlike the twin:
 * - nothing is written in place, so a commit is one block, where
 *   xv6's log.c writes each change twice;
 * - free blocks are found by a collector, instead of a bitmap that
 *   must be kept right;
 * - there are snapshots, which xv6 has no way to keep.
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
 * boot left is kept as a snapshot (there are 14 at most, and the oldest
 * is dropped). The
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
 *   That is quick on tiny-machine's small disks, where a transfer is
 *   instant, but a real file system keeps reference counts or a space
 *   map instead (ZFS's).
 * - There is no cache: every access reads its blocks again from the
 *   disk, as t6 does. That is fine only because the disk is instant.
 * - Directories are searched in order, and a removal rewrites the
 *   directory. That is fine for directories of a few dozen names.
 * - A file removed while a program still has it open is freed at once
 *   (Unix keeps it until the last close), and its inode may be reused.
 *)

(* A file is named by a tree number and an inode number in that tree
 * (see below). *)
type tree = int
type inode = int

(* The kinds are 1 and 2 on the disk, as in the directory entries ls
 * gets. *)
type file_kind = Fs_dir | Fs_file

(* A transfer goes between block b and memory at a. In the kernel it is
 * the disk device's command 1 or 2; in the tests it is a copy of
 * bytes. *)
type disk_io = Disk_read | Disk_write

(* An fs is a mounted disk, like Linux's super_block. *)
type fs

(* [fs_disk] is 0 for the first disk mounted, and 1 for the second. *)
val fs_disk : fs -> int

(* Raised by a write when no block is free, even after a collection. *)
exception Disk_full

(* [fs_mount io k n] mounts disk k, of n blocks, transferring with io. A
 * blank disk is formatted, and the last boot's tree becomes a snapshot.
 * A disk grown past its file system (disk.img by truncate -s) is used
 * whole. *)
val fs_mount : (int -> int -> disk_io -> unit) -> int -> int -> fs

(* [fs_commit] writes the changes since the last commit as a whole, if
 * any. [fs_sync] commits every disk, like Unix's sync. *)
val fs_commit : fs -> unit
val fs_sync : unit -> unit

(* [fs_snapshots] gives each snapshot's tree number and the boot that
 * left it. *)
val fs_snapshots : fs -> (tree * int) list

(* [fs_free] is the number of free blocks, as counted by the last
 * collection. *)
val fs_free : fs -> int

(* A file is an inode's number in a tree: tree 0 is the live one, which
 * can be changed, and trees 1 to 14 are the snapshots. Inode 1 is the root
 * directory. *)

(* [fs_kind] gives the type, size and number of links. [fs_date] is the
 * last write, in seconds since 2000, taken from [fs_clock], which the
 * kernel sets. *)
val fs_kind : fs -> tree -> inode -> file_kind * int * int
val fs_date : fs -> tree -> inode -> int
val fs_clock : (unit -> int) ref
val fs_is_dir : fs -> tree -> inode -> bool

val fs_lookup : fs -> tree -> inode -> string -> inode option

(* [fs_entries] lists a directory in the order its names were made. *)
val fs_entries : fs -> tree -> inode -> (string * inode) list

(* [fs_read_at r n off a len] reads up to len bytes from offset off to
 * memory at a, and returns the count. [fs_read_string] reads into a
 * string, one block at most. *)
val fs_read_at : fs -> tree -> inode -> int -> int -> int -> int
val fs_read_string : fs -> tree -> inode -> int -> int -> string
val fs_contents : fs -> tree -> inode -> string

(* [fs_write_at n off a len] writes len bytes from memory at a to the
 * live file n at offset off, or raises Disk_full. *)
val fs_write_at : fs -> inode -> int -> int -> int -> unit
val fs_truncate : fs -> inode -> unit
val fs_create : fs -> inode -> string -> file_kind -> inode

(* [fs_link d name n] gives n another name in d. [fs_unlink] frees the
 * inode with its last name. *)
val fs_link : fs -> inode -> string -> inode -> unit
val fs_unlink : fs -> inode -> string -> unit
