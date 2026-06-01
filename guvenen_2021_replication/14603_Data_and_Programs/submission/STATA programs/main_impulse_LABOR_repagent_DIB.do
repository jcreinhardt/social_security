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

global varoi="labor" 		// Income list that we analyze

global JMPpercentiles= "1 5 10 25 50 75 90 95 99"
global AGGpercentiles= "p1 p5 p10 p25 p50 p75 p90 p95 p99"

global outfolder=c(current_date)
global outfolder="$outfolder ImpulseResponse_labor_repagent_DIB"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
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

global impulse="$maindirectory${sep}do${sep}impulse_LABOR_repagent_DIB.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"

** 1) Compute income changes at various horizons to be later used for impulse response functions
cd "$maindirectory${sep}out${sep}$outfolder"
local yearfirst=$yrfirst+3
local yearlast=$yrlast-10
forvalues eayr = `yearfirst'/`yearlast'{
	disp("Year `eayr'")
	if(`eayr'<${yrfirst}+5){
		global minobspr = max(1,`eayr'-${yrfirst}-2)
	}
	else{
		global minobspr = 3
	}
	global yrbpr = max(${yrfirst},`eayr'-5)			// First year for avg. past income (t-5)
	global yrepr = `eayr'-1							// Last year for avg. past income (t-1)
	global yrbr  = `eayr'							// Benchmark year for computing impulse (t)
	global yr1L  = min(${yrlast},`eayr'+1)			// Period to construct response (t+1)
	global yr2L  = min(${yrlast},`eayr'+2)			// t+2
	global yr3L  = min(${yrlast},`eayr'+3)			// t+3
	global yr5L  = min(${yrlast},`eayr'+5)			// t+5
	global yr10L = min(${yrlast},`eayr'+10)			// t+10
	do "$impulse"
}

global part1=c(current_time)
mac list begin part1

** 2) Append income changes for various years into one file
local yearfirst=$yrfirst+3
local yearlast=$yrlast-10
global YRBIN="YR`yearfirst'`yearlast'"
cd "$maindirectory${sep}out${sep}$outfolder"	
use tempdata`yearfirst'.dta, clear	
qui erase tempdata`yearfirst'.dta
local yearfirst1=`yearfirst'+1
forvalues eayr = `yearfirst1'/`yearlast'{
	append using tempdata`eayr'
	qui erase tempdata`eayr'.dta
}

** 2) Percentile groups for income changes (labor and total income separately)
global numq = 20
gen res${varoi}chL1rank=.
qui bys agebin avgres${varoi}rank: bymyxtile res${varoi}chL1 res${varoi}chL1rank
/*gen restotincchL1rank=.
qui bys agebin avgrestotincrank: bymyxtile restotincchL1 restotincchL1rank*/

** 1) Labor income
** Generate earnings level for the representative agent at time t-1,t,t+1,t+2,t+3,t+5, and t+10
bys agebin avgres${varoi}rank res${varoi}chL1rank: egen avgres${varoi}L1 = mean(res${varoi}L1)
by  agebin avgres${varoi}rank res${varoi}chL1rank: egen avgres${varoi}t  = mean(res${varoi}t)
foreach lag in 1 2 3 5 10{
	by agebin avgres${varoi}rank res${varoi}chL1rank: egen avgres${varoi}F`lag' = mean(res${varoi}F`lag')
}

** Generate income changes for the representative agent
gen avgres${varoi}chL1=log(avgres${varoi}t)-log(avgres${varoi}L1)
foreach lag in 1 2 3 5 10{
	gen avgres${varoi}chF`lag'=log(avgres${varoi}F`lag')-log(avgres${varoi}t)
}

** 1) Total income
** Generate earnings level for the representative agent at time t-1,t,t+1,t+2,t+3,t+5, and t+10
bys agebin avgres${varoi}rank res${varoi}chL1rank: egen avgrestotincL1 = mean(restotincL1)
by  agebin avgres${varoi}rank res${varoi}chL1rank: egen avgrestotinct  = mean(restotinct)
foreach lag in 1 2 3 5 10{
	by agebin avgres${varoi}rank res${varoi}chL1rank: egen avgrestotincF`lag' = mean(restotincF`lag')
}

** Generate income changes for the representative agent
gen avgrestotincchL1=log(avgrestotinct)-log(avgrestotincL1)
foreach lag in 1 2 3 5 10{
	gen avgrestotincchF`lag'=log(avgrestotincF`lag')-log(avgrestotinct)
}

** Output
egen printtag = tag(agebin avgres${varoi}rank res${varoi}chL1rank)
outsheet agebin avgres${varoi}rank res${varoi}chL1rank avgres${varoi}chL1 		///
	avgres${varoi}chF1 avgres${varoi}chF2 avgres${varoi}chF3 avgres${varoi}chF5 ///
	avgres${varoi}chF10 avgrestotincchL1 ///
	avgrestotincchF1 avgrestotincchF2 avgrestotincchF3 avgrestotincchF5	///
	avgrestotincchF10	///
	using impulse_repagent.txt if printtag==1, replace
drop printtag

global part2=c(current_time)
mac list begin part1 part2
capture noisily log close
