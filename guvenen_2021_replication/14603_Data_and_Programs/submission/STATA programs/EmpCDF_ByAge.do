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
global outfolder=c(current_date)
global outfolder="$outfolder EmpShr_byAge"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"

do "$maindirectory${sep}do${sep}bymysum.do"
do "$maindirectory${sep}do${sep}bymysumf.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

global logname="$maindirectory${sep}out${sep}$outfolder${sep}EmpCDF_byAge.log"
capture noisily log close
capture noisily log using "$logname", replace
log off						// start recording in the middle, only when relevant

global yrfirst = 1978 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global yrtopcodelast=1993
global begin_age  = 25
global retire_age = 60
global varoi    = "labor" 	// Income list that we analyze
global varoi2   = "totinc" 	// Also do everything by total income (including DI)
global statlist = "mean sd skew kurt kurt2 min max p10 p50 p90"

global begin=c(current_time)

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

matrix rmininc  = J(rowsof(minwg),colsof(minwg), 0.0)
matrix rmininc1 = J(rowsof(minwg),colsof(minwg), 0.0)
matrix rmininc2 = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1959/2013{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
	matrix rmininc1[1,`cpi_index'] = 40*13*0.5*minwg[1,`cpi_index']*`deflate'
	matrix rmininc2[1,`cpi_index'] = 12000		// alternative min. income
}


foreach i in 55 60{
foreach j in 1 2{
	gl retire_age = `i'
	if $retire_age==60{
		global minobs = 33
	}
	else{
		global minobs = $retire_age-$begin_age+1
	}

	* minimum income
	matrix rmininc = rmininc`j'

	** Individual Statistics
	use  "$maindirectory${sep}dta${sep}MALE_LABORwDIBwTOTINC2013", clear

	** Sample selection & lifetime income construction
	** 1) Require at least 33 income observations
	** 2) Require at least 15 income observations above the threshold
	gen yrobs = min(${yrlast}-max(${yrlast}-yob+1-${retire_age},0),yod-1) - ///
				(${yrfirst}-min(${yrfirst}-yob+1-${begin_age},0)) + 1
	drop if yrobs<$minobs

	gen ${varoi}emp=0		// #yrs worked (earnings)
	gen ${varoi2}emp=0		// #yrs worked (with DI)
	gen LT${varoi}=0		// lifetime earnings
	gen LT${varoi2}=0		// lifetime earnings with total income
	gen lifetime=0			// length of lifetime (total yrs in the sample)
	global varl "${varoi} ${varoi2}"
	forvalues yr = $yrfirst/$yrlast{
		qui replace lifetime=lifetime+1 if ${varoi}`yr'~=.
		foreach var of global varl{
			qui replace `var'emp = `var'emp + 1 if 	///
				`var'`yr'>rmininc[1,`yr'-1959+1] & `var'`yr'~=.
			qui replace LT`var' = LT`var' + `var'`yr' if `var'`yr'~=.
		}
	}

	foreach var of global varl{
		gen emprat`var' = `var'emp/lifetime			// fraction of yrs worked
		gen int_emprat`var'=round((${retire_age}-${begin_age}+1)*emprat`var')	// yrs worked with completed spells assuming same working probability in the remaining years
	}
	log on
	tab yob

	foreach var of global varl{
		tab `var'emp
		tab emprat`var'
		tab int_emprat`var'
	}
	log off

	qui gen age=.
	gen emp=.

	forvalues age=$begin_age/$retire_age{
		qui replace age=`age'
		foreach var of global varl{
			replace emp=.
			forvalues coh=1951/1957{
				local year=`age'+`coh'-1
				** Dummy for being employed in the year where the cohort has age=`age'
				if `year'>=	$yrfirst & `year' <=$yrlast{
					qui replace emp=0 if yob==`coh'
					qui replace emp=1 if yob==`coh' & ///
						`var'`year'> rmininc[1,`year'-1959+1] & ${varoi}`year'~=.
				}
			}
			* by age and years worked, fraction of people that work
			bymysumf "emp" "D_" "`age'_`var'" "age int_emprat`var'"
		}
	}

	forvalues age=$begin_age/$retire_age{
		foreach var of global varl{
			drop _all
			use D_emp`age'_`var'.dta
			foreach stat in N mean p50 sd p1 p99{
				rename D_`stat'emp`age'_`var' `stat'_emp_`var'
			}
			drop p50* sd* p1* p99*
			save D_emp`age'_`var'.dta, replace
		}
	}

	foreach var of global varl{
		drop _all
		set obs 1
		gen tobedropped=1
		forvalues age=$begin_age/$retire_age{
			append using D_emp`age'_`var'.dta
			erase D_emp`age'_`var'.dta
		}
		drop if tobedropped==1 | age==.
		drop tobedropped
		sort age int_emprat
		outsheet using Emp_byAge_`var'_ret_${retire_age}_mininc`j'.txt, replace
	}

}
}
capture noisily log close
