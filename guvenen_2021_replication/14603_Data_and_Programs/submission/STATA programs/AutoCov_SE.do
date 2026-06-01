clear all
capture log close
set more off
set matsize 500
set linesize 255

** Jae: You should change the below directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata/"
global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac

** YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!

if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}
global outfolder=c(current_date)
global outfolder="$outfolder AutoCov_SE"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"

do "$maindirectory${sep}do${sep}/autocov_wide.do"

global logname="$maindirectory${sep}log${sep}$outfolder${sep}$outfolder.log"
capture noisily log close
capture noisily log using "$logname", replace

global nboot=10
global yrfirst = 1978 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global begin_age  = 25
global retire_age = 60
global varoi="labor" 		// Income list that we analyze
global statlist="mean sd skew kurt kurt2 min max p10 p50 p90"

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

matrix rmininc = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1959/2013{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
	matrix rmininc[1,`cpi_index']=40*13*0.5*minwg[1,`cpi_index']*`deflate'
}

use  "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013", clear
set seed 841117
sample 10

save  "$maindirectory${sep}dta${sep}cleaned_MALE_1p_LABOR2013", replace

** Individual Statistics
forvalues r=1/$nboot{
	use  "$maindirectory${sep}dta${sep}cleaned_MALE_1p_LABOR2013", clear
	set seed `r'
	bsample
	keep yob ${varoi}*
	
	forvalues h=$begin_age/$retire_age{
		qui gen ${varoi}`h'=.
		forvalues yr=$yrfirst/$yrlast{
			qui replace ${varoi}`h'=${varoi}`yr' if `yr'-yob+1==`h'
		}
	}
	drop ${varoi}197* ${varoi}198* ${varoi}199* ${varoi}200* ${varoi}201*
	
	qui gen emp=0
	forvalues h=$begin_age/$retire_age{
		qui replace emp=emp+1 if ${varoi}`h'>=rmininc[1,`h'+yob-1959]
		qui replace ${varoi}`h'=. if ${varoi}`h'<rmininc[1,`h'+yob-1959]
	}

	//	tab emp
	drop if emp<15

	forvalues h=$begin_age/$retire_age{
		qui replace ${varoi}`h'=log(${varoi}`h')
		forvalues yr=$yrfirst/$yrlast{
			qui sum ${varoi}`h' if `h'+yob-1==`yr', meanonly
			qui replace ${varoi}`h'=${varoi}`h'-r(mean) if `h'+yob-1==`yr'
		}
	}
	
	autocov_wide "${varoi}" $begin_age $retire_age
	
	local lstage=$retire_age-1
	forvalues h=$begin_age/`lstage'{
		local hnext=`h'+1
		qui gen L1${varoi}`h'=${varoi}`hnext'-${varoi}`h'
		drop ${varoi}`h'
	}
	autocov_wide "L1${varoi}" $begin_age `lstage'
	
	u autocovmat_${varoi}_${begin_age}_${retire_age}, clear
	gen run=`r'
	gen age=${begin_age}+_n-1
	order run age, first
	save autocovmat_${varoi}_run`r', replace
	erase autocovmat_${varoi}_${begin_age}_${retire_age}.dta
	erase autocovmat_${varoi}_${begin_age}_${retire_age}.txt
	
	u autocovmat_L1${varoi}_${begin_age}_`lstage', clear
	gen run=`r'
	gen age=${begin_age}+_n-1
	order run age, first
	save autocovmat_L1${varoi}_run`r', replace
	erase autocovmat_L1${varoi}_${begin_age}_`lstage'.txt
	erase autocovmat_L1${varoi}_${begin_age}_`lstage'.dta	
}

drop _all
set obs 1
gen tobedropped=1
forvalues r=1/$nboot{
	append using autocovmat_${varoi}_run`r'.dta
	erase autocovmat_${varoi}_run`r'.dta
}
drop if tobedropped==1 
drop tobedropped
save "$maindirectory${sep}dta${sep}autocovmat_${varoi}", replace

local totage=$retire_age-$begin_age+1
forvalues h=1/`totage'{
	bys age: egen avg_n`h'=mean(n`h')
	bys age: egen se_n`h'=sd(n`h')
	replace se_n`h'=se_n`h'/sqrt(${nboot})	
}
keep age avg_n* se_n* 
egen printtag=tag(age)
outsheet age avg_n* se_n*  using autocovmat_${varoi}.txt if printtag==1, replace


drop _all
set obs 1
gen tobedropped=1
forvalues r=1/$nboot{
	append using autocovmat_L1${varoi}_run`r'.dta
	erase autocovmat_L1${varoi}_run`r'.dta
}
drop if tobedropped==1 
drop tobedropped
save "$maindirectory${sep}dta${sep}autocovmat_L1${varoi}", replace

local totage=$retire_age-$begin_age
forvalues h=1/`totage'{
	bys age: egen avg_n`h'=mean(n`h')
	bys age: egen se_n`h'=sd(n`h')
	replace se_n`h'=se_n`h'/sqrt(${nboot})	
}
keep age avg_n* se_n* 
egen printtag=tag(age)
outsheet age avg_n* se_n*  using autocovmat_L1${varoi}.txt if printtag==1, replace

capture log close
