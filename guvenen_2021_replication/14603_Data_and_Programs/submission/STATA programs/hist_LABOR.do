drop _all
use "$maindirectory${sep}dta${sep}cleaned_male_10p_LABOR19942013"

local yrdrop=$yrbpr-1
forvalues yr = $yrfirst/`yrdrop'{
	foreach var in labor{
		drop `var'`yr'
	}
}

local yrdrop1=$yr1L+1
local yrdrop2=$yr5L-1
forvalues yr = `yrdrop1'/`yrdrop2'{
	foreach var in labor{
		drop `var'`yr'
	}
}
local yrdrop=$yr5L+1
forvalues yr = `yrdrop'/$yrlast{
	foreach var in labor{
		drop `var'`yr'
	}
}

drop if yob > ${yrepr} - ${begin_age}  + 1 
drop if yob < ${yr5L}  - ${retire_age} + 1
drop if yod <= ${yr5L} & yod~=.
drop yod

// Generating age groups
gen age$yrepr = $yrepr-yob+1
gen agebin=.
replace agebin=1 if age${yrepr}<=34
replace agebin=2 if age${yrepr}>=45 & age${yrepr}<=50


gen  avg${varoi}${yrepr}=0
gen  numobs${varoi}${yrepr}=0
gen  numallobs${varoi}${yrepr}=0
replace numobs${varoi}${yrepr}=-5 if ${varoi}${yrepr} < rmininc[1,${yrepr}-1959+1] | ${varoi}${yrepr}==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}${yrepr}=avg${varoi}${yrepr} +max(${varoi}`t', rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobs${varoi}${yrepr}=numobs${varoi}${yrepr} +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=.
	replace numallobs${varoi}${yrepr}=numallobs${varoi}${yrepr} +1 if ${varoi}`t'~=.
}
replace avg${varoi}${yrepr} = avg${varoi}${yrepr}/numallobs${varoi}${yrepr} if numobs${varoi}${yrepr} >=${minobspr}
replace avg${varoi}${yrepr} = . if numobs${varoi}${yrepr} < ${minobspr}
drop numobs${varoi}${yrepr} numallobs${varoi}$yrepr

drop if avg${varoi}${yrepr}==.		//there are a bunch of them with missings

global numq=100						// Number of quintiles
gen temprank=.
gen incrank=.
// Generate income percentiles based on past (5 years of) earnings
qui bys age${yrepr}: bymyxtile avg${varoi}${yrepr} temprank

replace incrank=10 if temprank==10
replace incrank=50 if temprank==50
replace incrank=90 if temprank==90



// log income change between t and t+1
gen res${varoi}chF1 = log(${varoi}${yr1L}) - log(${varoi}${yrbr}) ///
	if ${varoi}${yr1L}>=rmininc[1,${yr1L}-1959+1]/3 & ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
la var res${varoi}chF1 "Change in residual earnings btw t and t+1"

bys age${yrepr}: egen avgF1 = mean(res${varoi}chF1)
replace res${varoi}chF1 = res${varoi}chF1 - avgF1

// Arc percentage income change between t and t+1
bys age${yrepr}: egen avgABR = mean(${varoi}${yrbr})
bys age${yrepr}: egen avgA1L = mean(${varoi}${yr1L})

gen resA${varoi}chF1 = 2*(${varoi}${yr1L}/avgA1L - ${varoi}${yrbr}/avgABR)/ ///
	(${varoi}${yr1L}/avgA1L + ${varoi}${yrbr}/avgABR) ///
	if ${varoi}${yr1L}>=rmininc[1,${yr1L}-1959+1] | ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
la var resA${varoi}chF1 "Arc % change in residual earnings btw t and t+1"


// log income change between t and t+5
gen res${varoi}chF5 = log(${varoi}${yr5L}) - log(${varoi}${yrbr}) ///
	if ${varoi}${yr5L}>=rmininc[1,${yr5L}-1959+1]/3 & ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
la var res${varoi}chF5 "Change in residual earnings btw t and t+5"

bys age${yrepr}: egen avgF5 = mean(res${varoi}chF5)
replace res${varoi}chF5 = res${varoi}chF5 - avgF5

// Arc percentage income change between t and t+5
bys age${yrepr}: egen avgA5L = mean(${varoi}${yr5L})

gen resA${varoi}chF5 = 2*(${varoi}${yr5L}/avgA5L - ${varoi}${yrbr}/avgABR)/ ///
	(${varoi}${yr5L}/avgA5L + ${varoi}${yrbr}/avgABR) ///
	if ${varoi}${yr5L}>=rmininc[1,${yr5L}-1959+1] | ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
la var resA${varoi}chF5 "Arc % change in residual earnings btw t and t+1"


gen dropind=1
foreach var in res resA{
	foreach lag in 1 5{
		kdensity `var'${varoi}chF`lag', gen(F`var'`lag'all_x F`var'`lag'all_d) n(500) nograph
		replace dropind=0 if F`var'`lag'all_x ~=.		
	}
}
outsheet F* if dropind==0 using hist_labor_all${yrbr}.txt, replace
drop F*
drop if incrank==.
drop if agebin==.

replace dropind=1

foreach ab in 1 2{
	foreach pct in 10 50 90{
		foreach var in res resA{ 
			foreach lag in 1 5{
				kdensity `var'${varoi}chF`lag' if agebin==`ab' & incrank==`pct', ///
				gen(F`var'`lag'age`ab'rank`pct'x F`var'`lag'age`ab'rank`pct'd) n(500) nograph
				replace dropind=0 if F`var'`lag'age`ab'rank`pct'x~=.
			}
		}
	}
}


outsheet F* if dropind==0 using hist_labor_incrankage${yrbr}.txt, replace
