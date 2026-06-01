clear matrix
clear
capture log close
set more off
macro drop _all
set more off
set matsize 500
set linesize 255
set memory 3G  // Jae: you might wanna also increase the memory.

// Jae: You should change the below directory. 
global maindirectory ="/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Fatih_trial_replication/Stata"
// Please change the dataset name
global datafile_10p ="AR1_150K3EIN.dta" // Jae: Change the name of the data file to the 10% sample

global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac
if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}
global basla=c(current_time)

global outfolder=c(current_date)
global outfolder="$outfolder YRCHANGE_EIN"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"
capture noisily log using "$outfolder.log", replace

global yrfirst = 1978 		// First year in the dataset
global yrlast = 2010 		// Last year in the dataset
global begin_age = 25 
global retire_age = 60
global numq = 100		// Number of quintiles

global AGGpercentiles= "p1 p5 p10 p25 p50 p75 p90 p95 p99"
global inclist="wage" // Income list that we analyze
global varoi="wage" // Income list that we analyze

global base_price = 59   /* this is the index of the year 2005 */
global basla=c(current_time)
matrix cpimat = /*  CPI for 1947-2010
*/ (14.126,14.926,14.811,14.989, /*
*/ 16.009,16.337,16.556,16.697,16.764,17.101,17.620,18.035,18.306,18.606, /*
*/ 18.801,19.023,19.245,19.527,19.810,20.313,20.824,21.636,22.616,23.674, /*
*/ 24.681,25.525,26.901,29.703,32.184,33.950,36.155,38.687,42.118,46.642, /*
*/ 50.810,53.615,55.923,58.038,59.938,61.399,63.589,66.121,68.994,72.147, /*
*/ 74.755,76.955,78.643,80.265,82.041,83.826,85.395,86.207,87.596,89.778, /*
*/ 91.489,92.736,94.622,97.098,100.000,102.746,105.564,109.061,109.258,111.0501)

matrix minwg = /* Nominal minimum wage 1947-2010
*/ (0.40,0.40,0.40,0.40,0.75,0.75,0.75,0.75,0.75,1.00,1.00,1.00,1.00,1.00, /*
*/ 1.00,1.15,1.15,1.25,1.25,1.25,1.25,1.40,1.60,1.60,1.60,1.60,1.60,1.60, /*
*/ 2.00,2.10,2.10,2.30,2.65,2.90,3.10,3.35,3.35,3.35,3.35,3.35,3.35,3.35, /*
*/ 3.35,3.35,3.80,4.25,4.25,4.25,4.25,4.25,4.75,5.15,5.15,5.15,5.15,5.15, /*
*/ 5.15,5.15,5.15,5.15,5.15,5.85,6.55,7.25)

matrix rmininc = J(rowsof(minwg),colsof(minwg), 0.0)
forvalues yr = 1947/2010{
	local cpi_index = `yr'-1947+1
	local deflate = cpimat[1,$base_price]/cpimat[1,`cpi_index']
	matrix rmininc[1,`cpi_index']=40*13*0.5*minwg[1,`cpi_index']*`deflate'
}

matrix agedumwage= (17886.27, 20035.62, 21986.59, 23783.14, 25481.81, 27040.26, 28527.02, 29933.41, 31246, 32470.54, ///
33637.18, 34750.14, 35805.79, 36823.13, 37790.39, 38626.89, 39362.88, 40105, 40652.94, 41259.79, ///
41736.39, 42256.71, 42654.59, 42963.13, 43181.46, 43491.71, 43532.91, 43429.55, 43377.33, 43212.18, ///
42880.82, 42202.92, 41010, 40075.88, 39095.7, 37935.33)

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// This program generates a sample of wages with observations above 99.9999th percentile truncated
// We usually use the sample of wages with observations above 99.999th percentile truncated
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
do "$maindirectory${sep}do${sep}Gen_Wage_Sample_3EIN.do"

global YRCHANGE="$maindirectory${sep}do${sep}YRCHANGE_EIN_altdef.do"
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// This program generates a sample of wages with observations above 99.9999th percentile truncated
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

do "$maindirectory${sep}do${sep}bymydiststat.do"
do "$maindirectory${sep}do${sep}bymyxtile.do"
global kisim1=c(current_time)
// ************************************************************************************************	
//	Individual Factor Structure
// ************************************************************************************************	
foreach eayr in 1985 1990 1995 2000 2002 2005 2008{
	global minobspr = 3 				// Minimum number of observations  pre-recession 
	global yrbpr = max($yrfirst,`eayr'-5)	// Starting year to construct average income pre-period
	global yrepr = `eayr'-1				// Ending year to construct average income pre-period
	global yrbr = `eayr'				// Beginning year of the period (recession or expansion)
	global yrer = min($yrlast,`eayr'+1)	// Ending year of the period (recession or expansion)
	global yr5L = min($yrlast,`eayr'+5)	// Ending year of the period (recession or expansion)

	do "$YRCHANGE"	
}
global kisim2=c(current_time)
mac list basla kisim1 kisim2
