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
global outfolder="$outfolder ImpulseResponse_labor_estimation"
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

global impulse="$maindirectory${sep}do${sep}impulse_LABOR_estimation.do"
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

** 2) Compute impulse: Average change btw t-1 and t for each percentile
global numq = 100

** 2.1) First for the mean-normalization
gen resA${varoi}chL1_mean_mod=resA${varoi}chL1_mean
replace resA${varoi}chL1_mean_mod=. if resA${varoi}chL1_mean<=-1.99
gen resA${varoi}chL1rank_mean=.
gen temprank_mean=.
qui bys agebin avgres${varoi}rank: bymyxtile resA${varoi}chL1_mean_mod temprank_mean
replace resA${varoi}chL1rank_mean=1  if resA${varoi}chL1_mean<=-1.99
replace resA${varoi}chL1rank_mean=2  if inrange(temprank_mean,1,2)
replace resA${varoi}chL1rank_mean=3  if inrange(temprank_mean,3,5)
replace resA${varoi}chL1rank_mean=4  if inrange(temprank_mean,6,10)
replace resA${varoi}chL1rank_mean=5  if inrange(temprank_mean,11,15)
replace resA${varoi}chL1rank_mean=6  if inrange(temprank_mean,16,20)
replace resA${varoi}chL1rank_mean=7  if inrange(temprank_mean,21,25)
replace resA${varoi}chL1rank_mean=8  if inrange(temprank_mean,26,30)
replace resA${varoi}chL1rank_mean=9  if inrange(temprank_mean,31,35)
replace resA${varoi}chL1rank_mean=10 if inrange(temprank_mean,36,40)
replace resA${varoi}chL1rank_mean=11 if inrange(temprank_mean,41,45)
replace resA${varoi}chL1rank_mean=12 if inrange(temprank_mean,46,50)
replace resA${varoi}chL1rank_mean=13 if inrange(temprank_mean,51,55)
replace resA${varoi}chL1rank_mean=14 if inrange(temprank_mean,56,60)
replace resA${varoi}chL1rank_mean=15 if inrange(temprank_mean,61,65)
replace resA${varoi}chL1rank_mean=16 if inrange(temprank_mean,66,70)
replace resA${varoi}chL1rank_mean=17 if inrange(temprank_mean,71,75)
replace resA${varoi}chL1rank_mean=18 if inrange(temprank_mean,76,80)
replace resA${varoi}chL1rank_mean=19 if inrange(temprank_mean,81,85)
replace resA${varoi}chL1rank_mean=20 if inrange(temprank_mean,86,90)
replace resA${varoi}chL1rank_mean=21 if inrange(temprank_mean,91,95)
replace resA${varoi}chL1rank_mean=22 if inrange(temprank_mean,96,98)
replace resA${varoi}chL1rank_mean=23 if inrange(temprank_mean,99,100)
drop temprank_mean resA${varoi}chL1_mean_mod
bys agebin avgres${varoi}rank resA${varoi}chL1rank_mean: ///
	egen avgresA${varoi}chL1_mean = mean(resA${varoi}chL1_mean)
bys agebin avgres${varoi}rank resA${varoi}chL1rank_mean: ///
	egen minresA${varoi}chL1_mean = min(resA${varoi}chL1_mean)
bys agebin avgres${varoi}rank resA${varoi}chL1rank_mean: ///
	egen maxresA${varoi}chL1_mean = max(resA${varoi}chL1_mean)

