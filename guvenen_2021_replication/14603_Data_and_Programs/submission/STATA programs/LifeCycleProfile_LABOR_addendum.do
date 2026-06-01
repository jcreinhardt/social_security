clear all
capture log close
set more off
set matsize 500
set linesize 255

** JAE: Please change the below directory. This is the usual working directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata"
** JAE: Please change this to 1 if you run Stata on Unix or Mac
global unix=1
** JAE: Please replace temp_male to the name of the 10% 1978-2013 sample
global datafilename="temp_male"

** YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!
if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}

global datafile10percent="$maindirectory${sep}dta${sep}${datafilename}"

** We first (re-)generate 10 % sample of males between 1978-2013
cd "$maindirectory${sep}dta${sep}"

use "${datafile10percent}"
keep wage* yob yod male selfinc*
destring, replace force

global yrfirst = 1978 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global yrtopcodelast=1993
global begin_age  = 25
global retire_age = 60
global varoi="labor" 		// Income list that we analyze
global statlist="mean sd skew kurt kurt2 min max p10 p50 p90"

global base_price = 52   	/* this is the index of the year 2010 */
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

matrix topinc = /* Max. taxable earnings each year 1959-2013
*/ 1000*(4.8,4.8,4.8,4.8,4.8,4.8,4.8,6.6,6.6,7.8,7.8,7.8,7.8,9.0,10.8,13.2,14.1,/*
*/  15.3,16.5,17.7,22.9,25.9,29.7,32.4,35.7,37.8,39.6,42.0,43.8,45.0,48.0,/*
*/  51.3,53.4,55.5,57.6,60.6,61.2,62.7,65.4,68.4,72.6,76.2,80.4,84.9,87.0,/*
*/  87.9,90.0,94.2,97.5,102.0,106.8,106.8,106.8,110.1,113.7)

