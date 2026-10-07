BEGIN {
	n = split("a b  c", x); print n, x[1], x[2], x[3]
	n = split("a:b:c", x, ":"); print n, x[3]
	n = split("a1b22c", x, /[0-9]+/); print n, x[1], x[2], x[3]
	n = split("abc", x, ""); print n, x[1], x[3]
	n = split("", x); print n, length(x)
	n = split("a,b,", x, ","); print n "[" x[3] "]"
	n = split("a, b, c", x, ", "); print n, x[2]
	n = split("  lead trail  ", x, " "); print n, x[1]
	n = split("12 abc 3.5", x); print x[1]+x[3], (x[1] < 5), (x[2] < 5)
	n = split("a1b2", x, /[0-9]/); print n "[" x[3] "]"
	n = split("héllo", x, ""); print n, x[2]
	n = split("a\nb c", x, ":"); print n, x[1]
	FS = ":"; n = split("p:q", x); print n, x[2]
}
