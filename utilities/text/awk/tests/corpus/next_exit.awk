{ print; if (NR == 1) next; print "after", NR }
NR == 3 { exit }
END { print "end ran", NR }
