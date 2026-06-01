capture program drop bymydiststat
program bymydiststat
	//	syntax [varlist] [if] 
	preserve
	local varM="`1'"
	local prefix="`2'"
	local suffix="`3'"
	global statlist1 ="`prefix'N`varM'`suffix'=r(N) `prefix'mean`varM'`suffix'=r(mean) `prefix'sd`varM'`suffix'=r(sd)"
	global statlist2 ="`prefix'skew`varM'`suffix'=r(skewness) `prefix'kurt`varM'`suffix'=r(kurtosis) `prefix'min`varM'`suffix'=r(min)"
	global statlist3 ="`prefix'max`varM'`suffix'=r(max) `prefix'p1`varM'`suffix'=r(p1) `prefix'p5`varM'`suffix'=r(p5) `prefix'p10`varM'`suffix'=r(p10)"
	global statlist4 ="`prefix'p25`varM'`suffix'=r(p25) `prefix'p50`varM'`suffix'=r(p50) `prefix'p75`varM'`suffix'=r(p75) "
	global statlist5 ="`prefix'p90`varM'`suffix'=r(p90) `prefix'p95`varM'`suffix'=r(p95) `prefix'p99`varM'`suffix'=r(p99)"
	qui statsby $statlist1 $statlist2 $statlist3 $statlist4 $statlist5 , by(`4') saving(`prefix'`varM'`suffix',replace) total:  summarize `varM',detail 

	u `prefix'`varM'`suffix', clear
	erase `prefix'`varM'`suffix'.dta
	outsheet using `prefix'`varM'`suffix'.txt, replace	
end
