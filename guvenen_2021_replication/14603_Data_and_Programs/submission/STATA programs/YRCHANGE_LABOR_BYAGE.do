drop _all
use "$maindirectory${sep}dta${sep}MALE_LABORwDIBwTOTINC2013"

global YRCHANGEfolder="YRCHANGE$yrbr$yrer"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"
cd "$maindirectory${sep}out${sep}$outfolder${sep}$YRCHANGEfolder"

drop dib*
local yrdrop=$yrbpr-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in labor totinc{
		drop `var'`yr'
	}
}
local yrdrop1=${yrer}+1
local yrdrop2=${yr5L}-1
forvalues yr = `yrdrop1'/`yrdrop2'{  
	foreach var in labor totinc{
		drop `var'`yr'
	}
}
local yrdrop=${yr5L}+1
forvalues yr = `yrdrop'/$yrlast{  
	foreach var in labor totinc{
		drop `var'`yr'
	}
}

drop if yob > ${yrepr} -${begin_age} +1 
drop if yob < ${yrer} -${retire_age} +1
drop if yod <= ${yrer} & yod~=.	
drop yod

* Define age
gen age${yrepr} = ${yrepr}-yob+1

* Log change in residual earnings
gen ${varoi}ch${yrbr}${yrer} = log(${varoi}${yrer}/${varoi}${yrbr})
bys age${yrepr}: egen avg${varoi}chL1 = mean(${varoi}ch${yrbr}${yrer})
gen res${varoi}ch${yrbr}${yrer} = ${varoi}ch${yrbr}${yrer} - avg${varoi}chL1 ///
	if ${varoi}${yrer}>=rmininc[1,${yrer}-1959+1]/3 & ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
bymysum "res${varoi}ch$yrbr$yrer" "D_" "age" "age$yrepr"
bymypctile1 "res${varoi}ch$yrbr$yrer"  "age$yrepr"

if($yr5L>$yrer){
	gen ${varoi}ch${yrbr}${yr5L} = log(${varoi}${yr5L}/${varoi}${yrbr})
	bys age${yrepr}: egen avg${varoi}chL5 = mean(${varoi}ch${yrbr}${yr5L})
	gen res${varoi}ch${yrbr}${yr5L} = ${varoi}ch${yrbr}${yr5L} - avg${varoi}chL5 ///
		if ${varoi}${yr5L}>=rmininc[1,${yr5L}-1959+1]/3 & ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
	bymysum "res${varoi}ch$yrbr$yr5L" "D_" "age" "age$yrepr"
	bymypctile1 "res${varoi}ch$yrbr$yr5L"  "age$yrepr"
}
cap noi drop avg${varoi}chL1 avg${varoi}chL5 ${varoi}ch${yrbr}${yrer} ${varoi}ch${yrbr}${yr5L} res${varoi}ch$yrbr$yrer res${varoi}ch$yrbr$yr5L

* Arc percent change in earnings
bys age${yrepr}: egen avg${varoi}${yrbr} = mean(${varoi}${yrbr})
bys age${yrepr}: egen avg${varoi}${yrer} = mean(${varoi}${yrer})
gen resA${varoi}ch${yrbr}${yrer} = ///
	2*(${varoi}${yrer}/avg${varoi}${yrer} - ${varoi}${yrbr}/avg${varoi}${yrbr})/ 	///
	  (${varoi}${yrer}/avg${varoi}${yrer} + ${varoi}${yrbr}/avg${varoi}${yrbr}) 		///
	if ${varoi}${yrer}>=rmininc[1,${yrer}-1959+1] | ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]
bymysum "resA${varoi}ch$yrbr$yrer" "D_" "age" "age$yrepr"
bymypctile1 "resA${varoi}ch$yrbr$yrer"  "age$yrepr"

if($yr5L>$yrer){
	bys age${yrepr}: egen avg${varoi}${yr5L} = mean(${varoi}${yr5L})
	gen resA${varoi}ch${yrbr}${yr5L} = ///
		2*(${varoi}${yr5L}/avg${varoi}${yr5L} - ${varoi}${yrbr}/avg${varoi}${yrbr})/ ///
		  (${varoi}${yr5L}/avg${varoi}${yr5L} + ${varoi}${yrbr}/avg${varoi}${yrbr}) ///
		if ${varoi}${yr5L}>=rmininc[1,${yr5L}-1959+1] | ${varoi}${yrbr}>=rmininc[1,${yrbr}-1959+1]	
	bymysum "resA${varoi}ch$yrbr$yr5L" "D_" "age" "age$yrepr"
	bymypctile1 "resA${varoi}ch$yrbr$yr5L"  "age$yrepr"
}
cap noi drop avg${varoi}${yrbr} avg${varoi}${yrer} avg${varoi}${yr5L} resA${varoi}ch${yrbr}*

