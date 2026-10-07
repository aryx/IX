function f(a, b) { return a + b }
BEGIN { print f(1), f(1, 2, 3); print log(-1), sqrt(-1), exp(1000), 0^-1; print length(1, 2), atan2(1); printf "%z %d\n", 1, 2 }
