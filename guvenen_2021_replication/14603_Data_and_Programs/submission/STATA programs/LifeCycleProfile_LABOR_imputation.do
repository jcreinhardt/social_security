clear all
capture log close
set more off
set matsize 500
set linesize 255

** JAE: Please change the below directory. This is the usual working directory. 
//global maindirectory ="C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\STATA"
global maindirectory ="/Users/serdar/Dropbox/ssa-income-risk/STATA"
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
global outfolder=c(current_date)
global outfolder="$outfolder Impute_Selfinc"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"
do "$maindirectory${sep}do${sep}bymydiststat.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

global logname="$maindirectory${sep}out${sep}$outfolder${sep}$outfolder.log"
capture noisily log close
capture noisily log using "$logname", replace

global yrfirst = 1978 		// First year in the dataset
global yrlast  = 2013 		// Last year in the dataset
global agefirst   = 22
global retire_age = 60
global chi = 0.95

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
}
global begin=c(current_time)

** Recreate the 10% sample that includes ages 23 and 24 (needed for imputation)
use "${datafile10percent}"
keep wage* yob yod male selfinc*
destring, replace force

display "***********************************"
display "MALE Sample"
display "***********************************"
drop if male~=1
	
drop male	
drop if yob==.
drop if ${yrfirst}-yob+1>${retire_age} | ${yrlast}-yob+1<${agefirst}
drop if yod<=${yrfirst} & yod~=.
count

forvalues yr = $yrfirst/$yrlast{
	replace wage1_`yr' = 0 if wage1_`yr'==.
	replace wage2_`yr' = 0 if wage2_`yr'==.
	replace wage3_`yr' = 0 if wage3_`yr'==.
	replace selfinc`yr' = 0 if selfinc`yr'==.

	gen wage`yr' = wage1_`yr'+wage2_`yr'+wage3_`yr'
	replace wage`yr' = 0 if wage`yr'==.
	drop wage1_`yr' wage2_`yr' wage3_`yr'
}
foreach var in wage selfinc{ 
	forvalues yr = $yrfirst/$yrlast{
		gen temp`var'=`var'`yr' if `yr'-yob+1>= ${agefirst} & `yr'- yob+1<= ${retire_age} & `yr'< yod  // yod=. id very big number  
		egen temp=pctile(temp`var'), p(99.999)
		replace `var'`yr'= temp if `var'`yr'>=temp
		drop temp temp`var'

		local cpi_index = `yr'-1959+1
		local deflate = cpimat[1,${base_price}]/cpimat[1,`cpi_index']
		replace `var'`yr' = `var'`yr'*`deflate'

		gen temp=uniform()-0.5
		replace `var'`yr'=`var'`yr'+`var'`yr'*temp/5000 
		drop temp

		replace `var'`yr'= . if `yr'-yob+1 < ${agefirst} | `yr'- yob+1>${retire_age}
		replace `var'`yr'= . if `yr'>= yod & yod~=.  // (yod=. is very big number)
	}
}
compress
save "$maindirectory${sep}dta${sep}cleaned_MALE_10p_WAGE_SELFINC2013_2260", replace
