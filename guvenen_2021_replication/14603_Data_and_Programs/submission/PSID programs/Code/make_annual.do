clear
cap log close
set more off

cd $output
cap log close
log using "${logf}make_annual.log", replace t

u merged_psid, clear

foreach var of varlist *time {
	gen temp = 0
	replace temp = 52 if `var'==3
	replace temp = 26 if `var'==4
	replace temp = 12 if `var'==5
	replace temp = 1  if `var'==6
	replace `var' = temp
	drop temp
}

foreach var of varlist *rep {
	replace `var' = 0 if `var' ==.
}

foreach var of varlist hrent* hdiv* hint* htrust* wrent* wdiv* ///
					   wint* wtrust* *year {
					   		replace `var' = 0 if `var' ==.
					   }

if year == 1999 | year == 2001 | year == 2003 {
	replace hrentinc = hrentincrep * hrentinctime
	replace hdividendinc = hdividendincrep * hdividendinctime
	replace hinterestinc = hinterestincrep * hinterestinctime
	replace htrustfund = htrustfundrep * htrustfundtime
	replace wrentinc = wrentincrep * wrentinctime
	replace wdividendinc = wdividendincrep * wdividendinctime
	replace winterestinc = winterestincrep * winterestinctime
	replace wtrustfund = wtrustfundrep * wtrustfundtime	
}

* ASSET INCOME
gen asset = hrentinc+hdividendinc+hinterestinc+htrustfund+hassbus+hassfarm+ ///
		    wrentinc+wdividendinc+winterestinc+wtrustfund+wassbus+oassinc

save merged_psid_annual, replace

log close
clear
