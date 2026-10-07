{ a[$3] = a[$3] " " $1; n[$3]++; byline[NR] = $1 }
END {
	for (k in a) print k ":" a[k]
	for (i = NR; i > 0; i--) print byline[i]
	print length(a), length(byline)
	if ("paris" in n) print "yes"
	if (!("tokyo" in n)) print "no"
	delete n["paris"]
	for (k in n) print k, n[k]
	delete n
	print length(n)
	m[1,2] = 3; m["x","y"] = 4
	for (k in m) { split(k, p, SUBSEP); print p[1], p[2], m[k] }
	if ((1,2) in m) print "in"
	print (1 in z), length(z); z["x"]; print length(z), ("x" in z)
}
