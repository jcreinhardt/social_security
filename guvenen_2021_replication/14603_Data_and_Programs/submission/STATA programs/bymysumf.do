capture program drop bymysumf
program bymysumf
	//	syntax [varlist] [if] 

	local varM="`1'"
	local prefix="`2'"
	local suffix="`3'"
	global statlist1 ="`prefix'N`varM'`suffix'=r(N) `prefix'mean`varM'`suffix'=r(mean) `prefix'p50`varM'`suffix'=r(p50)"
	global statlist2 ="`prefix'sd`varM'`suffix'=r(sd) `prefix'p1`varM'`suffix'=r(p1) `prefix'p99`varM'`suffix'=r(p99)"
	qui statsby $statlist1 $statlist2, by(`4') saving(`prefix'`varM'`suffix',replace) total:  summarize `varM', detail

end
