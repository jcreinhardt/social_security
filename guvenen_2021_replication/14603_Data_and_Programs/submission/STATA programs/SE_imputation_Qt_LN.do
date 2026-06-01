capture noisily log close
capture noisily log using "$maindirectory${sep}out${sep}$outfolder${sep}Qreg.log", replace

global yrfirst = 1993 		// First year in the dataset
global yrlast  = 1996 		// Last year in the dataset
global begin_age = 25
global retire_age = 60

u "$maindirectory${sep}dta${sep}cleaned_MALE_10p_WAGE_SELFINC2013_2260", clear

keep wage1993 wage1994 wage1995 wage1996 selfinc1993 selfinc1994 selfinc1995 ///
	selfinc1996 yob yod
	
/* This part is for fake dataset
replace selfinc1996=selfinc1996+topinc[1,1996-1959+1]	
forvalues yr=1993/1995{
	replace selfinc`yr'=selfinc`yr' + 1.5*runiform()*topinc[1,`yr'-1959+1]
}
*/

drop if yob==.
drop if yod<=${yrlast} & yod~=.
drop if yob>${yrlast}-${begin_age}+1
drop if yob<${yrlast}-${retire_age}+1
drop if selfinc${yrlast}<topinc[1,${yrlast}-1959+1]		// people not top-coded in 1996

gen tempage=${yrlast}-yob+1
gen age = .
local bin=1
forvalues h = $begin_age(5)$retire_age{
	replace age = `bin' if tempage>=`h' & tempage<min(`h'+5,$retire_age)	
	local bin=`bin' +1
}
qui sum age
local bin=r(max)
replace age = `bin'  if tempage==$retire_age
drop tempage

** Age-by-age regression for imputation to obtain the coefficients.
forvalues t=$yrfirst/$yrlast{
	gen topcoded`t'=(selfinc`t'>=topinc[1,`t'-1959+1])
	gen zeroselfinc`t'=(selfinc`t'<rmininc[1,`t'-1959+1])
	gen lnselfinc`t'=(1-zeroselfinc`t')*ln(max(selfinc`t',0.5*rmininc[1,`t'-1959+1]))
	gen lntopcodedself`t'=min(lnselfinc`t',ln(topinc[1,`t'-1959+1]))
	gen zerowage`t'=(wage`t'<rmininc[1,`t'-1959+1])
	gen lnwage`t'=(1-zerowage`t')*ln(max(wage`t',0.5*rmininc[1,`t'-1959+1]))
}


gen nquant=.
forvalues nquan=1(1)$nq{
	local quant=-0.5/$nq+`nquan'/$nq
	replace nquant=`nquan'
	qui statsby _b, by(age nquant) saving(impt_coeffs_q`nquan',replace): ///
	_qreg  lnselfinc1996 zerowage* lnwage* topcoded1993 topcoded1994 topcoded1995 	///
		zeroselfinc1993 zeroselfinc1994 zeroselfinc1995 ///
		lntopcodedself1993 lntopcodedself1994 lntopcodedself1995, quantile(`quant')
}

drop nquant
xtile nquant= runiform(), n($nq)
save temp.dta, replace

use impt_coeffs_q1, clear
erase impt_coeffs_q1.dta
forvalues nquan=2(1)$nq{
	append using impt_coeffs_q`nquan'
	erase impt_coeffs_q`nquan'.dta
}
outsheet using impt_coeffs_qln.txt, replace
save "$maindirectory${sep}dta${sep}impt_coeffs_qln", replace

use temp.dta, clear
merge m:1 age nquant using "$maindirectory${sep}dta${sep}impt_coeffs_qln"
erase temp.dta

** Generate labor income using imputed self-income observations
gen imputedselfinc${yrlast} = _b_cons + _b_zerowage1993*zerowage1993 +  _b_zerowage1994*zerowage1994 ///
+ _b_zerowage1995*zerowage1995 + _b_zerowage1996*zerowage1996 + _b_lnwage1993*lnwage1993  ///
+ _b_lnwage1994*lnwage1994 + _b_lnwage1995*lnwage1995 + _b_lnwage1996*lnwage1996 ///
+ _b_topcoded1993*topcoded1993 + _b_topcoded1994*topcoded1994 + _b_topcoded1995*topcoded1995 ///
+ _b_zeroselfinc1993*zeroselfinc1993 + _b_zeroselfinc1994*zeroselfinc1994  ///
+ _b_zeroselfinc1995*zeroselfinc1995 + _b_lntopcodedself1993*lntopcodedself1993 /// 
+ _b_lntopcodedself1994*lntopcodedself1994 + _b_lntopcodedself1995*lntopcodedself1995
reg imputedselfinc${yrlast} lnselfinc1996 
tw scatter imputedselfinc${yrlast} lnselfinc1996   ///
|| line lnselfinc1996 lnselfinc1996 
graph export fit_qreg.eps, replace

capture noisily log close
