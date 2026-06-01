use "$maindirectory${sep}dta${sep}$datafile_10p"
keep wage* ein* yob yod male selfinc*

forvalues yr=1978/1993{
	forvalues var=1/3{ 
		capture noisily	drop wage`var'_`yr' ein`var'_`yr'
	}
	capture noisily drop selfinc`yr'
}

destring, replace force

display "***********************************"
display "Male Sample"
display "***********************************"
drop if male~=1
	
drop male	
drop if yob==.
drop if $yrfirst-yob+1>$retire_age | $yrlast-yob+1<$begin_age 
drop if yod<=$yrfirst & yod~=.
count

forvalues yr = $yrfirst/$yrlast{
	replace wage1_`yr' = 0 if wage1_`yr'==.
	replace wage2_`yr' = 0 if wage2_`yr'==.
	replace wage3_`yr' = 0 if wage3_`yr'==.
	replace selfinc`yr' = 0 if selfinc`yr'==.
}
forvalues yr = $yrfirst/$yrlast{
	foreach var in wage1_ wage2_ wage3_ selfinc{ 
		gen temp`var'=`var'`yr' if `yr'-yob+1>= $begin_age & `yr'- yob+1<= $retire_age & `yr'< yod  // yod=. id very big number  
		egen temp=pctile(temp`var'), p(99.999)
		replace `var'`yr'= temp if `var'`yr'>=temp
		drop temp temp`var'
		
		local cpi_index = `yr'-1959+1
		local deflate = cpimat[1,$base_price]/cpimat[1,`cpi_index']
		replace `var'`yr' = `var'`yr'*`deflate'
		
		gen temp=uniform()-0.5
		replace `var'`yr'=`var'`yr'+`var'`yr'*temp/5000 
		drop temp
		
		replace `var'`yr'= . if `yr'-yob+1 < $begin_age | `yr'- yob+1>$retire_age 
		replace `var'`yr'= . if `yr'>= yod & yod~=.  // (yod=. is very big number)
	}
	gen labor`yr' = wage1_`yr'+wage2_`yr'+wage3_`yr' + 2*selfinc`yr'/3
}
compress
save "$maindirectory${sep}dta${sep}cleaned_male_LABOR_SELFINC_3EIN", replace
