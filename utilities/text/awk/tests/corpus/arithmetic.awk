BEGIN {
	x = 5; x += 2; x -= 1; x *= 3; x /= 2; x %= 5; x ^= 2; print x
	print x++, ++x, x--, --x
	print -x, !x, !0, 2**3, 2^3^2, 7%3, -7%3, 7.5%2, 1+2*3, (1+2)*3, 2^-1, 2^0.5, (-8)^3
	print 1 - -1, 1 - - 1, 2 - 1, 1 -1, - -3
	a = "A"; b = a++; print a, b; c = "3x"; c++; print c; d = -"3"; print d; e = +"4a"; print e
	print int(3.9), int(-3.9), int("4x"), sqrt(16), exp(0), log(1), sin(0), cos(0), atan2(0, 1), atan2(1, 1)*4, exp(1), log(10)
	print 010, 011, 1e2, 1.5e1, .5, 5., 100 ""
}
