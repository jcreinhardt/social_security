drop _all
use "$maindirectory${sep}dta${sep}cleaned_male_WAGE_SELFINC_3EIN"

global YRCHANGEfolder="YRCHANGE$yrbr$yrer"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"
cd "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"

local yrdrop=$yrbpr-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in wage selfinc ein{
		drop `var'*`yr'
	}
}
local yrdrop1=$yrer+1
local yrdrop2=$yr5L-1
forvalues yr = `yrdrop1'/`yrdrop2'{  
	foreach var in wage selfinc{
		drop `var'*`yr'
	}
}
local yrdrop2=$yrepr-2
forvalues yr = $yrbpr/`yrdrop2'{
	drop ein*`yr'
}  
local yrdrop=$yr5L+1
forvalues yr = `yrdrop'/$yrlast{  
	foreach var in wage selfinc{
		drop `var'*`yr'
	}
}
local yrdrop=$yrer+2
forvalues yr = `yrdrop'/$yrlast{
	drop ein*`yr'
} 
forvalues yr = $yrbpr/$yrer{
	gen wage`yr'=wage1_`yr'+wage2_`yr'+wage3_`yr'
	drop if selfinc`yr' > max(rmininc[1,`yr'-1947+1],0.10*wage`yr') & selfinc`yr'~=. & wage`yr'~=.
	drop if selfinc`yr' > rmininc[1,`yr'-1947+1] & selfinc`yr'~=. & wage`yr'==.
	drop selfinc`yr'
}  
if($yr5L>$yrer) {
	gen wage${yr5L}=wage1_${yr5L}+wage2_${yr5L}+wage3_${yr5L}
	drop if selfinc$yr5L > max(rmininc[1,$yr5L-1947+1],0.10*wage$yr5L) & selfinc$yr5L~=. & wage$yr5L~=.
	drop if selfinc$yr5L > rmininc[1,$yr5L-1947+1] & selfinc$yr5L~=. & wage$yr5L==.
	drop selfinc$yr5L
}

drop if yob > $yrepr -$begin_age +1 
drop if yob < $yrer -$retire_age +1
drop if yod <= $yrer & yod~=.	
drop yod

gen age$yrepr = $yrepr-yob+1
gen agebin$yrepr = .

local bin=1
forvalues h = $begin_age(5)$retire_age{
	replace agebin$yrepr = `bin' if age$yrepr>=`h' & age$yrepr<min(`h'+5,$retire_age)	
	local bin=`bin' +1
}
qui sum agebin$yrepr
local bin=r(max)
replace agebin$yrepr = `bin'  if age$yrepr==$retire_age

matrix avgagedum${varoi}=J(1,$retire_age-$begin_age+1,0)
local dura = $yrepr-$yrbpr+1
local hmax = $retire_age-$begin_age+1
forvalues i=1/`hmax'{
	local dura1=min(`i',`dura')-1
	forvalues j=0/`dura1'{
		matrix avgagedum${varoi}[1,`i']	= avgagedum${varoi}[1,`i'] + agedum${varoi}[1,`i'-`j']
	}
	matrix avgagedum${varoi}[1,`i']	= ln(avgagedum${varoi}[1,`i']/(`dura1'+1))
}

