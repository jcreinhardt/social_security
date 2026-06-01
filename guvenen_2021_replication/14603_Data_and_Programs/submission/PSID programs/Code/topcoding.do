cd $inter

clear 
set more off
set maxvar 20000
cap log close
log using "${logf}topcoding.log",replace text

u family_combined, clear

gen trunc = 0

*TOP-CODING - 8 - 9 VARIABLES
foreach var of varlist hhealth hhealthbtr hsick hdisabl hstrike htlayoff ///
	uprevjob wtrunemp{
	replace `var' = . if `var' == 8 | `var' == 9
}

*TOP-CODING - 98 - 99 VARIABLES
foreach var of varlist whymoved monthsunemp emp_tenure wksunemp1{
	replace `var' = . if `var' == 98 | `var' == 99
}

*TOP-CODING - 998 - 999 VARIABLES
foreach var of varlist age agew weight hsickdays htlayoffdays hunemp hocc{
	replace `var' = . if `var' == 998 | `var' == 999
	replace trunc = 1 if `var' == 997
}


*TOP-CODING - 9,998 - 9,999 VARIABLES
foreach var of varlist  avhy job_startyr{
	replace `var' = 0 if `var' == 9998 | `var' == 9999
	replace trunc = 1 if `var' == 9997		
} 


*TOP-CODING - 999,998 - 999,999 VARIABLES

foreach var of varlist hrentincrep hdividendincrep hinterestincrep /// 
	htrustfundrep wdividendincrep winterestincrep wtrustfundrep /// 
	wrentincrep hrentinc hdividendinc hinterestinc wdividendinc /// 
	winterestinc wtrustfund  {
		replace `var' = 0 if `var' == 999998 | `var' == 999999 | `var' == -99999
		replace trunc = 1 if `var' == 999997 | `var' == -99998
	}


*TOP-CODING - 9,999,998 - 9,999,999 VARIABLES

foreach var of varlist hassbus wassbus {
	replace `var' = 0 if `var' == 9999998 | `var' == 9999999 | `var' == -999999
	replace trunc = 1 if `var' == 9999997 | `var' == -999998
}

save family_combined_b, replace 
log close
