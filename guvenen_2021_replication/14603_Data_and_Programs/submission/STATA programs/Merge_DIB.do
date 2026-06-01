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

//JAE: Please change the below to the name of the 10% dib data file (dib10p78to13.dta)
global dib_file10percent="dib10p78to13.dta" 

// YOU DON'T NEED TO MAKE ANY CHANGES FROM THIS POINT ON!!!!
cd "$maindirectory${sep}dta${sep}"

use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR2013", clear

merge idd using "$maindirectory${sep}dta${sep}dib10p78to13.dta"

global merge_DIB=c(current_date)
global merge_DIB="$merge_DIB merge_DIB"

capture noisily log using "$maindirectory${sep}log${sep}$merge_DIB.log", replace

tab _merge

drop if _merge==2

forvalues yr=$yrfirst/$yrlast{
	display as text "Year # " as result `yr'
	sum labor`yr' dib`yr'
	sum labor`yr' if labor`yr' >0 & labor`yr' ~=.
	sum dib`yr' if dib`yr' >0 & dib`yr' ~=.
	sum labor`yr' dib`yr' if labor`yr' >0 & labor`yr' ~=. & dib`yr' >0 & dib`yr' ~=.
	display as text " " 	
	display as text " " 	
	display as text " " 		
}
capture noisily log close
drop _merge
save "$maindirectory${sep}dta${sep}MALE_LABORwDIB2013", replace
