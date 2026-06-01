clear all
capture log close
set more off
set matsize 500
set linesize 255

** JAE: Please change the below directory. This is the usual working directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata"
** JAE: Please change this to 1 if you run Stata on Unix or Mac
global unix=1

** YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!
if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}

global chi = 0.95
global nq=75

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
matrix topinc = /* Max. taxable earnings each year 1959-2013
*/ ${chi}*1000*(4.8,4.8,4.8,4.8,4.8,4.8,4.8,6.6,6.6,7.8,7.8,7.8,7.8,9.0,10.8,/*
*/  13.2,14.1,15.3,16.5,17.7,22.9,25.9,29.7,32.4,35.7,37.8,39.6,42.0,43.8,/*
*/  45.0,48.0,51.3,53.4,55.5,57.6,60.6,61.2,62.7,65.4,68.4,72.6,76.2,80.4,/*
*/  84.9,87.0,87.9,90.0,94.2,97.5,102.0,106.8,106.8,106.8,110.1,113.7)
matrix rmininc = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1959/2013{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
	matrix rmininc[1,`cpi_index']=40*13*0.5*minwg[1,`cpi_index']*`deflate'
	matrix topinc[1,`cpi_index']=topinc[1,`cpi_index']*`deflate'
}

global outfolder=c(current_date)
global outfolder="$outfolder LTIncProfile_LABOR_ROBUST"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"

do "$maindirectory${sep}do${sep}bymydiststat2.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

global yrfirst = 1981 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global yrtopcodelast=1993
global yruncappedfirst=1994
global begin_age  = 25
global retire_age = 60
global varoi="labor" 		// Income list that we analyze

global logname="$maindirectory${sep}out${sep}$outfolder${sep}$outfolder.log"
capture noisily log close
capture noisily log using "$logname", replace


** Permanent types
u "$maindirectory${sep}dta${sep}cleaned_MALE_10p_WAGE_SELFINC2013_2260", clear

** Sample selection & lifetime income construction
** 1) Require at least 33 income observations
** 2) Require at least 15 income observations above the threshold
gen yrobs = min(${yrlast}-max(${yrlast}-yob+1-${retire_age},0),yod-1) - ///
			   (${yrfirst}-min(${yrfirst}-yob+1-${begin_age},0)) + 1
drop if yrobs<33

gen dropind=1
forvalues yr=1981/1990{
	replace dropind=0 if wage`yr'>rmininc[1,`yr'-1959+1] | selfinc`yr'>rmininc[1,`yr'-1959+1]
}
drop if dropind==1

replace dropind=1
forvalues yr=1991/2000{
	replace dropind=0 if wage`yr'>rmininc[1,`yr'-1959+1] | selfinc`yr'>rmininc[1,`yr'-1959+1]
}
drop if dropind==1

