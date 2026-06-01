drop _all
use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR19942013"

global YRCHANGEfolder="YRCHANGE_${NL}YR_$yrbr$yr1L"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR${sep}$YRCHANGEfolder"
cd "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR${sep}$YRCHANGEfolder"

local yrdrop=${yrbpr}-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in labor{
		drop `var'`yr'
	}
}

local yrdrop=${yr5L}+${NL}+1
forvalues yr = `yrdrop'/$yrlast{  
	foreach var in labor{
		drop `var'`yr'
	}
}

drop if yob >  ${yrepr} - ${begin_age} +1 
drop if yob <  ${yr1L}-${retire_age}+1
drop if yod <= ${yr1L}  & yod~=.	
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

* Calculate {NL} year future average (residual) earnings starting in t (yrbr)
gen avg${varoi}t = 0
local yrla=${yrbr}+${NL}
forvalues yr = $yrbr/`yrla'{
	replace avg${varoi}t = avg${varoi}t + max(${varoi}`yr',rmininc[1,`yr'-1959+1]) if ${varoi}`yr'~=.
}
replace avg${varoi}t = avg${varoi}t/(`yrla'-${yrbr}+1)
bys age${yrepr}: egen agedum = mean(avg${varoi}t)
gen avgres${varoi}t = log(avg${varoi}t) - log(agedum)
drop avg${varoi}t agedum

* Calculate {NL} year future average (residual) earnings starting in t+{NL}+1 (yr1a)
gen avg${varoi}F1=0
local yrla=${yr1L}+${NL}
forvalues yr = $yr1L/`yrla'{
	replace avg${varoi}F1 = avg${varoi}F1 + max(${varoi}`yr',rmininc[1,`yr'-1959+1]) if ${varoi}`yr'~=.
}
replace avg${varoi}F1 = avg${varoi}F1/(`yrla'-${yr1L}+1)
bys age${yrepr}: egen agedum = mean(avg${varoi}F1)
gen avgres${varoi}F1 = log(avg${varoi}F1) - log(agedum)
drop avg${varoi}F1 agedum

gen avgres${varoi}${NL}ch = avgres${varoi}F1 - avgres${varoi}t
bymysum "avgres${varoi}${NL}ch" "D_" "age" "agebin$yrepr avgres${varoi}rankage$yrepr"
bymypctile1 "avgres${varoi}${NL}ch" "agebin$yrepr avgres${varoi}rankage$yrepr"

use PC_avgres${varoi}${NL}ch, clear
gen year=${yrepr}
merge 1:1 agebin avgres${varoi}rankage${yrepr} using D_avgres${varoi}${NL}chage, nogen
erase PC_avgres${varoi}${NL}ch.dta
erase D_avgres${varoi}${NL}chage.dta
drop if agebin==.

order year
ren agebin agebin
ren avgreslaborrankage pastincpct
foreach var in avgreslabor$NLch{
	ren D_N`var' N
	ren D_mean`var' mean
	ren D_sd`var' sd
	ren D_skew`var' skew
	ren D_kurt`var' kurt
	ren D_min`var' min
	ren D_max`var' max
	ren p1avg p1
	ren p2_5avg p2_5
	ren p5avg p5
	ren p10avg p10
	ren p12_5avg p12_5
	ren p25avg p25
	ren p37_5avg p37_5
	ren p50avg p50
	ren p62_5avg p62_5
	ren p75avg p75
	ren p87_5avg p87_5
	ren p90avg p90
	ren p95avg p95
	ren p97_5avg p97_5
	ren p99avg p99
}
save avgch_${NL}_${yrbr}, replace
