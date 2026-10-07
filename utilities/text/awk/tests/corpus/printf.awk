BEGIN {
	printf "%d %5d %-5d| %05d %+d %s %10s| %-10s| %.2s %c %c %e %f %g %.3f %5.1f%%\n", 42, 42, 42, 42, 42, "str", "right", "left", "truncate", 65, "hello", 1234.5678, 1234.5678, 1234.5678, 3.14159, 2.55
	printf "%d %d %d %i\n", "12abc", 3.99, -3.99, 7
	printf "%s %s\n", 1e6, 0.1
	printf "%*d|%-*d|\n", 5, 42, 5, 42
	printf "%.*f\n", 2, 3.14159
	printf "no newline"; printf "\n%s\n" , "x" "y"
	printf "%d %d %d\n", 2^31, 2^40, -2^40
	printf "%5.2d|%-6d|%06d|% d|%E|%G|%10.3e|%05.1f|%5c|%.0f|%.10g\n", 3, 42, 42, 5, 1234.5, 0.00001234, 1234.5, 2.5, "x", 2.5, 1/3
	print sprintf("%3d|%-3d|%s", 1, 2, "z"), sprintf("%c%c%c", 228, "é", 9786), sprintf("%5s|%-5s|%.1s", "é", "é", "éa")
	printf("%s %s %s\n", "paren", 1, 2)
	printf "%s\n"
}
