capture program drop bymysum
program bymysum
	//	syntax [varlist] [if]
	preserve
	local varM="`1'"
	local prefix="`2'"
	local suffix="`3'"

	global statlist1 ="`prefix'N`varM'`suffix'=r(N) `prefix'mean`varM'`suffix'=r(mean) `prefix'sd`varM'`suffix'=r(sd)"
	global statlist2 ="`prefix'skew`varM'`suffix'=r(skewness) `prefix'kurt`varM'`suffix'=r(kurtosis)"
	global statlist3 ="`prefix'min`varM'`suffix'=r(min) `prefix'max`varM'`suffix'=r(max)"
	qui statsby ${statlist1} ${statlist2} ${statlist3}, by(`4') ///
		saving(`prefix'`varM'`suffix',replace) total:  summarize `varM', det

	u `prefix'`varM'`suffix', clear
	erase `prefix'`varM'`suffix'.dta
	save `prefix'`varM'`suffix', replace
	*outsheet using `prefix'`varM'`suffix'.txt, replace
end
