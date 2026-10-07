BEGIN {
	a["é"]=1; a["b"]=2; a["zz"]=3; a["x1"]=4; a[10]=5; a[2]=6
	for (k in a) printf "%s ", k; print ""
	for (i = 0; i < 130; i++) y["k" i] = i
	for (k in y) if (y[k] < 20) printf "%s ", k; print ""
	for (i = 0; i < 300; i++) w[i] = i
	n = 0; for (k in w) { if (n++ < 12) printf "%s ", k; s += w[k] }; print s, length(w)
	for (k in w) delete w[k]; print length(w)
}