gen  avg${varoi}$yrepr=0
gen  numobs${varoi}$yrepr=0
gen  numallobs${varoi}$yrepr=0
replace numobs${varoi}$yrepr=-5 if ${varoi}$yrepr < rmininc[1,$yrepr-1947+1] | ${varoi}$yrepr==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}$yrepr=avg${varoi}$yrepr +max(${varoi}`t', rmininc[1,`t'-1947+1]) if ${varoi}`t'~=.
	replace numobs${varoi}$yrepr=numobs${varoi}$yrepr +1 if ${varoi}`t' >= rmininc[1,`t'-1947+1] & ${varoi}`t'~=.
	replace numallobs${varoi}$yrepr=numallobs${varoi}$yrepr +1 if ${varoi}`t'~=.
}
replace avg${varoi}$yrepr = avg${varoi}$yrepr/numallobs${varoi}$yrepr if numobs${varoi}$yrepr >=$minobspr
replace avg${varoi}$yrepr = . if numobs${varoi}$yrepr < $minobspr 
replace avg${varoi}$yrepr = ln(avg${varoi}${yrepr}) - avgagedum${varoi}[1,age$yrepr-$begin_age+1] if numobs${varoi}$yrepr >=$minobspr
rename avg${varoi}$yrepr avgres${varoi}$yrepr 
drop numobs${varoi}$yrepr numallobs${varoi}$yrepr

drop if avgres${varoi}$yrepr == .

gen avgres${varoi}rankage$yrepr=.
global numq=100
qui bys agebin${yrepr}: bymyxtile avgres${varoi}${yrepr} avgres${varoi}rankage${yrepr}

// Define stayers and job changers _ Method I
drop if ein1_${yrbr}==. | ein1_${yrer}==.
gen cond=0
replace cond=cond+1 if (ein1_${yrbr}~=ein1_${yrer}) 

replace cond=cond+1 if (wage1_${yrbr}/wage${yrbr})>=0.50 & (wage1_${yrer}/wage${yrer})>=0.50
replace cond=cond+1 if (ein1_${yrbr}~=ein2_${yrer} & ein1_${yrbr}~=ein3_${yrer}) | ///
						(ein1_${yrbr}==ein2_${yrer} & wage2_${yrer}<0.25*wage1_${yrbr}) | ///
						(ein1_${yrbr}==ein3_${yrer} & wage3_${yrer}<0.25*wage1_${yrbr}) 
replace cond=cond+1 if (ein1_${yrer}~=ein2_${yrbr} & ein1_${yrer}~=ein3_${yrbr}) | ///
						(ein1_${yrer}==ein2_${yrbr} & wage2_${yrbr}<0.25*wage1_${yrer}) | ///
						(ein1_${yrer}==ein3_${yrbr} & wage3_${yrbr}<0.25*wage1_${yrer}) 						

gen stayI${yrbr}${yrer}=1
replace stayI${yrbr}${yrer}=0 if cond==4
drop cond

gen ein1_${yrbr}ratio${yrbr}=wage1_${yrbr}/wage${yrbr} if stayI${yrbr}${yrer}==0
gen ein1_${yrbr}ratio${yrer}=.
replace ein1_${yrbr}ratio${yrer}=0 if (ein1_${yrbr}~=ein2_${yrer} & ein1_${yrbr}~=ein3_${yrer}) & stayI${yrbr}${yrer}==0
replace ein1_${yrbr}ratio${yrer}=wage2_${yrer}/wage1_${yrbr} if ein1_${yrbr}==ein2_${yrer} & stayI${yrbr}${yrer}==0
replace ein1_${yrbr}ratio${yrer}=wage3_${yrer}/wage1_${yrbr} if ein1_${yrbr}==ein3_${yrer} & stayI${yrbr}${yrer}==0

gen ein1_${yrer}ratio${yrer}=wage1_${yrer}/wage${yrer} if stayI${yrbr}${yrer}==0
gen ein1_${yrer}ratio${yrbr}=.
replace ein1_${yrer}ratio${yrbr}=0 if (ein1_${yrer}~=ein2_${yrbr} & ein1_${yrer}~=ein3_${yrbr}) & stayI${yrbr}${yrer}==0
replace ein1_${yrer}ratio${yrbr}=wage2_${yrbr}/wage1_${yrer} if ein1_${yrer}==ein2_${yrbr} & stayI${yrbr}${yrer}==0
replace ein1_${yrer}ratio${yrbr}=wage3_${yrbr}/wage1_${yrer} if ein1_${yrer}==ein3_${yrbr} & stayI${yrbr}${yrer}==0

gen dropind=1
foreach yr1 in $yrbr $yrer{
	foreach yr2 in $yrbr $yrer{
	kdensity ein1_`yr1'ratio`yr2', gen(H_ein1_`yr1'ratio`yr2'_x H_ein1_`yr1'ratio`yr2'_d) n(500) nograph
	replace dropind=0 if H_ein1_`yr1'ratio`yr2'_x ~=.
	}
}
outsheet H* if dropind==0 using hist_switch${yrbr}.txt, replace
drop H* dropind ein1*ratio*


// Define stayers and job changers _ Method II
drop if ein1_${yrbr}==. | ein1_${yrer}==.
global yr1L=${yrbr}-1
global yr1F=${yrer}+1
gen stayII${yrbr}${yrer}=0

replace stayII${yrbr}${yrer}=1 if (ein1_${yrbr}==ein1_${yrer}) &  (ein1_${yr1L}==ein1_${yrbr}) ///
									&  (ein1_${yrer}==ein1_${yr1F})
 
//	Log of Residual Change by Age

gen res${varoi}ch$yrbr$yrer = log(${varoi}$yrer/agedum${varoi}[1,$yrer-yob+1-$begin_age+1]) - log(${varoi}$yrbr/agedum${varoi}[1,$yrbr-yob+1-$begin_age+1]) ///
if ${varoi}$yrer>=rmininc[1,$yrer-1947+1]/3 & ${varoi}$yrbr>=rmininc[1,$yrbr-1947+1] // Residual income change between before and after recession

bymydiststat "res${varoi}ch$yrbr$yrer" "PR" "stayI" "agebin$yrepr  avgres${varoi}rankage$yrepr stayI${yrbr}${yrer}"
bymydiststat "res${varoi}ch$yrbr$yrer" "PR" "stayII" "agebin$yrepr  avgres${varoi}rankage$yrepr stayII${yrbr}${yrer}"
/*
if($yr5L>$yrer){
	gen res${varoi}ch$yrbr$yr5L = log(${varoi}$yr5L/agedum${varoi}[1,$yr5L-yob+1-$begin_age+1]) - log(${varoi}$yrbr/agedum${varoi}[1,$yrbr-yob+1-$begin_age+1]) ///
	if ${varoi}$yr5L>=rmininc[1,$yr5L-1947+1]/3 & ${varoi}$yrbr>=rmininc[1,$yrbr-1947+1] & samejob==${allyr} // Residual income change between before and after recession
	bymydiststat "res${varoi}ch$yrbr$yr5L" "PR" "age" "agebin$yrepr  avgres${varoi}rankage$yrepr"	
}
*/
foreach st in I II{
	drop _all
	use PRres${varoi}ch$yrbr${yrer}stay`st'.dta 
	erase PRres${varoi}ch$yrbr${yrer}stay`st'.dta
	outsheet using PRres${varoi}ch$yrbr${yrer}stay`st'.txt, replace
}
/*
if($yr5L>$yrer){
	drop _all
	use PR`var'${varoi}ch$yrbr${yr5L}age.dta 
	erase PR`var'${varoi}ch$yrbr${yr5L}age.dta
	outsheet using PR`var'${varoi}ch$yrbr${yr5L}age.txt, replace
}
*/

