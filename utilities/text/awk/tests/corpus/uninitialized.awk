BEGIN { a["x"]; print x+0, x "", length(x), (x == 0), (x == ""); if (x) print "t"; else print "f"; x[1]; print length(x) }
