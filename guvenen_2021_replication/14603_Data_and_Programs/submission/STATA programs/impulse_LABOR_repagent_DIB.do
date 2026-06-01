drop _all
use "$maindirectory${sep}dta${sep}MALE_LABORwDIBwTOTINC2013"

** Drop income observations for years that we won't need
drop dib*
local yrdrop=$yrbpr-1
forvalues yr = $yrfirst/`yrdrop'{
	foreach var in labor totinc{
		drop `var'`yr'
	}
}
local yr = $yr5L-1
foreach var in labor totinc{
	drop `var'`yr'
}
local yrdrop1=$yr5L+1
local yrdrop2=$yr10L-1
forvalues yr = `yrdrop1'/`yrdrop2'{
	foreach var in labor totinc{
		drop `var'`yr'
	}
}
local yrdrop=$yr10L+1
forvalues yr = `yrdrop'/$yrlast{
	foreach var in labor totinc{
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

* Calculate recent earnings by using residual earnings (residualized using year-specific dummies)
gen  avg${varoi}${yrepr}=0
gen  numobs${varoi}${yrepr}=0
gen  numallobs${varoi}${yrepr}=0
replace numobs${varoi}${yrepr}=-5 if ${varoi}${yrepr} < rmininc[1,${yrepr}-1959+1] | ${varoi}${yrepr}==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}${yrepr} = avg${varoi}${yrepr} + max(${varoi}`t', rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobs${varoi}${yrepr} = numobs${varoi}${yrepr} + 1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=.
	replace numallobs${varoi}${yrepr} = numallobs${varoi}${yrepr} + 1 if ${varoi}`t'~=.
}
replace avg${varoi}${yrepr} = avg${varoi}${yrepr}/numallobs${varoi}${yrepr} if numobs${varoi}${yrepr}>=${minobspr}
replace avg${varoi}${yrepr} = . if numobs${varoi}${yrepr} < ${minobspr}
bys age${yrepr}: egen agedum = mean(avg${varoi}${yrepr})
replace avg${varoi}${yrepr} = ln(avg${varoi}${yrepr}) - ln(agedum) if numobs${varoi}${yrepr}>=${minobspr}
rename  avg${varoi}${yrepr} avgres${varoi}${yrepr}
drop numobs${varoi}${yrepr} numallobs${varoi}${yrepr}

** Everyone should have positive earnings in year t-1 and t
drop if ${varoi}${yrbr}==.  | ${varoi}${yrbr}==0
drop if ${varoi}${yrepr}==. | ${varoi}${yrepr}==0
drop if avgres${varoi}${yrepr}==. | agebin==.

** Generate income percentiles based on past (5 years of) earnings
global numq = 100
gen avgres${varoi}rank=.
gen avgres${varoi}rank2=.
qui bys agebin: bymyxtile avgres${varoi}${yrepr} avgres${varoi}rank2
local bin=1
forvalues h = 1(5)91{
	replace avgres${varoi}rank = `bin' if avgres${varoi}rank2>=`h' & avgres${varoi}rank2<=`h'+4
	local bin=`bin'+1
}
replace avgres${varoi}rank=20 if avgres${varoi}rank2>=96 & avgres${varoi}rank2<=99
replace avgres${varoi}rank=21 if avgres${varoi}rank2==100
drop avgres${varoi}rank2

** Log change in labor income between t-1 and t (then residualized)
gen res${varoi}chL1 = log(${varoi}${yrbr}) - log(${varoi}${yrepr})
bys age${yrepr}: egen avgL1 = mean(res${varoi}chL1)
replace res${varoi}chL1 = res${varoi}chL1-avgL1
la  var res${varoi}chL1 "Change in residual labor income btw t-1 and t"

bys age${yrepr}: egen mean${varoi}L1=mean(${varoi}${yrepr})
gen res${varoi}L1=${varoi}${yrepr}/mean${varoi}L1
drop avgL1

** Log change in total income between t-1 and t (then residualized)
gen restotincchL1 = log(totinc${yrbr}) - log(totinc${yrepr})
bys age${yrepr}: egen avgL1 = mean(restotincchL1)
replace restotincchL1 = restotincchL1-avgL1
la  var restotincchL1 "Change in residual total income btw t-1 and t"

bys age${yrepr}: egen meantotincL1=mean(totinc${yrepr})
gen restotincL1=totinc${yrepr}/meantotincL1
drop avgL1

** Now, compute the level of (residual) earnings in t+1,t+2,t+3,t+5, and t+10
bys age${yrepr}: egen mean${varoi}t=mean(${varoi}${yrbr})
gen res${varoi}t=${varoi}${yrbr}/mean${varoi}t
bys age${yrepr}: egen meantotinct=mean(totinc${yrbr})
gen restotinct=totinc${yrbr}/meantotinct
foreach lag in 1 2 3 5 10{
	bys age${yrepr}: egen mean${varoi}F`lag'=mean(${varoi}${yr`lag'L})
	gen res${varoi}F`lag'=${varoi}${yr`lag'L}/mean${varoi}F`lag'
	la var res${varoi}F`lag' "Residual labor income at t+`lag'"

	bys age${yrepr}: egen meantotincF`lag'=mean(totinc${yr`lag'L})
	gen restotincF`lag'=totinc${yr`lag'L}/meantotincF`lag'
	la var restotincF`lag' "Residual total income at t+`lag'"
}

gen year=${yrbr}
keep agebin avgres${varoi}rank res${varoi}chL1 res${varoi}L1 res${varoi}t 	///
	res${varoi}F1 res${varoi}F2 res${varoi}F3 res${varoi}F5 res${varoi}F10	///
	restotincchL1 restotincL1 restotinct restotincF1 restotincF2 ///
	restotincF3 restotincF5 restotincF10
order agebin avgres${varoi}rank
save tempdata${yrbr}, replace

