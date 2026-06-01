drop _all
use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR19942013"

** Drop income observations for years that we won't need
local yrdrop=$yrbpr-1
forvalues yr = $yrfirst/`yrdrop'{
	foreach var in labor{
		drop `var'`yr'
	}
}
local yr = $yr5L-1
foreach var in labor{
	drop `var'`yr'
}
local yrdrop1=$yr5L+1
local yrdrop2=$yr10L-1
forvalues yr = `yrdrop1'/`yrdrop2'{
	foreach var in labor{
		drop `var'`yr'
	}
}
local yrdrop=$yr10L+1
forvalues yr = `yrdrop'/$yrlast{
	foreach var in labor{
		drop `var'`yr'
	}
}
drop if yob > ${yrepr} - ${begin_age}  + 1 
drop if yob < ${yr10L} - ${retire_age} + 1
drop if yod <= ${yr10L} & yod~=.
drop yod

** Generating age groups
gen age${yrepr} = ${yrepr}-yob+1
gen agebin=.
replace agebin=1 if age${yrepr} <=34
replace agebin=2 if age${yrepr} >=35

matrix avgagedum${varoi}=J(1,${retire_age}-${begin_age}+1,0)
local dura = ${yrepr}-${yrbpr}+1
local hmax = ${retire_age}-${begin_age}+1
forvalues i=1/`hmax'{
	local dura1=min(`i',`dura')-1
	forvalues j=0/`dura1'{
		matrix avgagedum${varoi}[1,`i']	= avgagedum${varoi}[1,`i'] + agedum${varoi}[1,`i'-`j']
	}
	matrix avgagedum${varoi}[1,`i']	= ln(avgagedum${varoi}[1,`i']/(`dura1'+1))
}

gen  avg${varoi}${yrepr}=0
gen  numobs${varoi}${yrepr}=0
gen  numallobs${varoi}${yrepr}=0
replace numobs${varoi}${yrepr}=-5 if ${varoi}${yrepr} < rmininc[1,${yrepr}-1959+1] | ${varoi}${yrepr}==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}${yrepr}=avg${varoi}${yrepr} + max(${varoi}`t', rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobs${varoi}${yrepr}=numobs${varoi}${yrepr} +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=.
	replace numallobs${varoi}${yrepr}=numallobs${varoi}${yrepr} +1 if ${varoi}`t'~=.
}
replace avg${varoi}${yrepr} = avg${varoi}${yrepr}/numallobs${varoi}${yrepr} 	///
	if numobs${varoi}${yrepr} >=${minobspr}
replace avg${varoi}${yrepr} = . if numobs${varoi}${yrepr} < ${minobspr}
replace avg${varoi}${yrepr} = ln(avg${varoi}${yrepr}) - avgagedum${varoi}[1,age${yrepr}-${begin_age}+1] ///
	if numobs${varoi}${yrepr} >=${minobspr}
rename avg${varoi}${yrepr} avgres${varoi}${yrepr}
drop numobs${varoi}${yrepr} numallobs${varoi}${yrepr}

** Everyone should have positive earnings in year t-1
drop if ${varoi}${yrepr}==. | ${varoi}${yrepr}==0
drop if avgres${varoi}${yrepr}==.

** Generate income percentiles based on past (5 years of) earnings
global numq  = 100
gen temprank=.
gen avgres${varoi}rank=.
qui bys agebin: bymyxtile avgres${varoi}${yrepr} temprank
replace avgres${varoi}rank=1 if temprank<=5
replace avgres${varoi}rank=2 if temprank>5 & temprank<=10
replace avgres${varoi}rank=3 if temprank>10 & temprank<=30
replace avgres${varoi}rank=4 if temprank>30 & temprank<=50
replace avgres${varoi}rank=5 if temprank>50 & temprank<=70
replace avgres${varoi}rank=6 if temprank>70 & temprank<=90
replace avgres${varoi}rank=7 if temprank>90 & temprank<=95
replace avgres${varoi}rank=8 if temprank>95
drop temprank

** Arc percentage change in (residual) earnings between t-1 and t
** Age effect (mean and median)
bys age${yrepr}: egen avgt = mean(${varoi}${yrbr})
bys age${yrepr}: egen medt = median(${varoi}${yrbr})
bys age${yrepr}: egen avgl = mean(${varoi}${yrepr})
bys age${yrepr}: egen medl = median(${varoi}${yrepr})
gen resA${varoi}chL1_mean = 2*(${varoi}${yrbr}/avgt-${varoi}${yrepr}/avgl)/ 	///
	(${varoi}${yrbr}/avgt+${varoi}${yrepr}/avgl)
gen resA${varoi}chL1_med  = 2*(${varoi}${yrbr}/medt-${varoi}${yrepr}/medl)/ 	///
	(${varoi}${yrbr}/medt+${varoi}${yrepr}/medl)
la var  resA${varoi}chL1_mean "Arc percent change in residual earnings btw t-1 and t (mean)"
la var  resA${varoi}chL1_med  "Arc percent change in residual earnings btw t-1 and t (median)"

** Log and arc percent change in (residual) earnings between t-1 and t+1, t and t+2, t and t+3, t and t+5 and t and t+10
foreach lag in 1 2 3 5 10{
	bys age${yrepr}: egen avgF = mean(${varoi}${yr`lag'L})
	bys age${yrepr}: egen medF = median(${varoi}${yr`lag'L})
	gen resA${varoi}chF`lag'_mean = 2*(${varoi}${yr`lag'L}/avgF-${varoi}${yrepr}/avgl)/	///
		(${varoi}${yr`lag'L}/avgF+${varoi}${yrepr}/avgl)
	gen resA${varoi}chF`lag'_med  = 2*(${varoi}${yr`lag'L}/medF-${varoi}${yrepr}/medl)/	///
		(${varoi}${yr`lag'L}/medF+${varoi}${yrepr}/medl)
	la var  resA${varoi}chF`lag'_mean "Arc percent change in residual earnings btw t and t+`lag' (mean)"
	la var  resA${varoi}chF`lag'_med  "Arc percent change in residual earnings btw t and t+`lag' (median)"
	drop avgF medF
}
gen year=${yrbr}
keep year agebin avgres${varoi}rank resA${varoi}*
order year agebin
save tempdata${yrbr}, replace
