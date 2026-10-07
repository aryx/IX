BEGIN {
	if (0) print "a"; else if ("") print "b"; else if ("0") print "c"; else print "d"
	if (0.0) print "e"; if ("a") print "f"; x = "0"; if (x) print "g"; y = 0; if (y "") print "h"
	if (!nothing) print "not"
	print 1 ? "one" : "other"; print (x > 0) ? "pos" : "neg"; v = x ? x : 5; print v; print 1?2?3:4:5, 0?1:0?2:3
}
{ if ($2) print "t" $1; if ($9) print "never"; if ($1 == 0) print "zero" $2 }
