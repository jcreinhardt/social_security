clear
cap log close
set more off

cd $output
cap log close
log using "${logf}clean_data.log", replace t

u merged_psid_annual, clear
erase merged_psid_annual.dta

sort person year
qby person: gen dyear=year-year[_n-1]
egen todrop=sum(dyear>2 & dyear!=.),by(person)	/* Drop those with intermittent "headship" */
egen n=sum(person!=.),by(person)				/* Drop those appearing only once */
replace todrop=1 if n==1
drop if todrop>0
drop todrop dyear n


*Makes the variable race consistent over the years
*Now 1 is white, 2 black, 3 others
gen     rc=race if race<=2
replace rc=3    if race>=3 & race<=7
drop race
ren rc race


* Makes the variable education consistent over the years
*   Now 1 is 0-11 grades (includes those with no schooling, i.e. can't read/write people); 
*       2 is 12 grades, i.e. high school w or w/o nonacademic training;
*       3 is college dropout, college degree, or collage & advanced/professional degree;
*       a missing point denotes na/dk.
gen etmp=1 if educ>=0  & educ<=11 & year>1989           /* 0-11  grades */
replace etmp=2 if educ==12                        		/* High school or 12 grades+nonacademic training */
replace etmp=3 if educ>=13 & educ<=17 & year>1989		/* College dropout, BA degree, or collage & adv./prof. degree */
replace etmp=. if educ>17 & year>1989					/* Missing, NA, DK */
drop educ
ren etmp educ

* Make some manual adjustments
sort person year
by person: replace educ=educ[_n-1] if educ==.
gsort person -year
by person: replace educ=educ[_n-1] if educ==.
sort person year

* Take the maximum grade achieved as the relevant education level
egen maxed=max(educ),by(person)
gen educ2=educ
replace educ=maxed
drop maxed 

* Design a demographically unstable household as one where some family composition 
* change (apart from changes in people other than head-wife takes place).
* Then drop households with unstable demographical pattern

* fchg =
* 0 (No change)
* 1 (Change in members other than Head or Wife)
* 2 (Head same, wife left,die, or is new)
* 3 (wife is now head), 4 (ex female head married and huisband is now head)
* 5 (some sample member other than ex Head or Wife is now head)
* 7 (ex wife head because husband in inst., now husband back and is head)
* 8 (Other)

egen miny=min(year),by(person)
gen temp1=fchg>1
replace temp1=0 if year==miny & temp1==1	/* starting household structure is when they first appear in sample */
egen instable = sum(temp1), by(person)
replace instable = (instable!=0)

drop miny temp1

* Drop female household heads
gen fmhead = (sex==2)

* Drop households with missing observations on race, education, or state of residence
drop if race==.

gen m=educ==.
egen mm=sum(m),by(person)
drop if mm>0
drop m mm

*by person: gen dyear = year - year[_n-1]
*by person: gen dage = age - age[_n-1]

* Some manual adjustments
replace age  = 41 if person==4216 & age==.
replace age  = 26 if person==9923 & age==. 
replace agew = 32 if person==6901 & agew==.
replace agew = 34 if person==14227& agew==.

* Recode age so that there is no gap or jump
egen lasty=max(year),by(person)
gen  lastage=age if year==lasty
gen  b=year-lastage
replace b=0 if b==.
egen yb=sum(b),by(person)
replace age=year-yb
drop lasty lastage yb b

* Define the regions
egen n=sum(state==.|state==0|state==99),by(person)
drop if n>0
drop n

# delimit;
gen     region=1 if state==6  | state==18 | state==20 | state==28 | state==29 | state==31 
                              | state==37 | state==38 | state==44; 						 /* North East*/
replace region=2 if state==12 | state==13 | state==14 | state==15 | state==21 | state==22
                              | state==24 | state==26 | state==33 | state==34 | state==40 | state==48; /*Midwest*/
replace region=3 if state==1  | state==3  | state==7  | state==8  | state==9  | state==10 | state==16  
                              | state==17 | state==19 | state==23 | state==32 | state==35 
                              | state==39 | state==41 | state==42 | state==45 | state==47; 		 /*South*/
replace region=4 if state==2  | state==4  | state==5  | state==11 | state==25 | state==27 | state==30 
                              | state==36 | state==43 | state==46 | state==49 | state==50 | state==51; /*West*/                              
#delimit cr

sort person year

gen yb=year-age
gen ybw=year-agew

* Do not use observations with topcoded income or financial income or federal taxes paid
replace asset=. if trunc==1
replace y    =. if trunc==1

gen ratio_ya=(y-asset)/y
replace ratio_ya=0 if ratio_ya<0	/* Ratio of non-financial income to income */
									/* We have total federal taxes, ftax */
									/* We assume that taxes paid on non-financial income */
									/* are equal to (ratio_ya*ftax) */

*Add a CPI price index and transform variables in real term
*This series is drawn from ftp://ftp.bls.gov/pub/special.requests/cpi/cpiai.txt
*CPI Base year is 2006
*2000 U.S. Department Of Labor, Bureau of Labor Statistics, Washington, D.C. 20212
*Consumer Price Index All Urban Consumers - (CPI-U) U.S. city average All items 

replace year = year-1 /* take into account the retrospective nature of survey*/

gen     price= 77.827 if year==1996
replace price= 79.613 if year==1997
replace price= 80.853 if year==1998
replace price= 82.639 if year==1999
replace price= 85.417 if year==2000
replace price= 87.847 if year==2001
replace price= 89.236 if year==2002
replace price= 91.270 if year==2003
replace price= 93.700 if year==2004
replace price= 96.875 if year==2005
replace price=100.000 if year==2006
replace price=102.848 if year==2007
replace price=106.797 if year==2008
replace price=106.417 if year==2009
replace price=108.163 if year==2010
replace price=111.577 if year==2011
replace price=113.886 if year==2012
replace price=115.554 if year==2013

* Scale so that 2010 prices == 100
replace price=100*price/108.163

gen ratio=ly/y		/*Ratio of male earnings to total income*/
replace ratio=1 if ratio>1 & ratio!=.

recode race (0=.) (1=1) (2=2) (3/9 =3)
gen selfe =self==3
recode empst (1 2=1) (3=2) (4=3) (5/99 = 4)
gen veteran    = vet==1
gen disability = disab==1
gen kidsout    = outkid==1
gen extra = (tyoth)>0

save merged_psid_clean, replace

log close
clear
