BEGIN {
	print 1 " " 2, 1 2, "a" "b" "c", 1+2 "x", "x" 1+2, -1 " " -2
	print 2 * 3 4, 2 3 * 4, 1 + 2 3 + 4, "a" (1 < 2) "b"
	print -1 " " -1; print "a" -1; x = 3; print x -1, x - 1, x" "-1
	a = "x"; a = a a a; print a; b[1] = b[1] "y"; print b[1]; $0 = "p q"; $2 = $2 $1; print
	print length("x") length("yy")
}
