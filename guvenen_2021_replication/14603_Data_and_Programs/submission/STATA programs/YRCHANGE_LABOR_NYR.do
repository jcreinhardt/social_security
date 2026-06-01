drop _all
use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR19942013"

global YRCHANGEfolder="YRCHANGE$yrbr$yrer"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"
cd "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"

local yrdrop=${yrbpr}-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in labor{
		drop `var'`yr'
	}
}
/*local yrdrop1=${yrer}+1
local yrdrop2=${yr5L}-1
forvalues yr = `yrdrop1'/`yrdrop2'{  
	foreach var in labor{
		drop `var'`yr'
	}
}*/
local yrdrop=${yr5L}+1
forvalues yr = `yrdrop'/$yrlast{  
	foreach var in labor{
		drop `var'`yr'
	}
}

drop if yob >  ${yrepr} - ${begin_age} +1 
drop if yob <  ${yrer}  - ${retire_age} +1
drop if yod <= ${yrer}  & yod~=.	
drop yod

gen age${yrepr} = ${yrepr}-yob+1
gen agebin${yrepr} = .

local bin=1
forvalues h = $begin_age(5)$retire_age{
	replace agebin${yrepr} = `bin' if age${yrepr}>=`h' & age${yrepr}<min(`h'+5,${retire_age})	
	local bin=`bin' +1
}
qui sum agebin${yrepr}
local bin=r(max)
replace agebin${yrepr} = `bin'  if age${yrepr}==${retire_age}

* Calculate recent earnings by using residual earnings (take out year-age effects)
gen  avg${varoi}${yrepr}=0
gen  numobs${varoi}${yrepr}=0
gen  numallobs${varoi}${yrepr}=0
replace numobs${varoi}${yrepr}=-5 if ${varoi}${yrepr} < rmininc[1,${yrepr}-1959+1] | ${varoi}${yrepr}==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}${yrepr} = avg${varoi}${yrepr} + max(${varoi}`t', rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobs${varoi}${yrepr} = numobs${varoi}${yrepr} +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=.
	replace numallobs${varoi}${yrepr} = numallobs${varoi}${yrepr} +1 if ${varoi}`t'~=.
}
replace avg${varoi}${yrepr} = avg${varoi}${yrepr}/numallobs${varoi}${yrepr} if numobs${varoi}${yrepr}>=${minobspr}
replace avg${varoi}${yrepr} = . if numobs${varoi}${yrepr} < ${minobspr}
bys age${yrepr}: egen agedum = mean(avg${varoi}${yrepr})
replace avg${varoi}${yrepr} = ln(avg${varoi}${yrepr}) - ln(agedum) if numobs${varoi}${yrepr}>=${minobspr}
rename  avg${varoi}${yrepr} avgres${varoi}${yrepr}
drop numobs${varoi}${yrepr} numallobs${varoi}${yrepr} agedum

gen avgres${varoi}rankage${yrepr}=.
global numq=100
qui bys agebin${yrepr}: bymyxtile avgres${varoi}${yrepr} avgres${varoi}rankage${yrepr}
drop if avgres${varoi}rankage${yrepr}==. | agebin==.

* Calculate 1, 3 and 5 year future average earnings
gen avgF3=0
gen avgF5=0
gen numobsF3=0
gen numobsF5=0
forvalues t =$yrbr/$yr4L{
	if (`t'<=$yr2L){
		replace avgF3 = avgF3 + max(${varoi}`t',rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
		replace numobsF3 = numobsF3+1 if ${varoi}`t'~=.
	}
	replace avgF5 = avgF5 + max(${varoi}`t',rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobsF5 = numobsF5+1 if ${varoi}`t'~=.
}
replace avgF3 = avgF3/(${yr2L}-${yrbr}+1)
replace avgF5 = avgF5/(${yr4L}-${yrbr}+1)
gen avgF1 = max(${varoi}${yrbr},rmininc[1,${yrbr}-1959+1]) if ${varoi}${yrbr}~=.

foreach var in F1 F3 F5{
	* Calculate 1,3, 5-year future average earnings - RE
	bys age${yrepr}: egen agedum = mean(avg`var')
	replace avg`var' = ln(avg`var') - ln(agedum)
	gen resavg`var' = avg`var' - avgres${varoi}${yrepr}
	drop agedum avg`var'
	bymysum "resavg`var'" "D_" "age" "agebin$yrepr avgres${varoi}rankage$yrepr"
	bymypctile1 "resavg`var'" "agebin$yrepr avgres${varoi}rankage$yrepr"
}

use PC_resavgF1, clear
gen year=${yrepr}
merge 1:1 agebin avgres${varoi}rankage${yrepr} using PC_resavgF3, nogen
merge 1:1 agebin avgres${varoi}rankage${yrepr} using PC_resavgF5, nogen
merge 1:1 agebin avgres${varoi}rankage${yrepr} using D_resavgF1age, nogen
merge 1:1 agebin avgres${varoi}rankage${yrepr} using D_resavgF3age, nogen
merge 1:1 agebin avgres${varoi}rankage${yrepr} using D_resavgF5age, nogen
erase PC_resavgF1.dta
erase PC_resavgF3.dta
erase PC_resavgF5.dta
erase D_resavgF1age.dta
erase D_resavgF3age.dta
erase D_resavgF5age.dta
drop if agebin==.

order year
ren agebin agebin
ren avgreslaborrankage pastincpct
foreach var in resavgF1 resavgF3 resavgF5{
	ren D_N`var' N`var'
	ren D_mean`var' mean`var'
	ren D_sd`var' sd`var'
	ren D_skew`var' skew`var'
	ren D_kurt`var' kurt`var'
	ren D_min`var' min`var'
	ren D_max`var' max`var'
}
save avgch_${yrbr}, replace
