// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// This program generates disability benefits for 10% sample of males between 1978-2013
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

clear all
capture log close
set more off
set matsize 500
set linesize 255

// Jae: You should change the below directory. 
global maindirectory ="/Users/serdar/Dropbox/ssa-income-risk/STATA/"
global unix=1  // JAE: Please change this to 1 if you run stata on Unix or Mac

if($unix==1){
	global sep="/"
}
else{
	global sep="\"
}

// YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!
cd "$maindirectory${sep}dta${sep}"

use MALE_LABORwDIB2013.dta

global yrfirst = 1978 		// First year in the dataset
global yrlast = 2013 		// Last year in the dataset
global begin_age = 25 
global retire_age = 60

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
	
forvalues yr = $yrfirst/$yrlast{
	replace dib`yr' = 0 if dib`yr'==.
}

forvalues yr = $yrfirst/$yrlast{
	local cpi_index = `yr'-1959+1
	local deflate = cpimat[1,$base_price]/cpimat[1,`cpi_index']
	replace dib`yr' = dib`yr'*`deflate'
			
	replace dib`yr'= . if `yr'-yob+1 < $begin_age | `yr'- yob+1>$retire_age 
	replace dib`yr'= . if `yr'>= yod & yod~=.  // (yod=. is very big number)
	
	gen totinc`yr'=labor`yr'+dib`yr'
}

compress
sort idd
save "$maindirectory${sep}dta${sep}MALE_LABORwDIBwTOTINC2013", replace

global outfolder=c(current_date)
global outfolder="$outfolder DIBAgeDum_M2013"
capture noisily mkdir "$maindirectory${sep}out${sep}$outfolder"
cd "$maindirectory${sep}out${sep}$outfolder"

drop idd
sample 10
gen id=_n
save "$maindirectory${sep}dta${sep}temp", replace
/* Convert to long format */

forval y = $yrfirst/$yrlast {
	/* Load data */

	u id yob yod labor`y' dib`y' totinc`y' ///
		if `y'<yod & `y'-yob+1 >= $begin_age & `y'- yob+1<=$retire_age ///
		using "$maindirectory${sep}dta${sep}temp", clear
	drop yod

	/* Rename variables */
	rename labor`y' labor
	rename dib`y' dib	
	rename totinc`y' totinc

	/* Construct variables */

	gen int year = `y'
	gen byte age = year-yob+1
	
	/* Sample criteria */

	keep if inrange(age,$begin_age,$retire_age)
	// Create variables for positive values
	gen labor_P=labor if labor>= rmininc[1,`y'-1959+1]
	gen totinc_P=totinc if totinc>= rmininc[1,`y'-1959+1]
	gen dib_P=dib if dib>= rmininc[1,`y'-1959+1]/10	

	/* Save data */

	if `y'>$yrfirst {
		append using "$maindirectory${sep}dta${sep}Long_Data_male"
	}

	save "$maindirectory${sep}dta${sep}Long_Data_male", replace
}
erase "$maindirectory${sep}dta${sep}temp.dta"

drop _all
use "$maindirectory${sep}dta${sep}Long_Data_male"
erase "$maindirectory${sep}dta${sep}Long_Data_male.dta"

foreach var in labor dib totinc{
	gen log`var'=log(`var'_P) 
	bys year age: egen D_N`var'=count(`var')	
	by year age: egen D_avg`var'=mean(`var')
	by year age: egen D_N`var'_P=count(`var'_P)	
	by year age: egen D_avg`var'_P=mean(`var'_P)
	by year age: egen D_avglog`var'=mean(log`var')	
	by year age: egen D_sdlog`var'=sd(log`var')			
}
egen printtag=tag(year age)

outsheet year age D_* using sumstat_dib_ageyear.txt if printtag==1, replace
drop printtag

tab year, gen(yeardum)
tab age, gen(agedum)
tab yob, gen(cohdum)

capture noisily log using "$maindirectory${sep}out${sep}$outfolder${sep}agedummy_dib.log", replace

foreach var in labor totinc dib{
	regress log`var' agedum* cohdum2-cohdum55, nocons
	regress log`var' agedum* yeardum2-yeardum20, nocons
}

capture noisily log close

