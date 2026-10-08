(* mini-singularity: the kernel's functions a process may call, numbered
 * (decision 3 of plan_system_singularity.md). A call is a number and
 * integers, its words; what an integer points at is copied (cross.c:
 * no value of one heap is seen by the other's collector); what a
 * process holds of the kernel is a handle (Process). The answer is an
 * integer, and for some more of them left in the call's words 1 and 2.
 * -1: refused, or closed; -2: a handle that is not one of the
 * caller's, or not of that kind. A process's lib/Sip says the same
 * numbers.
 *    0 exit status             the process ends
 *    1 debug address bytes     the debug line; the bytes written
 *    2 yield                   the others run
 *    3 create address bytes    a process of the program of that name,
 *                              not started: its handle
 *    4 start process
 *    5 join process            waits for its end: its status
 *    6 channel address bytes   a channel of the contract described
 *                              there (Contract.encode): its importing
 *                              endpoint's handle, the exporting one's
 *                              in word 1
 *    7 give process endpoint   to a child not started: its handle there
 *    8 send endpoint tag value handle   a message to the other end;
 *                              the handle's block or endpoint (-1:
 *                              nothing) goes with it, the caller's
 *                              handle no longer one. A message the
 *                              channel's contract does not allow now
 *                              ends the caller.
 *    9 receive endpoint        waits for a message: its tag (0 and
 *                              up), its value in word 1; what it
 *                              carries: its handle (or -1) in word 2,
 *                              its kind in word 5 (0 nothing, 1 a
 *                              block, 2 an endpoint), a block's
 *                              address and bytes in words 3 and 4
 *   10 select n endpoint...    waits until one of n (3 at most) has a
 *                              message or is closed: which
 *   11 close endpoint
 *   12 alloc bytes             a block of the exchange heap: its
 *                              handle, its address and bytes in words
 *                              1 and 2 (its owner reads and writes it
 *                              there: no call)
 *   13 free block
 *   15 is address bytes endpoint side   0 if the endpoint is of the
 *                              contract of that name, that end (0 the
 *                              importing)
 *   16 io_read registers offset    a register of a device the caller
 *                              was given: its low 30 bits
 *   17 io_write registers offset value
 *   18 wait interrupt          until an interrupt has come
 *   19 info block which        the processes (0) or the programs (1),
 *                              as text in the block: the bytes written
 *   20 stop process            a child ended, with 255
 *   14 time                    microseconds, from the board's timer
 *                              (its low 30 bits) *)

(* the call being served (registered as "abi": cross.c calls it); -1 for
 * a number that is no function *)
val call : unit -> int