** 2.2) Now for the median-normalization
gen resA${varoi}chL1_med_mod=resA${varoi}chL1_med
replace resA${varoi}chL1_med_mod=.  if resA${varoi}chL1_med<=-1.99
gen resA${varoi}chL1rank_med=.
gen temprank_med=.
qui bys agebin avgres${varoi}rank: bymyxtile resA${varoi}chL1_med_mod temprank_med
replace resA${varoi}chL1rank_med=1  if resA${varoi}chL1_med<=-1.99
replace resA${varoi}chL1rank_med=2  if inrange(temprank_med,1,2)
replace resA${varoi}chL1rank_med=3  if inrange(temprank_med,3,5)
replace resA${varoi}chL1rank_med=4  if inrange(temprank_med,6,10)
replace resA${varoi}chL1rank_med=5  if inrange(temprank_med,11,15)
replace resA${varoi}chL1rank_med=6  if inrange(temprank_med,16,20)
replace resA${varoi}chL1rank_med=7  if inrange(temprank_med,21,25)
replace resA${varoi}chL1rank_med=8  if inrange(temprank_med,26,30)
replace resA${varoi}chL1rank_med=9  if inrange(temprank_med,31,35)
replace resA${varoi}chL1rank_med=10 if inrange(temprank_med,36,40)
replace resA${varoi}chL1rank_med=11 if inrange(temprank_med,41,45)
replace resA${varoi}chL1rank_med=12 if inrange(temprank_med,46,50)
replace resA${varoi}chL1rank_med=13 if inrange(temprank_med,51,55)
replace resA${varoi}chL1rank_med=14 if inrange(temprank_med,56,60)
replace resA${varoi}chL1rank_med=15 if inrange(temprank_med,61,65)
replace resA${varoi}chL1rank_med=16 if inrange(temprank_med,66,70)
replace resA${varoi}chL1rank_med=17 if inrange(temprank_med,71,75)
replace resA${varoi}chL1rank_med=18 if inrange(temprank_med,76,80)
replace resA${varoi}chL1rank_med=19 if inrange(temprank_med,81,85)
replace resA${varoi}chL1rank_med=20 if inrange(temprank_med,86,90)
replace resA${varoi}chL1rank_med=21 if inrange(temprank_med,91,95)
replace resA${varoi}chL1rank_med=22 if inrange(temprank_med,96,98)
replace resA${varoi}chL1rank_med=23 if inrange(temprank_med,99,100)
drop temprank_med resA${varoi}chL1_med_mod
bys agebin avgres${varoi}rank resA${varoi}chL1rank_med: ///
	egen avgresA${varoi}chL1_med = mean(resA${varoi}chL1_med)
bys agebin avgres${varoi}rank resA${varoi}chL1rank_med: ///
	egen minresA${varoi}chL1_med = min(resA${varoi}chL1_med)
bys agebin avgres${varoi}rank resA${varoi}chL1rank_med: ///
	egen maxresA${varoi}chL1_med = max(resA${varoi}chL1_med)

** 2) Compute response: Average change btw t-1 and t+k
foreach lag in 1 2 3 5 10{
	bys agebin avgres${varoi}rank resA${varoi}chL1rank_mean: ///
		egen avgresA${varoi}chF`lag'_mean = mean(resA${varoi}chF`lag'_mean)
	bys agebin avgres${varoi}rank resA${varoi}chL1rank_med: ///
		egen avgresA${varoi}chF`lag'_med = mean(resA${varoi}chF`lag'_med)
}

** 3) Print the results
egen tagA_mean = tag(agebin avgres${varoi}rank resA${varoi}chL1rank_mean)
sort agebin avgres${varoi}rank resA${varoi}chL1rank_mean
outsheet agebin avgres${varoi}rank resA${varoi}chL1rank_mean  					///
	avgresA${varoi}chL1_mean avgresA${varoi}chF1_mean avgresA${varoi}chF2_mean  ///
	avgresA${varoi}chF3_mean avgresA${varoi}chF5_mean avgresA${varoi}chF10_mean ///
	minresA${varoi}chL1_mean maxresA${varoi}chL1_mean using impulseA_mean.txt 	///
	if tagA_mean==1, replace

egen tagA_med = tag(agebin avgres${varoi}rank resA${varoi}chL1rank_med)
sort agebin avgres${varoi}rank resA${varoi}chL1rank_med
outsheet agebin avgres${varoi}rank resA${varoi}chL1rank_med  					///
	avgresA${varoi}chL1_med avgresA${varoi}chF1_med avgresA${varoi}chF2_med  	///
	avgresA${varoi}chF3_med avgresA${varoi}chF5_med avgresA${varoi}chF10_med 	///
	minresA${varoi}chL1_med maxresA${varoi}chL1_med using impulseA_med.txt 	///
	if tagA_med==1, replace

global part2=c(current_time)
mac list begin part1 part2
capture noisily log close
