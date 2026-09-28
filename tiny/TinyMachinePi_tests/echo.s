@ The PL011's input, by its interrupt (TinyMachinePi_test.sh runs it
@ under TinyMachinePi, mini-qemu and QEMU's raspi1ap, echo.input on the
@ UART, the output the same): each character received is echoed, a
@ letter in upper case, a \r (Enter, from a terminal) as a newline;
@ ^D ends it. Loaded at 0x8000, entered in SVC mode, IRQ and FIQ
@ masked. The kernel waits (WFI) between interrupts.
	.text
	.global _start
_start:
	@ a stack for IRQ mode, then SVC's (the mode we are in)
	msr cpsr_c, #0xd2
	ldr sp, =0x7000
	msr cpsr_c, #0xd3
	ldr sp, =0x8000
	@ the vectors at 0: eight "ldr pc, [pc, #24]" and their eight addresses
	ldr r0, =vectors
	mov r1, #0
	ldmia r0!, {r2, r3, r4, r5, r6, r7, r8, r9}
	stmia r1!, {r2, r3, r4, r5, r6, r7, r8, r9}
	ldmia r0!, {r2, r3, r4, r5, r6, r7, r8, r9}
	stmia r1!, {r2, r3, r4, r5, r6, r7, r8, r9}
	ldr r0, =hello
	bl puts
	@ the UART's receive interrupt (IMSC: RXIM and RTIM), then its
	@ line, 57, at the controller (enable 2, bit 25)
	ldr r0, =0x20201000
	mov r1, #0x50
	str r1, [r0, #0x38]
	ldr r0, =0x2000b214
	mov r1, #0x2000000
	str r1, [r0]
	cpsie i
	@ done checked before each wait: its interrupt may have come already
wait:
	ldr r0, =done
	ldr r0, [r0]
	cmp r0, #0
	bne finish
	wfi
	b wait
finish:
	cpsid i
	ldr r0, =bye
	bl puts
halt:
	wfi			@ IRQs masked: never wakes
	b halt

@ the UART's interrupt: every character waiting, until FR says the
@ receive FIFO empty (which lowers the line)
irq_handler:
	push {r0, r1, r2, r3, lr}
	ldr r2, =0x20201000
more:
	ldr r3, [r2, #0x18]
	tst r3, #0x10		@ FR: RXFE
	bne out
	ldr r1, [r2]		@ DR: the character in
	and r1, r1, #0xff
	cmp r1, #4		@ ^D
	beq end
	cmp r1, #13		@ \r: a newline
	moveq r1, #10
	sub r3, r1, #97		@ a letter: 'a' to 'z' in upper case
	cmp r3, #26
	sublo r1, r1, #32
	bl putc
	b more
end:
	ldr r0, =done
	mov r1, #1
	str r1, [r0]
	b more
out:
	pop {r0, r1, r2, r3, lr}
	subs pc, lr, #4

@ putc: the character in r1 to the PL011 at r2 (r3 used)
putc:
	ldr r3, [r2, #0x18]
	tst r3, #0x20
	bne putc
	str r1, [r2]
	bx lr

@ puts: the string at r0 to the PL011 (r0-r3 used)
puts:
	ldr r2, =0x20201000
puts_next:
	ldrb r1, [r0], #1
	cmp r1, #0
	bxeq lr
puts_wait:
	ldr r3, [r2, #0x18]
	tst r3, #0x20
	bne puts_wait
	str r1, [r2]
	b puts_next

vectors:
	ldr pc, [pc, #24]	@ 0x00 reset
	ldr pc, [pc, #24]	@ 0x04 undefined
	ldr pc, [pc, #24]	@ 0x08 svc
	ldr pc, [pc, #24]	@ 0x0c prefetch abort
	ldr pc, [pc, #24]	@ 0x10 data abort
	ldr pc, [pc, #24]	@ 0x14 (unused)
	ldr pc, [pc, #24]	@ 0x18 IRQ
	ldr pc, [pc, #24]	@ 0x1c FIQ
	.word _start, _start, _start, _start, _start, _start, irq_handler, _start

done:
	.word 0
hello:
	.asciz "echo: type, ^D to end\n"
bye:
	.asciz "echo: done, halting\n"