matrix rmininc = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1959/2013{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
	matrix rmininc[1,`cpi_index']=40*13*0.5*minwg[1,`cpi_index']*`deflate'
}

display "***********************************"
display "************MALE SAMPLE************"
display "***********************************"
drop if male~=1
drop male	
drop if yob==.
drop if ${yrfirst}-yob+1>${retire_age} | ${yrlast}-yob+1<${begin_age}
drop if yod<=${yrfirst} & yod~=.
count

forvalues yr = $yrfirst/$yrlast{
	replace wage1_`yr' = 0 if wage1_`yr'==.
	replace wage2_`yr' = 0 if wage2_`yr'==.
	replace wage3_`yr' = 0 if wage3_`yr'==.
	replace selfinc`yr' = 0 if selfinc`yr'==.

	gen labor`yr' = wage1_`yr'+wage2_`yr'+wage3_`yr' + 2*selfinc`yr'/3
	drop wage1_`yr' wage2_`yr' wage3_`yr' /*selfinc`yr'*/
}
foreach var in labor{
	forvalues yr = $yrfirst/$yrlast{
		gen temp`var'=`var'`yr' if `yr'-yob+1>= ${begin_age} & `yr'- yob+1<= ${retire_age} & `yr'< yod  // yod=. id very big number  
		egen temp=pctile(temp`var'), p(99.999)
		replace `var'`yr'= temp if `var'`yr'>=temp
		drop temp temp`var'

		local cpi_index = `yr'-1959+1
		local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
		replace `var'`yr' = `var'`yr'*`deflate'

		gen temp=uniform()-0.5
		replace `var'`yr'=`var'`yr'+`var'`yr'*temp/5000 
		drop temp

		replace `var'`yr'= . if `yr'-yob+1 < ${begin_age} | `yr'- yob+1>${retire_age}
		replace `var'`yr'= . if `yr'>= yod & yod~=.  // (yod=. is very big number)
	}
}
compress
save "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013_wself", replace

global outfolder=c(current_date)
global outfolder="$outfolder LifeCycleProfile_LABOR"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"

do "$maindirectory${sep}do${sep}bymydiststat.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

global logname="$maindirectory${sep}log${sep}$outfolder${sep}$outfolder.log"
capture noisily log close
capture noisily log using "$logname", replace

global begin=c(current_time)

** Individual Statistics
use  "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013_wself", clear

** Sample selection & lifetime income construction
** 1) Require at least 33 income observations
** 2) Require at least 15 income observations above the threshold
gen yrobs = min(${yrlast}-max(${yrlast}-yob+1-${retire_age},0),yod-1) - ///
			   (${yrfirst}-min(${yrfirst}-yob+1-${begin_age},0)) + 1
drop if yrobs<33
tab yob
gen ${varoi}emp=0
gen LT${varoi}=0
gen lifetime=0
forvalues yr = $yrfirst/$yrlast{
	qui replace ${varoi}emp=${varoi}emp+1 if 	///
		${varoi}`yr'> rmininc[1,`yr'-1959+1] & ${varoi}`yr'~=.
	qui replace LT${varoi}=LT${varoi}+${varoi}`yr' if ${varoi}`yr'~=.
	qui replace lifetime=lifetime+1 if ${varoi}`yr'~=.
}
tab ${varoi}emp
drop if ${varoi}emp<15
tab ${varoi}emp

replace LT${varoi}=LT${varoi}/lifetime
drop yrobs lifetime

gen id=_n
save "$maindirectory${sep}dta${sep}LifeCycleProfileData_LABOR.dta", replace
xtile incrank=LT${varoi}, nq(100)

** Obtain max self employment income in the data
forvalues year=$yrfirst/$yrlast{
	egen maxselfinc`year'=max(selfinc`year')
}
gen tagprint=_n==1
qui outsheet maxselfinc* using maxselfinc.txt if tagprint==1, replace
drop tagprint

qui gen age=.
order id age incrank LTlabor
forvalues age=25/44{
	qui gen iftop_exog=.	// theoretical top coding (from FGuvenen's email)
	qui gen iftop_emp=.		// empirical top coding, based on largest level in the data
	qui replace age=`age'
	forvalues coh=1951/1957{
		local year=`age'+`coh'-1
		if `year'>=	$yrfirst & `year' <=$yrtopcodelast{
			disp as text "Year: " as result `year' as text "  Cohort: " as result `coh'
			disp as text "Max exog selfinc: " as result topinc[1,`year'-1959+1]
			replace iftop_exog=0 if selfinc`year'< topinc[1,`year'-1959+1] & yob==`coh'
			replace iftop_exog=1 if selfinc`year'>=topinc[1,`year'-1959+1] & yob==`coh'
			qui replace iftop_emp=0  if selfinc`year'< maxselfinc`year' & yob==`coh'
			qui replace iftop_emp=1  if selfinc`year'>=maxselfinc`year' & yob==`coh'
		}
	}
	bymydiststat "iftop_exog" "D_" "`age'" "age incrank"
	bymydiststat "iftop_emp" "D_" "`age'" "age incrank"
	drop iftop*
}

global vars "iftop_exog iftop_emp"
forvalues age=25/44{
	drop _all
	foreach v of global vars{
		use D_`v'`age'.dta, clear
		foreach stat in N mean sd skew kurt min max p1 p5 p10 p25 p50 p75 p90 p95 p99{
			rename D_`stat'`v'`age' `stat'`v'
		}
		save D_`v'`age'.dta, replace
	}
}

drop _all
foreach v of global vars{
	drop _all
	set obs 1
	gen tobedropped=1
	forvalues age=25/44{
		append using D_`v'`age'.dta
		erase D_`v'`age'.dta
	}
	drop if tobedropped==1 | age==.
	drop tobedropped
	save D_`v', replace
}

drop _all
use D_iftop_exog
erase D_iftop_exog.dta
merge 1:1 age incrank using D_iftop_emp
drop _merge
erase D_iftop_emp.dta

qui outsheet using fraction_topcoded.txt, replace

drop _all
insheet using maxselfinc.txt
gen id=1
reshape long maxselfinc, i(id) j(year)
qui outsheet using maxselfinc.txt, replace

capture log close
