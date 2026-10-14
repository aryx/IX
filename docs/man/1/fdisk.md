\title{fdisk}{1}

# NAME
fdisk – a disk's partitions, as the lines its driver takes

# SYNOPSIS
**fdisk**
**-p**
*disk*

# DESCRIPTION
*Fdisk* reads the partition table in the first sector of *disk* (a
PC's MBR: four entries) and writes a line for each partition:

```
part name start end
```

the sectors by their numbers. Written to the disk's `ctl` file, the
lines make the partitions files beside `data`. The kernel knows
nothing of partition tables: a program reads them and tells it.

A name is the type's: `dos` for a FAT, `plan9`, `linux`,
`linuxswap`, `ntfs`, `efi`, `other`, and some more; with a number
when it is taken already (`dos1`, `plan9.1`). An empty entry, and
one of a type not known, are passed over.

# EXAMPLES
```
fdisk -p /dev/sdM0/data > /dev/sdM0/ctl
ls /dev/sdM0
```

# SEE ALSO
\man{dossrv}{1}, \man{mkcard}{1}

# DIAGNOSTICS
A disk that cannot be opened, and a first sector without the table's
mark (`55 aa`), are said.

# BUGS
Only Plan 9's fdisk's **-p**: not its editor. The partitions inside
an extended one are not read, nor a GPT.
