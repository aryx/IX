/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
// coupling: principia, must be kept in sync
#define NOP     0
#define RFORK       1
#define EXEC        2
#define EXITS       3
#define AWAIT       4
#define BRK     5
#define OPEN        6
#define CLOSE       7
#define DUP         8
#define FD2PATH     9
#define PREAD       10
#define PWRITE      11
#define SEEK        12
#define CREATE      13
#define REMOVE      14
#define CHDIR       15
#define STAT        16
#define FSTAT       17
#define WSTAT       18
#define FWSTAT      19
#define BIND        20
#define MOUNT       21
#define UNMOUNT     22
#define SLEEP       23
#define ALARM       24
#define PIPE        27

#define NOTIFY      25
#define NOTED       26

#define SEGATTACH   28
#define SEGDETACH   29
#define SEGFREE     30
#define SEGFLUSH    31
#define SEGBRK      32
#define RENDEZVOUS  33
#define SEMACQUIRE  34
#define SEMRELEASE  35
#define TSEMACQUIRE 36
#define FVERSION    37
#define FAUTH       38
#define ERRSTR      39