use PC_res${varoi}ch${yrbr}${yrer}, clear
gen year=${yrepr}
merge 1:1 age using PC_resA${varoi}ch${yrbr}${yrer}, nogen
merge 1:1 age using D_res${varoi}ch${yrbr}${yrer}age, nogen
merge 1:1 age using D_resA${varoi}ch${yrbr}${yrer}age, nogen
erase PC_res${varoi}ch${yrbr}${yrer}.dta
erase PC_resA${varoi}ch${yrbr}${yrer}.dta
erase D_res${varoi}ch${yrbr}${yrer}age.dta
erase D_resA${varoi}ch${yrbr}${yrer}age.dta
drop if age==.

order year
ren age age
foreach var in reslaborch resAlaborch{
	ren p1`var' p1`var'
	ren p2_5`var' p2_5`var'
	ren p5`var' p5`var'
	ren p10`var' p10`var'
	ren p12_5`var' p12_5`var'
	ren p25`var' p25`var'
	ren p37_5`var' p37_5`var'
	ren p50`var' p50`var'
	ren p62_5`var' p62_5`var'
	ren p75`var' p75`var'
	ren p87_5`var' p87_5`var'
	ren p90`var' p90`var'
	ren p95`var' p95`var'
	ren p97_5`var' p97_5`var'
	ren p99`var' p99`var'

	ren D_N`var' N`var'
	ren D_mean`var' mean`var'
	ren D_sd`var' sd`var'
	ren D_skew`var' skew`var'
	ren D_kurt`var' kurt`var'
	ren D_min`var' min`var'
	ren D_max`var' max`var'
}
save L1_${yrbr}, replace

if($yr5L>$yrer){
	use PC_res${varoi}ch${yrbr}${yr5L}, clear
	gen year=${yrepr}
	merge 1:1 age using PC_resA${varoi}ch${yrbr}${yr5L}, nogen
	merge 1:1 age using D_res${varoi}ch${yrbr}${yr5L}age, nogen
	merge 1:1 age using D_resA${varoi}ch${yrbr}${yr5L}age, nogen
	erase PC_res${varoi}ch${yrbr}${yr5L}.dta
	erase PC_resA${varoi}ch${yrbr}${yr5L}.dta
	erase D_res${varoi}ch${yrbr}${yr5L}age.dta
	erase D_resA${varoi}ch${yrbr}${yr5L}age.dta
	drop if age==.

	order year
	ren age age
	foreach var in reslaborch resAlaborch{
		ren p1`var' p1`var'
		ren p2_5`var' p2_5`var'
		ren p5`var' p5`var'
		ren p10`var' p10`var'
		ren p12_5`var' p12_5`var'
		ren p25`var' p25`var'
		ren p37_5`var' p37_5`var'
		ren p50`var' p50`var'
		ren p62_5`var' p62_5`var'
		ren p75`var' p75`var'
		ren p87_5`var' p87_5`var'
		ren p90`var' p90`var'
		ren p95`var' p95`var'
		ren p97_5`var' p97_5`var'
		ren p99`var' p99`var'

		ren D_N`var' N`var'
		ren D_mean`var' mean`var'
		ren D_sd`var' sd`var'
		ren D_skew`var' skew`var'
		ren D_kurt`var' kurt`var'
		ren D_min`var' min`var'
		ren D_max`var' max`var'
	}
	save L5_${yrbr}, replace
}

/*foreach var in res resA{
	drop _all
	use D_`var'${varoi}ch$yrbr${yrer}age.dta
	erase D_`var'${varoi}ch$yrbr${yrer}age.dta
	outsheet using D_`var'${varoi}ch$yrbr${yrer}age.txt, replace

	drop _all
	use PC_`var'${varoi}ch$yrbr${yrer}.dta
	erase PC_`var'${varoi}ch$yrbr${yrer}.dta
	outsheet using PC_`var'${varoi}ch$yrbr${yrer}.txt, replace

	if($yr5L>$yrer){
		drop _all
		use D_`var'${varoi}ch$yrbr${yr5L}age.dta 
		erase D_`var'${varoi}ch$yrbr${yr5L}age.dta
		outsheet using D_`var'${varoi}ch$yrbr${yr5L}age.txt, replace

		drop _all
		use PC_`var'${varoi}ch$yrbr${yr5L}.dta
		erase PC_`var'${varoi}ch$yrbr${yr5L}.dta
		outsheet using PC_`var'${varoi}ch$yrbr${yr5L}.txt, replace
	}
}*/
