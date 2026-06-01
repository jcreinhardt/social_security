capture program drop bymyxtile
program bymyxtile, byable(recall)
	//	syntax [varlist] [if] 
	marksample touse 
	tempvar temp_rank
	capture noisily xtile `temp_rank'=`1' if `touse', nq($numq)
	capture noisily replace `2'=`temp_rank' if `touse'
end 
