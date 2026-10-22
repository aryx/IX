#!args NPROC=2 all
# $nproc: the slot running a job
# (a sleeps 1 s: b ends first even on a loaded machine, test-lite)
all:V: a b
	echo all
a:V:
	sleep 1; echo a slot=$nproc
b:V:
	echo b slot=$nproc
