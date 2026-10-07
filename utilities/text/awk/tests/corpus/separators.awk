BEGIN { FS = "," }
{ printf "%d:", NF; for (i = 1; i <= NF; i++) printf "[%s]", $i; print "" }
NR == 3 { FS = "[0-9]+" }
NR == 5 { FS = "" }
NR == 6 { FS = "\t" }
NR == 7 { FS = " "; OFS = "+"; ORS = "|\n" }
NR == 8 { $1 = $1; print }