replace dropind=1
forvalues yr=2001/2013{
	replace dropind=0 if wage`yr'>rmininc[1,`yr'-1959+1] | selfinc`yr'>rmininc[1,`yr'-1959+1]
}
drop if dropind==1
drop dropind

tab yob
gen ${varoi}emp=0
gen LT${varoi}=0
gen lifetime=0
xtile nquant= runiform(), n($nq)

forvalues yr=1978/1980{
	gen topcoded`yr'=(selfinc`yr'>=topinc[1,`yr'-1959+1])
	gen zeroselfinc`yr'=(selfinc`yr'<rmininc[1,`yr'-1959+1])
	gen lnselfinc`yr'=(1-zeroselfinc`yr')*ln(max(selfinc`yr',0.5*rmininc[1,`yr'-1959+1]))
	gen lntopcodedself`yr'=min(lnselfinc`yr',ln(topinc[1,`yr'-1959+1]))
	gen zerowage`yr'=(wage`yr'<rmininc[1,`yr'-1959+1])
	gen lnwage`yr'=(1-zerowage`yr')*ln(max(wage`yr',0.5*rmininc[1,`yr'-1959+1]))
}

forvalues yr = $yrfirst/$yrtopcodelast{
	gen topcoded`yr'=(selfinc`yr'>=topinc[1,`yr'-1959+1])
	gen zeroselfinc`yr'=(selfinc`yr'<rmininc[1,`yr'-1959+1])
	gen lnselfinc`yr'=(1-zeroselfinc`yr')*ln(max(selfinc`yr',0.5*rmininc[1,`yr'-1959+1]))
	gen lntopcodedself`yr'=min(lnselfinc`yr',ln(topinc[1,`yr'-1959+1]))
	gen zerowage`yr'=(wage`yr'<rmininc[1,`yr'-1959+1])
	gen lnwage`yr'=(1-zerowage`yr')*ln(max(wage`yr',0.5*rmininc[1,`yr'-1959+1]))
	
	gen tempage=`yr'-yob+1
	gen age = .
	local bin=1
	forvalues h = $begin_age(5)$retire_age{
		replace age = `bin' if tempage>=`h' & tempage<min(`h'+5,$retire_age)	
		local bin=`bin' +1
	}
	replace age = 7  if tempage==$retire_age
	drop tempage
	merge m:1 age nquant using "$maindirectory${sep}dta${sep}impt_coeffs_qln"
	
	local L1=`yr'-1
	local L2=`yr'-2
	local L3=`yr'-3

	gen imputedselfinc`yr' = 0	
replace imputedselfinc`yr' =  _b_cons + _b_zerowage1993*zerowage`L3' +  _b_zerowage1994*zerowage`L2' ///
+ _b_zerowage1995*zerowage`L1' + _b_zerowage1996*zerowage`yr' + _b_lnwage1993*lnwage`L3'  ///
+ _b_lnwage1994*lnwage`L2' + _b_lnwage1995*lnwage`L1' + _b_lnwage1996*lnwage`yr' ///
+ _b_topcoded1993*topcoded`L3' + _b_topcoded1994*topcoded`L2' + _b_topcoded1995*topcoded`L1' ///
+ _b_zeroselfinc1993*zeroselfinc`L3' + _b_zeroselfinc1994*zeroselfinc`L2'  ///
+ _b_zeroselfinc1995*zeroselfinc`L1' + _b_lntopcodedself1993*lntopcodedself`L3' /// 
+ _b_lntopcodedself1994*lntopcodedself`L2' + _b_lntopcodedself1995*lntopcodedself`L1' ///
	if selfinc`yr'>topinc[1,`yr'-1959+1]
	replace imputedselfinc`yr'=max(selfinc`yr', ///
				exp(imputedselfinc`yr')*topinc[1,`yr'-1959+1]/topinc[1,1996-1959+1])
	
	drop topcoded`L3' zeroselfinc`L3' lnselfinc`L3' lntopcodedself`L3' zerowage`L3' lnwage`L3'
	drop age _b_* _merge
	drop if yob==.
	
	gen ${varoi}`yr'=wage`yr'+2*imputedselfinc`yr'/3
	qui replace ${varoi}emp=${varoi}emp+1 if 	///
		${varoi}`yr'> rmininc[1,`yr'-1959+1] & ${varoi}`yr'~=.
	qui replace LT${varoi}=LT${varoi}+${varoi}`yr' if ${varoi}`yr'~=.
	qui replace lifetime=lifetime+1 if ${varoi}`yr'~=.
}
forvalues L3 = 1991/$yrtopcodelast{
	drop topcoded`L3' zeroselfinc`L3' lnselfinc`L3' lntopcodedself`L3' zerowage`L3' lnwage`L3'
}
forvalues yr = $yruncappedfirst/$yrlast{
	gen ${varoi}`yr'=wage`yr'+2*selfinc`yr'/3
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
save "$maindirectory${sep}dta${sep}LTIncData_LABOR_IMPT_PM.dta", replace
xtile incrank=LT${varoi}, nq(100)

qui gen age=.
order id age incrank LTlabor
forvalues age=25/60{
	qui gen temp${varoi}=.
	qui replace age=`age'
	forvalues coh=1954/1957{
		local year=`age'+`coh'-1
		if `year'>=	$yrfirst & `year' <=$yrlast{
			qui replace temp${varoi}=${varoi}`year' if yob==`coh'
		}
	}
	bymydiststat "temp${varoi}" "D_" "`age'" "age incrank"
	drop temp${varoi}
}

forvalues age=25/60{
	drop _all 
	use D_temp${varoi}`age'.dta
	foreach stat in N mean sd skew kurt min max p1 p5 p10 p25 p50 p75 p90 p95 p99{
		rename D_`stat'temp${varoi}`age' `stat'${varoi}
	}
	save D_temp${varoi}`age'.dta, replace
}
drop _all
set obs 1
gen tobedropped=1
forvalues age=25/60{
	append using D_temp${varoi}`age'.dta
	erase D_temp${varoi}`age'.dta
}
drop if tobedropped==1 | age==.
drop tobedropped
qui outsheet using LTInc_Profile_LABOR_IMPT_PM.txt, replace

capture log close
