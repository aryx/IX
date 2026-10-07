BEGIN {
	i = 0; while (i < 3) { print i; i++ }
	do { print i; i-- } while (i > 1)
	for (;;) { if (++j > 3) break; if (j == 2) continue; print "j" j }
	for (i = 0; i < 10; i++) { if (i % 2) continue; if (i > 6) break; printf "%d ", i }; print ""
	n = split("3 1 2", a); for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (a[j] < a[i]) { t = a[i]; a[i] = a[j]; a[j] = t }
	print a[1] a[2] a[3]
	while (k < 5)
		k++
	print k
	if (k == 5)
		print "five"
	else
		print "not"
	for (k in a) { if (k == 2) continue; s = s k }; print length(s)
	do k--; while (k > 0); print k
	if (1) ; else print "no"
	;
}
