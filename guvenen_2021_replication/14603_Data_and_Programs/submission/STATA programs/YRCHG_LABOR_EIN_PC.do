drop _all
use "$maindirectory${sep}dta${sep}cleaned_male_LABOR_SELFINC_3EIN"

global YRCHANGEfolder="YRCHANGE$yrbr$yrer"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"
cd "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"

disp $yrbr 

local yrdrop=$yrbpr-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in wage selfinc ein{
		drop `var'*`yr'
	}
}
local yrdrop1=$yrer+2
local yrdrop2=$yr5F-1
forvalues yr = `yrdrop1'/`yrdrop2'{  
	foreach var in wage selfinc labor ein{
		drop `var'*`yr'
	}
}
local yrdrop2=$yrepr-1
forvalues yr = $yrbpr/`yrdrop2'{
	drop ein*`yr'
}  
local yrdrop=$yr6F+1
forvalues yr = `yrdrop'/$yrlast{  
	foreach var in wage selfinc labor ein{
		drop `var'*`yr'
	}
}

drop if yob > $yrepr -$begin_age +1 
drop if yob < $yrer -$retire_age +1
drop if yod <= $yrer & yod~=.	
drop yod

gen age$yrepr = $yrepr-yob+1
gen agebin$yrepr = .

replace agebin$yrepr = 1  if age$yrepr==$begin_age
local bin=1
local age_fr=$begin_age+1
forvalues h = `age_fr'(5)$retire_age{
	replace agebin$yrepr = `bin' if age$yrepr>=`h' & age$yrepr<=min(`h'+4,$retire_age)	
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
replace numobs${varoi}$yrepr=-5 if ${varoi}$yrepr < rmininc[1,$yrepr-1959+1] | ${varoi}$yrepr==.
forvalues t =$yrbpr/$yrepr{	
	replace avg${varoi}$yrepr=avg${varoi}$yrepr +max(${varoi}`t', rmininc[1,`t'-1959+1]) if ${varoi}`t'~=.
	replace numobs${varoi}$yrepr=numobs${varoi}$yrepr +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=.
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

replace agebin${yrepr}=.
replace agebin${yrepr} = 1 if age$yrepr>=25 & age$yrepr<=35	
replace agebin${yrepr} = 2 if age$yrepr>=36 & age$yrepr<=45	
replace agebin${yrepr} = 3 if age$yrepr>=46 & age$yrepr<=55	

drop if agebin${yrepr} ==. 

 
// Define stayers and job changers - Method II V2

drop if ${varoi}$yrer<rmininc[1,$yrer-1959+1] | ${varoi}$yrbr<rmininc[1,${yrbr}-1959+1]
drop if ein1_${yrbr}==. | ein1_${yrer}==.

global yr1L=${yrbr}-1
global yr1F=${yrer}+1
gen stayIIv2_${yrbr}${yrer}=0
				
replace stayIIv2_${yrbr}${yrer}=1 if (ein1_${yrbr}==ein1_${yrer}) &  ///
				(wage1_${yrbr}/labor${yrbr}>=0.80 & wage1_${yrer}/labor${yrer} >= 0.80) & ///
	(ein1_${yr1L}==ein1_${yrbr} | ein2_${yr1L}==ein1_${yrbr} | ein3_${yr1L}==ein1_${yrbr} ) & ///
	(ein1_${yrer}==ein1_${yr1F} | ein1_${yrer}==ein2_${yr1F} | ein1_${yrer}==ein3_${yr1F} ) & ///
	selfinc${yrbr} < max(rmininc[1,${yrbr}-1959+1],0.10*labor${yrbr}) & ///
	selfinc${yrer} < max(rmininc[1,${yrer}-1959+1],0.10*labor${yrer})
	
//replace stayIIv2_${yrbr}${yrer}=1 if selfinc${yrbr}/labor${yrbr} >=0.80 & ///
//		selfinc${yrer}/labor${yrer} >= 0.80 & ///
//		selfinc${yr1L} >= max(rmininc[1,${yr1L}-1959+1],0.10*labor${yr1L}) & ///
//		selfinc${yr1F} >= max(rmininc[1,${yr1F}-1959+1],0.10*labor${yr1F}) 		
	
	
	//	Log of Residual Change by Age

gen res${varoi}ch$yrbr${yrer} = log(${varoi}$yrer/agedum${varoi}[1,$yrer-yob+1-${begin_age}+1]) - ///
							    log(${varoi}$yrbr/agedum${varoi}[1,$yrbr-yob+1-${begin_age}+1]) ///
	if ${varoi}$yrer>=rmininc[1,$yrer-1959+1]/3 & ${varoi}$yrbr>=rmininc[1,${yrbr}-1959+1] 		// Residual income change between before and after recession

bys	age$yrepr: egen mean_res${varoi}ch=mean(res${varoi}ch$yrbr${yrer})
replace res${varoi}ch$yrbr${yrer}=res${varoi}ch$yrbr${yrer}-mean_res${varoi}ch
drop mean_res${varoi}ch
	
bymypctile1 "res${varoi}ch$yrbr$yrer" "agebin$yrepr  avgres${varoi}rankage$yrepr stayIIv2_${yrbr}${yrer}"

// Define stayers and job changers between t and t+5 - Method II V2
if($yr6F>$yr5F & $yr5F>${yrer}){
	drop if ${varoi}$yrer<rmininc[1,$yrer-1959+1] | ${varoi}${yr5F}<rmininc[1,${yr5F}-1959+1]
	drop if ein1_${yrbr}==. | ein1_${yr5F}==.
	global yr1L=${yrbr}-1
	gen stayIIv2_${yrbr}${yr5F}=0

	replace stayIIv2_${yrbr}${yr5F}=1 if (ein1_${yrbr}==ein1_${yr5F}) &  ///
				(wage1_${yrbr}/labor${yrbr}>=0.80 & wage1_${yr5F}/labor${yr5F} >= 0.80) & ///
	(ein1_${yr1L}==ein1_${yrbr} | ein2_${yr1L}==ein1_${yrbr} | ein3_${yr1L}==ein1_${yrbr} ) & ///
	(ein1_${yr5F}==ein1_${yr6F} | ein1_${yr5F}==ein2_${yr6F} | ein1_${yr5F}==ein3_${yr6F} ) & ///	
	selfinc${yrbr} < max(rmininc[1,${yrbr}-1959+1],0.10*labor${yrbr}) & ///
	selfinc${yr5F} < max(rmininc[1,${yr5F}-1959+1],0.10*labor${yr5F})

	//replace stayIIv2_${yrbr}${yrer}=1 if selfinc${yrbr}/labor${yrbr} >=0.80 & ///
	//	selfinc${yr5F}/labor${yr5F} >= 0.80 & ///
	//	selfinc${yr1L} >= max(rmininc[1,${yr1L}-1959+1],0.10*labor${yr1L}) & ///
	//	selfinc${yr6F} >= max(rmininc[1,${yr6F}-1959+1],0.10*labor${yr6F}) 		
	
	gen res${varoi}ch$yrbr${yr5F} = log(${varoi}$yr5F/agedum${varoi}[1,$yr5F-yob+1-${begin_age}+1]) - ///
								log(${varoi}$yrbr/agedum${varoi}[1,$yrbr-yob+1-${begin_age}+1]) ///
	if ${varoi}$yr5F>=rmininc[1,$yr5F-1959+1]/3 & ${varoi}$yrbr>=rmininc[1,${yrbr}-1959+1]  	// Residual income change between before and after recession

	bys	age$yrepr: egen mean_res${varoi}ch=mean(res${varoi}ch$yrbr${yr5F})
	replace res${varoi}ch$yrbr${yr5F}=res${varoi}ch$yrbr${yr5F}-mean_res${varoi}ch
	drop mean_res${varoi}ch	
	
	bymypctile1 "res${varoi}ch$yrbr$yr5F"  "agebin$yrepr avgres${varoi}rankage$yrepr stayIIv2_${yrbr}${yr5F}"
}
	 
drop _all
use PC_res${varoi}ch$yrbr${yrer}.dta 
erase PC_res${varoi}ch$yrbr${yrer}.dta
outsheet using PC_res${varoi}ch$yrbr${yrer}.txt, replace

if($yr6F>$yr5F & $yr5F>${yrer}){
	drop _all
	use PC_res${varoi}ch$yrbr${yr5F}.dta 
	erase PC_res${varoi}ch$yrbr${yr5F}.dta
	outsheet using PC_res${varoi}ch$yrbr${yr5F}.txt, replace
}
