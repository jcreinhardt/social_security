clear all
capture log close
set more off
set matsize 500
set linesize 255

** Jae: You should change the below directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata"
global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac

** YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!

if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}
global yrfirst = 1994 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global begin_age  = 25 
global retire_age = 60
global numq = 100			// Number of quintiles
global varoi="labor"

global outfolder=c(current_date)
global outfolder="$outfolder YRCHANGE_LABOR_NYR"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
capture noisily mkdir "$maindirectory${sep}dta${sep}RE_data_labor"
cd "$maindirectory${sep}out${sep}$outfolder"

capture noisily log close
capture noisily log using "$maindirectory${sep}log${sep}$outfolder.log", replace

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

matrix agedumlabor = ///
(14684.66, 16470.99, 18153.65, 19725.39, 21155.31, 22480.42, 23731.53, 24906.15, 26018.16, ///
 27033.44, 28021.29, 28896.04, 29745.70, 30562.53, 31287.69, 31915.91, 32641.18, 33263.63, ///
 33806.89, 34273.58, 34757.48, 35178.49, 35638.08, 36025.42, 36439.55, 36740.32, 37034.68, ///
 37170.10, 37321.69, 37353.06, 37295.95, 37027.27, 36245.12, 35758.03, 35102.58, 34318.51)

global begin=c(current_time)

global YRCHANGE_NYR="$maindirectory${sep}do${sep}YRCHANGE_LABOR_NYR.do"
global YRCHANGE_NYR_v2="$maindirectory${sep}do${sep}YRCHANGE_LABOR_NYR_v2.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"
do "$maindirectory${sep}do${sep}bymysum.do"
do "$maindirectory${sep}do${sep}bymypctile1.do"

****************************************************************************
**	Cross-Sectional Moments
****************************************************************************
local yearfirst = ${yrfirst}+3
local yearlast  = ${yrlast}-1
forvalues nn = 2/3{
	global NL=`nn'
	capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR"
	cd "$maindirectory${sep}out${sep}$outfolder"
	local yearfirst=${yrfirst}+3
	local yearlast=${yrlast}-(2*${NL}+1)
	forvalues eayr = `yearfirst'/`yearlast'{
		if(`eayr'<$yrfirst+5){
			global minobspr = max(1,`eayr'-$yrfirst-2) 	// Minimum number of observations  to construct average past income 
			global yrbpr = ${yrfirst}					// Starting year to construct average past income
			global yrepr = `eayr'-1						// Ending year to construct average past income
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
			global yr5L  = min($yrlast,`eayr'+5)		// Beginning year of the third N-year period
		}
		else{
			global minobspr = 3 						// Minimum number of observations  to construct average past income 
			global yrbpr = `eayr'-5						// Starting year to construct average past income
			global yrepr = `eayr'-1						// Ending year to construct average past income
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
			global yr5L  = min($yrlast,`eayr'+5)		// Beginning year of the third N-year period
		}
		do "$YRCHANGE_NYR_v2"	
	}
}
global part1=c(current_time)
mac list begin part1

cd "$maindirectory${sep}out${sep}$outfolder"
local yearfirst = ${yrfirst}+3
local yearlast  = ${yrlast}-1
forvalues eayr = `yearfirst'/`yearlast'{
	global minobspr = 3 					// Minimum number of observations  pre-recession 
	global yrbpr = max(${yrfirst},`eayr'-5)	// Starting year to construct average income pre-period
	global yrepr = `eayr'-1					// Ending year to construct average income pre-period
	global yrbr  = `eayr'
	global yrer  = min($yrlast,`eayr'+1)
	global yr2L  = min($yrlast,`eayr'+2)
	global yr4L  = min($yrlast,`eayr'+4)
	global yr5L  = min($yrlast,`eayr'+5)
	if ($yr4L<=$yrlast){
		do "$YRCHANGE_NYR"
	}
}
global part2=c(current_time)
mac list begin part1 part2

** Now compile the results
drop _all
local yearfirst = ${yrfirst}+3
local yearlast  = ${yrlast}-1
forvalues nn = 2/3{
	global NL=`nn'
	local yearfirst=${yrfirst}+3
	local yearlast=${yrlast}-(2*${NL}+1)
	forvalues eayr = `yearfirst'/`yearlast'{
		if(`eayr'<$yrfirst+5){
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
		}
		else{
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
		}
		cd "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR${sep}YRCHANGE_${NL}YR_$yrbr$yr1L"
		append using avgch_${NL}_${yrbr}
		erase avgch_${NL}_${yrbr}.dta
	}
	cd "$maindirectory${sep}out${sep}$outfolder"
	save avgch_${NL}_NYR, replace
}

drop _all
local yearfirst=${yrfirst}+3
local yearlast=${yrlast}-1
forvalues eayr = `yearfirst'/`yearlast'{
	global yrbr = `eayr'
	global yrer = min($yrlast,`eayr'+1)
	global yr4L  = min($yrlast,`eayr'+4)
	if ($yr4L<=$yrlast){
		cd "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE$yrbr$yrer"
		append using avgch_${yrbr}
		erase avgch_${yrbr}.dta
	}
}
cd "$maindirectory${sep}out${sep}$outfolder${sep}"
save avgch_NYR, replace

* Clean up: Remove temporary directories
drop _all
forvalues nn = 2/3{
	global NL=`nn'
	local yearfirst=${yrfirst}+3
	local yearlast=${yrlast}-(2*${NL}+1)
	forvalues eayr = `yearfirst'/`yearlast'{
		if(`eayr'<$yrfirst+5){
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
		}
		else{
			global yrbr  = `eayr'						// Beginning year of the first N-year period
			global yr1L  = min($yrlast,`eayr'+${NL}+1)	// Beginning year of the second N-year period
		}
		rmdir "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR${sep}YRCHANGE_${NL}YR_$yrbr$yr1L"
	}
	rmdir "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE_${NL}YR"
}

local yearfirst=$yrfirst+3
local yearlast=$yrlast-1
forvalues eayr = `yearfirst'/`yearlast'{
	global yrbr = `eayr'
	global yrer = min($yrlast,`eayr'+1)
	global yr4L  = min($yrlast,`eayr'+4)
	if ($yr4L<=$yrlast){
		rmdir "$maindirectory${sep}out${sep}$outfolder${sep}YRCHANGE$yrbr$yrer"
	}
}

** Now aggregate over time
use avgch_NYR, clear
collapse (mean) p1resavgF1-maxresavgF5, by(agebin pastincpct)
outsheet using avgch_NYR.txt, replace
erase avgch_NYR.dta

forvalues nn=2/3{
	global NL=`nn'
	use avgch_${NL}_NYR, clear
	collapse (mean) p1-max, by(agebin pastincpct)
	outsheet using avgch_${NL}_NYR.txt, replace
	erase avgch_${NL}_NYR.dta
}

global part3=c(current_time)
mac list begin part1 part2 part3
capture noisily log close
