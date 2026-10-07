# the classic: words counted, the commonest first by a small sort
{ for (i = 1; i <= NF; i++) { w = tolower($i); gsub(/[^a-z]/, "", w); if (w != "") count[w]++ } }
END {
	n = 0
	for (w in count) { n++; word[n] = w }
	for (i = 2; i <= n; i++) {
		v = word[i]
		for (j = i - 1; j > 0 && (count[word[j]] < count[v] || (count[word[j]] == count[v] && word[j] > v)); j--) word[j+1] = word[j]
		word[j+1] = v
	}
	for (i = 1; i <= n && i <= 8; i++) printf "%-8s %3d\n", word[i], count[word[i]]
}
