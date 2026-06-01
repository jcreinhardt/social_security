clear
cap log close
set more off

cd $inter
cap log close
log using "${logf}merge_files.log", replace t


u family_combined_b,clear
sort intid year
save family_combined_c, replace

u person,clear
compress
sort intid year
merge intid year using family_combined_c
tab _merge
drop if _merge!=3
drop _merge

erase person.dta
erase family_combined.dta
erase family_combined_b.dta
erase family_combined_c.dta

cd $output
save merged_psid, replace

log close
clear
