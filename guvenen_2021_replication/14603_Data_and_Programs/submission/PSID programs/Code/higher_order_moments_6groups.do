clear
cls
cap log close
set more off

cd $output
cap log close
log using "${logf}higher_order_moments.log", replace t

**defining programs
do ${code}kelly_skewness.do
do ${code}moors_kurtosis.do
do ${code}crows_kurtosis.do

gl sample=1		// 1: 25-55, 2: 25-39, 3: 40-55
if $sample==1{
	gl minage=25
	gl maxage=55
	gl filename="psid_stats_all_6groups.xlsx"
	mat shares=(3.8, 3.8+14.4, 3.8+14.4+62.3, 3.8+14.4+62.3+16.5, 3.8+14.4+62.3+16.5+3.0)
}
else if $sample==2{
	gl minage=25
	gl maxage=39
	gl filename="psid_stats_25_39_6groups.xlsx"
	mat shares=(4.0, 4.0+16.0, 4.0+16.0+59.0, 4.0+16.0+59.0+17.7, 4.0+16.0+59.0+17.7+3.3)
}
else if $sample==3{
	gl minage=40
	gl maxage=55
	gl filename="psid_stats_40_55_6groups.xlsx"
	mat shares=(3.6, 3.6+16.6, 3.6+16.6+65.2, 3.6+16.6+65.2+15.4, 3.6+16.6+65.2+15.4+2.8)
}
else{
	stop
}

gl truncate_min=1
gl min_inc=1500
*mat thresh_y = (-100000,-1,-.5,-.25,-.05,.05,.25,.5,1,100000)
*mat thresh_y = (-100000,-1,-.25,.25,1,100000)
mat thresh_y = (-100000,-1,-.25,0,.25,1,100000)
mat thresh_w = thresh_y
mat thresh_h = thresh_y

u merged_psid_clean, clear

gen touse = 1
replace touse = touse*!(age<25|age>55)*(seo==0)*(sex==1)
keep if touse

gen agegroup=1 if inrange(age,25,39)
replace agegroup=2 if inrange(age,40,55)

* make earnings real
replace ly = 100*ly/price

drop if ly < $min_inc
*drop if (ly==0 & hours>0) | (ly>0 & hours==0)
*if $truncate_min==1{
*	replace ly = $min_inc if ly<$min_inc
*}

gen wage = ly/hours
gen logy=ln(ly)
gen logw=ln(wage)
gen logh=ln(hours)

* Declare the data as panel with one year gap
tsset person year, delta(2)

* Residualize
local vars "y w h"
foreach lname of local vars {
	reg log`lname' i.year##(i.educ i.age i.race i.region) if touse
	predict u`lname' if e(sample), res
	gen du`lname' = D.u`lname'
}
la var duy "earnings chg"
la var duw "wage chg"
la var duh "hours chg"

matrix Table2=J(4,6,.)
if $sample==1{
	foreach v in "y" "w"{
		kelly_skewness du`v'
		local kelley_`v'_all = r(k)

		crows_kurtosis du`v'
		local crows_`v'_all = r(m)

		sum du`v', det
		local skew_`v'_all = r(skewness)
		local kurt_`v'_all = r(kurtosis)
	}


	foreach v in "y" "w"{
		forvalues h=1/2{
			kelly_skewness du`v' "if agegroup==`h'"
			local kelley_`v'_`h' = r(k)

			crows_kurtosis du`v' "if agegroup==`h'"
			local crows_`v'_`h' = r(m)

			sum du`v' if agegroup==`h', det
			local skew_`v'_`h' = r(skewness)
			local kurt_`v'_`h' = r(kurtosis)
		}
	}

	matrix Table2=(`skew_y_all', `skew_w_all', `skew_y_1', `skew_w_1', `skew_y_2', `skew_w_2' \ `kelley_y_all',`kelley_w_all', `kelley_y_1',`kelley_w_1', `kelley_y_2',`kelley_w_2' \ `kurt_y_all', `kurt_w_all', `kurt_y_1', `kurt_w_1', `kurt_y_2', `kurt_w_2' \ `crows_y_all', `crows_w_all', `crows_y_1', `crows_w_1', `crows_y_2', `crows_w_2')
	matrix colnames Table2 = earnings_all wages_all earnings_age1 wages_age1 earnings_age2 wages_age2
	matrix rowname Table2 = Skewness Kelley_Skewness Kurtosis Crow_Kurtosis
	matrix list Table2
	putexcel set Table2, replace sheet("Table2")
	putexcel A1 = matrix(Table2), names nformat(#0.00)
}

drop if age<${minage} | age>${maxage}

