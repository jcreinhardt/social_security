// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// This program generates 10 % sample of males between 1978-2013
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

clear all
capture log close
set more off
set matsize 500
set linesize 255

// Jae: You should change the below directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata/"
global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac

if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}

//JAE: Please change the below to the name of the 10% 1978-2013 sample
global datafile10percent="$maindirectory${sep}dta${sep}temp_male_dib" 

// YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!


cd "$maindirectory${sep}dta${sep}"

use "${datafile10percent}"
keep wage* yob yod male selfinc*
destring, replace force


global yrfirst = 1978 		// First year in the dataset
global yrlast = 2013 		// Last year in the dataset
global begin_age = 25 
global retire_age = 60

global base_price = 52   /* this is the index of the year 2010 */
matrix cpimat = /*  CPI for 1959-2013
*/ (17.262,17.546,17.730,17.939,18.149,18.414,18.681,19.155,19.637,20.402,	/*
*/ 21.327,22.325,23.274,24.070,25.368,28.009,30.348,32.013,34.091,36.479, 	/*
*/ 39.714,43.978,47.908,50.553,52.729,54.724,56.661,57.887,59.650,61.974,	/*
*/ 64.641,64.641,67.440,69.652,71.494,73.279,74.803,76.356,77.981,79.327,	/*
*/ 79.936,81.110,83.131,84.736,85.873,87.572,89.703,92.261,94.729,97.101, 	/*
*/ 100.065,100.000,101.653,104.149,106.062,107.333)



display "***********************************"
display "MALE Sample"
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

	gen labor`yr' = wage1_`yr'+wage2_`yr'+wage3_`yr' + 2*selfinc`yr'/3
	drop wage1_`yr' wage2_`yr' wage3_`yr' selfinc`yr'
}
foreach var in labor{
	forvalues yr = $yrfirst/$yrlast{
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
}
compress
save "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013", replace


display "***********************************"
display "MALE Sample Summary Statistics" 
display "***********************************"

global basla=c(current_time)


global base_price = 52   /* this is the index of the year 2010 */
matrix cpimat = /*  CPI for 1959-2013
*/ (17.262,17.546,17.730,17.939,18.149,18.414,18.681,19.155,19.637,20.402,	/*
*/ 21.327,22.325,23.274,24.070,25.368,28.009,30.348,32.013,34.091,36.479, 	/*
*/ 39.714,43.978,47.908,50.553,52.729,54.724,56.661,57.887,59.650,61.974,	/*
*/ 64.641,64.641,67.440,69.652,71.494,73.279,74.803,76.356,77.981,79.327,	/*
*/ 79.936,81.110,83.131,84.736,85.873,87.572,89.703,92.261,94.729,97.101, 	/*
*/ 100.065,100.000,101.653,104.149,106.062,107.333)


matrix minwg = /* Nominal minimum wage 1959-2013
*/ (1.00,1.00,1.00,1.15,1.15,1.25,1.25,1.25,1.25,1.40,1.60,1.60,1.60,1.60,/*
*/  1.60,1.60,2.00,2.10,2.10,2.30,2.65,2.90,3.10,3.35,3.35,3.35,3.35,3.35,/*
*/  3.35,3.35,3.35,3.35,3.80,4.25,4.25,4.25,4.25,4.25,4.75,5.15,5.15,5.15,/*
*/  5.15,5.15,5.15,5.15,5.15,5.15,5.15,5.85,6.55,7.25,7.25,7.25,7.25)


matrix rmininc = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1959/2013{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
	matrix rmininc[1,`cpi_index']=40*13*0.5*minwg[1,`cpi_index']*`deflate'
}

global outfolder=c(current_date)
global outfolder="$outfolder LaborAgeDum_M2013"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
capture noisily log using "$maindirectory${sep}log${sep}$outfolder.log", replace
cd "$maindirectory${sep}out${sep}$outfolder"

do "$maindirectory${sep}do${sep}bymydiststat2.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

capture log close
capture noisily log using "$maindirectory${sep}out${sep}$outfolder${sep}MALE_10p_LABOR.log", replace

display "***********************************"
display "MALE Sample"
display "***********************************"
count
tab yob
tab yod
forvalues yr = $yrfirst/$yrlast{
	count if labor`yr'>0
	sum labor`yr'
	sum labor`yr'  if labor`yr'>0
}
capture log close


// ************************************************************************************************	
//	Age Dummies
// ************************************************************************************************	

use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013", clear

global yrfirst = 1994 		// First year in the dataset
global yrlast = 2013 		// Last year in the dataset
global begin_age = 25 
global retire_age = 60

drop if $yrfirst-yob+1>$retire_age | $yrlast-yob+1<$begin_age 
drop if yod<=$yrfirst & yod~=.
count

forvalues yr = 1978/1993{
	drop labor`yr'	
}

save "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR19942013", replace

sample 10

gen id=_n
save "$maindirectory${sep}dta${sep}temp", replace
/* Convert to long format */

forval y = $yrfirst/$yrlast {
	/* Load data */

	u id yob yod labor`y' ///
		if `y'<yod & `y'-yob+1 >= $begin_age & `y'- yob+1<=$retire_age ///
		using "$maindirectory${sep}dta${sep}temp", clear
	drop yod

	/* Rename variables */
	rename labor`y' labor

	/* Construct variables */

	gen int year = `y'
	gen byte age = year-yob+1
	
	/* Sample criteria */

	keep if inrange(age,$begin_age,$retire_age)
	keep if labor>= rmininc[1,`y'-1959+1]
	

	/* Save data */

	if `y'>$yrfirst {
		append using "$maindirectory${sep}dta${sep}Long_Data_male"
	}

	save "$maindirectory${sep}dta${sep}Long_Data_male", replace
}
erase "$maindirectory${sep}dta${sep}temp.dta"

drop _all
use "$maindirectory${sep}dta${sep}Long_Data_male"
erase "$maindirectory${sep}dta${sep}Long_Data_male.dta"

gen loglabor=log(labor)
bymydiststat "labor" "SL_" "_yrage" "year age"
bymydiststat "loglabor" "SL_" "_yrage" "year age"

tab year, gen(yeardum)
tab age, gen(agedum)
tab yob, gen(cohdum)

global bit=c(current_time)
macro list basla bit
capture noisily log close

capture noisily log using "$maindirectory${sep}out${sep}$outfolder${sep}agedummy_LABOR.log", replace

regress loglabor agedum* cohdum2-cohdum55, nocons
regress labor agedum* cohdum2-cohdum55, nocons

regress loglabor agedum* yeardum2-yeardum20, nocons
regress labor agedum* yeardum2-yeardum20, nocons

global bit=c(current_time)
capture noisily log close


drop _all
use SL_labor_yrage.dta
erase SL_labor_yrage.dta
outsheet using SL_labor_yrage.txt, replace

drop _all
use SL_loglabor_yrage.dta
erase SL_loglabor_yrage.dta
outsheet using SL_loglabor_yrage.txt, replace

