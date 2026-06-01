drop _all
use "$maindirectory${sep}dta${sep}cleaned_MALE_10p_LABOR19942013", clear

local yrdrop=$yrbpr-1 
forvalues yr = $yrfirst/`yrdrop'{  
	foreach var in labor{
		drop `var'`yr'
	}
}
local yrdrop1=$yrer+1
forvalues yr = `yrdrop1'/$yrlast{  
	foreach var in labor{
		drop `var'`yr'
	}
}

drop if yob > $yrepr -$begin_age +1 
drop if yob < $yrepr -$retire_age +1
drop if yod <= $yrer & yod~=.	
drop yod

gen age$yrepr = $yrepr-yob+1

gen  numobs${varoi}$yrepr=0

replace numobs${varoi}$yrepr=-5 if ${varoi}$yrepr < rmininc[1,$yrepr-1959+1] | ${varoi}$yrepr==.
forvalues t =$yrbpr/$yrepr{	
	replace numobs${varoi}$yrepr=numobs${varoi}$yrepr +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=. & ///
	age$yrepr>${begin_age}+1
}
forvalues t =$yrepr/$yrer{	
	replace numobs${varoi}$yrepr=numobs${varoi}$yrepr +1 if ${varoi}`t' >= rmininc[1,`t'-1959+1] & ${varoi}`t'~=. & ///
	age$yrepr<=${begin_age}+1
}
drop if numobs${varoi}$yrepr <$minobspr

keep age$yrepr ${varoi}$yrepr

rename age$yrepr age

bys age: egen N_${varoi}${yrepr}=count(${varoi}$yrepr)
by age: egen mean_${varoi}${yrepr}=mean(${varoi}$yrepr)
by age: egen mean_log${varoi}${yrepr}=mean(log(${varoi}$yrepr))
by age: egen sd_log${varoi}${yrepr}=sd(log(${varoi}$yrepr))

egen printtag=tag(age N_${varoi}${yrepr})
drop if printtag~=1

drop printtag ${varoi}$yrepr

save "$maindirectory${sep}out${sep}$outfolder${sep}sumstat$yrepr.dta", replace
