clear all
capture log close
set more off
set matsize 500
set linesize 255

// Jae: You should change the below directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata"
global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac

// YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!

if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}
global yrfirst = 1994 		// First year in the dataset
global yrlast = 2013 		// Last year in the dataset
global begin_age = 25 
global retire_age = 60
global numq = 100		// Number of quintiles

global varoi="labor" // Income list that we analyze


global outfolder=c(current_date)
global outfolder="$outfolder LABOR_YBAR_DISPERSION"
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

global YBAR_DISP="$maindirectory${sep}do${sep}YBAR_DISP.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"
do "$maindirectory${sep}do${sep}bymysum.do"
do "$maindirectory${sep}do${sep}bymypctile1.do"


// ************************************************************************************************	
//	Cross-Sectional Moments
// ************************************************************************************************	

local yearfirst=$yrfirst+3
local yearlast=$yrlast+1
forvalues eayr = `yearfirst'/`yearlast'{
	global minobspr = 3 	// Minimum number of observations  pre-recession 
	global yrbpr =max(${yrfirst},`eayr'-5)	// Starting year to construct average income pre-period
	global yrepr = `eayr'-1	// Ending year to construct average income pre-period
	global yrer = min(`eayr'+1,$yrlast)	// Ending year to construct average income pre-period	
	do ${YBAR_DISP}
}

use "$maindirectory${sep}out${sep}$outfolder${sep}sumstat1996", clear
erase "$maindirectory${sep}out${sep}$outfolder${sep}sumstat1996.dta"
forvalues eayr = 1997/$yrlast{
	merge 1:1 age using "$maindirectory${sep}out${sep}$outfolder${sep}sumstat`eayr'"
	erase "$maindirectory${sep}out${sep}$outfolder${sep}sumstat`eayr'.dta"
	drop _merge
}

outsheet age N_* using N_YBAR.txt, replace
outsheet age mean_la* using mean_YBAR.txt, replace
outsheet age mean_log* using mean_logYBAR.txt, replace
outsheet age sd_log* using sd_logYBAR.txt, replace

global part1=c(current_time)
mac list begin part1 
capture noisily log close