local vars "y"
foreach lname of local vars {
	gen group_`lname'=.
	replace group_`lname'=1 if inrange(du`lname',thresh_`lname'[1,1],thresh_`lname'[1,2])
	replace group_`lname'=2 if inrange(du`lname',thresh_`lname'[1,2],thresh_`lname'[1,3])
	replace group_`lname'=3 if inrange(du`lname',thresh_`lname'[1,3],thresh_`lname'[1,4])
	replace group_`lname'=4 if inrange(du`lname',thresh_`lname'[1,4],thresh_`lname'[1,5])
	replace group_`lname'=5 if inrange(du`lname',thresh_`lname'[1,5],thresh_`lname'[1,6])
	replace group_`lname'=6 if inrange(du`lname',thresh_`lname'[1,6],thresh_`lname'[1,7])

	egen printtag_`lname'=tag(group_`lname')

	bys  group_`lname': egen ngroup_`lname' = count(du`lname')
	egen ndu`lname' = count(du`lname')
	gen  share_`lname' = ngroup_`lname'/ndu`lname'
	la var group_`lname' "Group"
	la var share_`lname' "Share"
}

** Health related
sort person year
gen some_disabl=.
replace some_disabl=1 if inlist(hdisabl,1,3,5)	// some disability that prevents work
replace some_disabl=0 if inlist(hdisabl,0,7)
la var some_disabl "some disability"

gen new_disabl=0
replace new_disabl=1 if L1.some_disabl==0 & some_disabl==1
gen new_notdisabl=0
replace new_notdisabl=1 if L1.some_disabl==1 & some_disabl==0
la var new_disabl "flow to disability"
la var new_notdisabl "flow out of disability"

gen some_hhealth=.
replace some_hhealth=1 if inlist(hhealth,4,5)	// fair or poor
replace some_hhealth=0 if inlist(hhealth,1,2)
la var some_hhealth "some health issue"

gen bad_hhealth=0
replace bad_hhealth=1 if inlist(hhealth,5)	// poor
gen new_badhealth=0
replace new_badhealth=1 if L.bad_hhealth==0 & bad_hhealth==1
gen new_goodhealth=0
replace new_goodhealth=1 if L.bad_hhealth==1 & bad_hhealth==0
la var bad_hhealth "bad health"
la var new_badhealth "flow to bad health"
la var new_goodhealth "flow to good health"

** Time off work
gen unemp=1 if wtrunemp==1
replace unemp=0 if wtrunemp==5
gen wksunemp = 4*monthsunemp
gen wksu = wksunemp1
replace wksu = wksunemp if  mi(wksunemp1) | (wksunemp1<wksunemp & ~mi(wksunemp))
drop wksunemp
ren wksu wksunemp

egen totaltimeoff = rowtotal(wksolf wksunemp)
la var wksunemp "wks unemployed"
la var wksolf "wks olf"
la var totaltimeoff "wks out of work"

gen change_unemp = wksunemp-L.wksunemp
gen change_olf = wksolf-L.wksolf
gen change_timeoff = totaltimeoff-L.totaltimeoff
la var change_unemp "change wks unemp"
la var change_olf "change wks olf"
la var change_timeoff "change wks out"

gen move_outsidevent=0
replace move_outsidevent=1 if whymoved==7
la var move_outsidevent "move"

** Job and occupation change
gen job_change=0      if ~mi(job_startyr)
replace job_change=1  if job_startyr>year-1 & ~mi(job_startyr)
replace job_change=0  if ~mi(emp_tenure) & emp_tenure>2
la var  job_change "job change"

gen eue=0 if job_change==1 & totaltimeoff==0
replace eue=1 if job_change==1 & totaltimeoff>0
la var eue "EUE switcher"

gen duy_switcher = duy if job_change==1
gen duw_switcher = duw if job_change==1
gen duy_ee_switcher  = duy if eue==0
gen duy_eue_switcher = duy if eue==1
la var duy_switcher "earnings chg switcher"
la var duw_switcher "wage chg switcher"
la var duy_ee_switcher "earnings chg ee switcher"
la var duy_eue_switcher "earnings chg eue switcher"

foreach x in "ee" "eue"{
	_pctile duy_`x'_switcher, p(3.8, 18.2, 49.4, 80.5, 97)
	gen group_`x'_switch=.
	replace group_`x'_switch=1 if duy_`x'_switcher<r(r1)
	replace group_`x'_switch=2 if inrange(duy_`x'_switcher,r(r1),r(r2))
	replace group_`x'_switch=3 if inrange(duy_`x'_switcher,r(r2),r(r3))
	replace group_`x'_switch=4 if inrange(duy_`x'_switcher,r(r3),r(r4))
	replace group_`x'_switch=4 if inrange(duy_`x'_switcher,r(r4),r(r5))
	replace group_`x'_switch=5 if duy_`x'_switcher>=r(r5) & ~mi(duy_`x'_switcher)
	bys group_`x'_switch: egen avg_duy_`x'_switcher=mean(duy_`x'_switcher)
	la var avg_duy_`x'_switcher "avg earnings chg `x' switchers"
	egen printtag_`x'=tag(group_`x'_switch)
}
sort person year

