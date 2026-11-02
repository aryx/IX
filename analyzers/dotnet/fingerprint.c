// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// mini-analyze's fingerprint on its .NET road (Fingerprint.mli): FNV-1a
// over 64 bits, the arithmetic unsigned, which C says as it is and ML
// cannot (its int is signed, 63 bits natively). Compiled by mini-cc
// -dotnet into fingerprint.dll, whose class fingerprint's methods
// mini-ml -dotnet's Fingerprint calls (its externals): uint64 here,
// int64 there, the same bits, nothing converted between them.

typedef unsigned long long uvlong;

// FNV's offset basis
uvlong
fp_basis(void)
{
	return 0xcbf29ce484222325ULL;
}

// a byte mixed in: xor, then times FNV's prime
uvlong
fp_mix(uvlong h, int b)
{
	return (h ^ (b & 0xff)) * 0x100000001b3ULL;
}

// two fingerprints together, in any order: their sum
uvlong
fp_add(uvlong a, uvlong b)
{
	return a + b;
}
