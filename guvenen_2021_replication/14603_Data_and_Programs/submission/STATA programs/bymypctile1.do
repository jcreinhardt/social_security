capture program drop bymypctile1
program bymypctile1
	//	syntax [varlist] [if] 

	local varM="`1'"
	global statlist1 ="p1`varM'=r(r1) p2_5`varM'=r(r2) p5`varM'=r(r3) p10`varM'=r(r4) p12_5`varM'=r(r5)"
	global statlist2 ="p25`varM'=r(r6) p37_5`varM'=r(r7) p50`varM'=r(r8) p62_5`varM'=r(r9)"
	global statlist3 ="p75`varM'=r(r10) p87_5`varM'=r(r11) p90`varM'=r(r12) p95`varM'=r(r13)" 
	global statlist4 ="p97_5`varM'=r(r14) p99`varM'=r(r15)" 
	qui statsby $statlist1 $statlist2 $statlist3 $statlist4, by(`2') saving(PC_`varM',replace) total: ///
	_pctile `varM',p(1,2.5,5,10,12.5,25,37.5,50,62.5,75,87.5,90,95,97.5,99) 

end