* Occupation recode
gen hocc_rec=.
replace hocc_rec=1  if inrange(hocc,1,43)
replace hocc_rec=2  if inrange(hocc,50,73)
replace hocc_rec=3  if inrange(hocc,80,95)
replace hocc_rec=4  if inrange(hocc,100,124)
replace hocc_rec=5  if inrange(hocc,130,156)
replace hocc_rec=6  if inrange(hocc,160,196)
replace hocc_rec=7  if inrange(hocc,200,206)
replace hocc_rec=8  if inrange(hocc,210,215)
replace hocc_rec=9  if inrange(hocc,220,255)
replace hocc_rec=10 if inrange(hocc,260,296)

replace hocc_rec=11 if inrange(hocc,300,354)
replace hocc_rec=12 if inrange(hocc,360,365)
replace hocc_rec=13 if inrange(hocc,370,395)
replace hocc_rec=14 if inrange(hocc,400,416)
replace hocc_rec=15 if inrange(hocc,420,425)
replace hocc_rec=16 if inrange(hocc,430,465)
replace hocc_rec=17 if inrange(hocc,470,496)
replace hocc_rec=18 if inrange(hocc,500,593)
replace hocc_rec=19 if inrange(hocc,600,613)
replace hocc_rec=20 if inrange(hocc,620,676)
replace hocc_rec=21 if inrange(hocc,680,694)
replace hocc_rec=22 if inrange(hocc,700,762)
replace hocc_rec=23 if inrange(hocc,770,896)
replace hocc_rec=24 if inrange(hocc,900,975)
replace hocc_rec=25 if inrange(hocc,980,983)


gen occ_chg=.
replace occ_chg = 0 if L1.hocc_rec==hocc_rec
replace occ_chg = 1 if L1.hocc_rec~=hocc_rec
replace occ_chg = 0 if occ_chg==1 & L1.hocc_rec==F1.hocc_rec
la var occ_chg "occupation change"

gen occ_chg2=occ_chg
replace occ_chg2=0 if occ_chg==1 & job_change==0
la var occ_chg2 "occupation change"

foreach lname of local vars {
	foreach var of varlist duy duw duh some_disabl new_disabl 	 ///
		new_notdisabl some_hhealth  bad_hhealth new_badhealth 	 ///
		new_goodhealth wksunemp wksolf totaltimeoff change_unemp ///
		change_olf change_timeoff move_outsidevent occ_chg2 	 ///
		job_change duy_switcher duy_ee_switcher duy_eue_switcher {
		bys group_`lname': egen avg_`lname'_`var' = mean(`var')
		local lab: variable label `var'
		la var avg_`lname'_`var' "`lab'"
	}
}

bys group_y: egen corr_dw_dh = corr(duw duh)
la var corr_dw_dh "Corr(dw,dh)"
keep group_* share_* corr_* avg_* printtag*
order group_y share_y avg_y_duy avg_y_duw avg_y_duh corr_*

foreach x in "ee" "eue"{
preserve
	duplicates drop group_`x'_switch,force
	drop if group_`x'_switch==.
	keep group_`x'_switch avg_duy_`x'_switcher
	sum avg_duy_`x'_switcher
	ren group_`x'_switch group
	sort group
	save temp_`x', replace
restore
}

ren group_y group
drop group_*_switch avg_duy_*_switcher printtag* avg_y_duy_ee_switcher ///
	avg_y_duy_eue_switcher avg_y_duy_switcher
duplicates drop group, force
foreach x in "ee" "eue"{
	merge 1:1 group using temp_`x', nogen
	erase temp_`x'.dta
	drop if group==.
}
ren group group_y

local vars "y"
foreach lname of local vars {
	sort group_`lname'
	keep group_y share_y avg_y_duy avg_y_duw avg_y_duh avg_y_change_timeoff avg_y_occ_chg2 avg_y_job_change avg_y_new_disabl
	order group_y share_y avg_y_duy avg_y_duw avg_y_duh avg_y_change_timeoff avg_y_occ_chg2 avg_y_job_change avg_y_new_disabl
	export excel using ${filename}, sheetreplace firstrow(varlabels) sheet("`lname'") keepcellfmt
}
log close
