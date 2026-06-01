capture program drop bymysum_meanonly
program bymysum_meanonly 
	local varM="`1'"
	local prefix="`2'"
	local suffix="`3'"
	
	global statlist1 ="N`varM'=r(N) mean`varM'=r(mean) "
	qui statsby $statlist1, by(`4') saving(S_`prefix'`varM'`suffix',replace): ///
	summarize `varM', meanonly
				
end
