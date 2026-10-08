(* mini-9pi's boot, its traps and interrupts (principia's main.c,
 * trap.c). The first process does initcode's work in the kernel (as
 * mini-xv6's init does xv6's initcode): #c/cons opened as 0, 1, 2, then
 * the boot program exec'd; stage A's is /boot/echo (plan_9pi.md). *)
