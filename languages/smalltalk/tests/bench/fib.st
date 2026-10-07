"The benchmark of sends (the playground's tests/bench): fib, by recursion."!

!Integer methodsFor: 'benchmarks'!
benchFib
	^self < 2 ifTrue: [self] ifFalse: [(self - 1) benchFib + (self - 2) benchFib]! !
