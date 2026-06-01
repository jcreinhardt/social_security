****EXTRACTS FROM THE FAMILY FILES THE VARIABLES OF INTEREST *****

cd $inter
clear
set more off
set maxvar 20000
cap log close
log using "${logf}process_family_files.log", replace text

** Process 1999 data
u family_1999

rename ER13002 intid   //interview number 1999
rename ER13019 id68    //FAMILY NUMBER - id
rename ER16518 famwgt  //aweights

** INCOME
rename ER16462   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER16463  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER16465 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER16452  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER16456  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER16454  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER16458  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER13004  state   // STATE
rename ER13009  fsize   // # IN FU
rename ER13008A  fchg   // family composition change since last wave
rename ER13010    age   // AGE OF HEAD (missing = 999)
rename ER13011    sex   // SEX OF HEAD
rename ER13012   agew   // AGE OF WIFE
rename ER13013   kids
rename ER13021  marit   // MARITAL STATUS
rename ER13205  empst   // WORKING NOW
rename ER13210   self   // SELF-EMPLOYED
rename ER13213 unionj   // Head's Job covered by a union contract
rename ER13214 unioni   // Head belongs to a labor union
rename ER14976 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER15449  disab   // HEAD DISABLED
rename ER15552 weight   // WEIGHT (missing = 999)
rename ER15890  newhd   // whether same head as in last wave 
rename ER15928   race   // RACE
rename ER15935    vet   // HEADS A VETERAN
rename ER16471  hours   // YRLY HEADS HRS
rename ER16514   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER16516   educ   // HEADS EDUCATION

gen            split = .  // has info in 01-11 (whether family a splitoff from 1968)

gen            oassinc = .          // asset income of OFUM (available 2005-2011)
rename ER14479 hrentincrep          // num(6.0), 8-9
rename ER14480 hrentinctime   
rename ER14494 hdividendincrep      // num(6.0), 8-9
rename ER14495 hdividendinctime 
rename ER14509 hinterestincrep      // num(6.0), 8-9
rename ER14510 hinterestinctime
rename ER14524 htrustfundrep        // num(6.0), 8-9
rename ER14525 htrustfundtime
rename ER14790 wdividendincrep      // num(6.0), 8-9
rename ER14791 wdividendinctime
rename ER14805 winterestincrep      // num(6.0), 8-9
rename ER14806 winterestinctime
rename ER14820 wtrustfundrep        // num(6.0), 8-9
rename ER14821 wtrustfundtime
rename ER16491 hassbus 				//annual
rename ER16512 wassbus 				//annual
rename ER16448 hassfarm 			//both labor and asset
rename ER16490 hlabbus
rename ER16511 wlabbus
//asset = sum (above)

rename ER15447 hhealth 				// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER15451 hdisabl				// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA

rename ER13498 uprevjob				// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER13080 whymoved				// 7 response to outside events, 99 DK NA, 0 has not moved
rename ER13253 change_othere		// 1 promotion, 5 change in duties,  7 other, 9 NA/DK
rename ER13300 change_samee			// 1 promotion, 5 change in duties,  7 other, 8-9 NA/DK

rename ER13362 wksworked			// 99 NA-DK. 0 Inapplicable
rename ER16477 wksolf				// check values. 0 inap.
rename ER13243 emp_tenure			// tenure with employer

drop ER*
gen year = 1999
compress
sort intid
save fam99, replace



** Process 2001 data
u family_2001

rename ER17002 intid   //interview number 1999
rename ER17022 id68    //FAMILY NUMBER - id
rename ER20394 famwgt

** INCOME
rename ER20456   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER20443  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER20447 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER20449  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER20453  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER20450  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER20454  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  			// IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER17004  state   // STATE
rename ER17012  fsize   // # IN FU
rename ER17007   fchg   // family composition change since last wave
rename ER17013    age   // AGE OF HEAD (missing = 999)
rename ER17014    sex   // SEX OF HEAD
rename ER17015   agew   // AGE OF WIFE
rename ER17016   kids
rename ER17024  marit   // MARITAL STATUS
rename ER17216  empst   // WORKING NOW
rename ER17221   self   // SELF-EMPLOYED
rename ER17224 unionj   // Head's Job covered by a union contract
rename ER17225 unioni   // Head belongs to a labor union
rename ER19172 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER19614  disab   // HEAD DISABLED
rename ER19717 weight   // WEIGHT (missing = 999)
rename ER19951  newhd   // whether same head as in last wave 
rename ER19989   race   // RACE
rename ER19996    vet   // HEADS A VETERAN
rename ER20399  hours   // YRLY HEADS HRS
rename ER20451   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER20457   educ   // HEADS EDUCATION

rename ER17006  split   // has info in 01-11 (whether family a splitoff from 1968)

gen            oassinc = . // asset income of OFUM (available 2005-2011)
rename ER18634 hrentincrep
rename ER18635 hrentinctime
rename ER18650 hdividendincrep
rename ER18651 hdividendinctime
rename ER18666 hinterestincrep
rename ER18667 hinterestinctime
rename ER18683 htrustfundrep
rename ER18684 htrustfundtime
rename ER18966 wdividendincrep
rename ER18967 wdividendinctime
rename ER18982 winterestincrep
rename ER18983 winterestinctime
rename ER18998 wtrustfundrep
rename ER18999 wtrustfundtime
rename ER20423 hassbus //annual
rename ER20445 wassbus //annual
rename ER20420 hassfarm
rename ER20422 hlabbus
rename ER20444 wlabbus
//asset = sum (above)

rename ER19612 hhealth 			// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER19616 hdisabl			// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA

rename ER17538 uprevjob			// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER17091 whymoved			// 7 response to outside events, 99 DK NA, 0 has not moved
rename ER17264 change_othere	// 1 promotion, 5 change in duties,  7 other, 9 NA/DK
rename ER17311 change_samee		// 1 promotion, 5 change in duties,  7 other, 8-9 NA/DK

rename ER17391 wksworked		// 99 NA-DK. 0 Inapplicable
rename ER20405 wksolf			// check values. 0 inap.
rename ER17254 emp_tenure		// tenure with employer

drop ER*
gen year = 2001
compress
sort intid
save fam01, replace



** Process 2003 data
u family_2003

rename ER21002 intid   //interview number 1999
rename ER21009 id68    //FAMILY NUMBER - id
rename ER24179 famwgt

** INCOME
rename ER24099   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER24116  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER24135 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER24100  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER24102  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER24101  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER24103  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER21003  state   // STATE
rename ER21016  fsize   // # IN FU
rename ER21007   fchg   // family composition change since last wave
rename ER21017    age   // AGE OF HEAD (missing = 999)
rename ER21018    sex   // SEX OF HEAD
rename ER21019   agew   // AGE OF WIFE
rename ER21020   kids
rename ER21023  marit   // MARITAL STATUS
rename ER21123  empst   // WORKING NOW
rename ER21147   self   // SELF-EMPLOYED
rename ER21150 unionj   // Head's Job covered by a union contract
rename ER21151 unioni   // Head belongs to a labor union
rename ER22537 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER23014  disab   // HEAD DISABLED
rename ER23132 weight   // WEIGHT (missing = 999)
rename ER23388  newhd   // whether same head as in last wave 
rename ER23426   race   // RACE
rename ER23433    vet   // HEADS A VETERAN
rename ER24080  hours   // YRLY HEADS HRS
rename ER24137   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER24148   educ   // HEADS EDUCATION

rename ER21005  split    // has info in 01-11 (whether family a splitoff from 1968)

gen            oassinc = . // asset income of OFUM (available 2005-2011)
rename ER22003 hrentinc
rename ER22004 hrentinctime
rename ER22020 hdividendinc
rename ER22021 hdividendinctime
rename ER22037 hinterestinc
rename ER22038 hinterestinctime
rename ER22055 htrustfund
rename ER22056 htrustfundtime
rename ER22353 wdividendinc
rename ER22354 wdividendinctime
rename ER22370 winterestinc
rename ER22371 winterestinctime
rename ER22336 wrentincrep
rename ER22337 wrentinctime
rename ER22387 wtrustfund
rename ER22388 wtrustfundtime

rename ER24110 hassbus
rename ER24112 wassbus
rename ER24105 hassfarm
rename ER24109 hlabbus
rename ER24111 wlabbus
//asset = sum (above)

rename ER23009 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER23010 hhealthbtr	// 1 better, 3 same, 5 worse
rename ER21289 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER21290 hsickdays	// 998 DK, 999 NA
rename ER23016 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER21303 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER21310 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER21311 htlayoffdays	// 998 DK, 999 NA
rename ER21318 hunemp		// 998 DK, 999 NA

rename ER21184 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER21120 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER21317 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER21320 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER21322 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER24087 wksolf		// check values. 0 inap.
rename ER24085 wkslayoff
rename ER21145 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER21130 job_startyr	// start year of job 1
rename ER21171 emp_tenure	// tenure with employer

drop ER*
gen year = 2003
compress
sort intid
save fam03, replace



** Process 2005 data
u family_2005

rename ER25002 intid   //interview number 1999
rename ER25009 id68    //FAMILY NUMBER - id
rename ER28078 famwgt

** INCOME
rename ER28037   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER27931  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER27943 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER27953  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER28009  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER28002  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER28030  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER25003  state   // STATE
rename ER25016  fsize   // # IN FU
rename ER25007   fchg   // family composition change since last wave
rename ER25017    age   // AGE OF HEAD (missing = 999)
rename ER25018    sex   // SEX OF HEAD
rename ER25019   agew   // AGE OF WIFE
rename ER25020   kids
rename ER25023  marit   // MARITAL STATUS
rename ER25104  empst   // WORKING NOW
rename ER25129   self   // SELF-EMPLOYED
rename ER25138 unionj   // Head's Job covered by a union contract
rename ER25139 unioni   // Head belongs to a labor union
rename ER26518 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER26995  disab   // HEAD DISABLED
rename ER27109 weight   // WEIGHT (missing = 999)
rename ER27352  newhd   // whether same head as in last wave 
rename ER27393   race   // RACE
rename ER27400    vet   // HEADS A VETERAN
rename ER27886  hours   // YRLY HEADS HRS
rename ER28003   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER28047   educ   // HEADS EDUCATION

rename ER25005  split    // has info in 01-11 (whether family a splitoff from 1968)

rename ER27932 hrentinc
rename ER27934 hdividendinc
rename ER27936 hinterestinc
rename ER27938 htrustfund
rename ER27947 wdividendinc
rename ER27949 winterestinc
rename ER27945 wrentinc
rename ER27951 wtrustfund //no missing

rename ER28007 oassinc
rename ER27911 hassbus
rename ER27941 wassbus
rename ER27908 hassfarm
rename ER27910 hlabbus
rename ER27940 wlabbus //no missing
//asset = sum (above)

rename ER26990 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER26991 hhealthbtr	// 1 better, 3 same, 5 worse
rename ER25278 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER25279 hsickdays	// 998 DK, 999 NA
rename ER26997 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER25292 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER25299 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER25300 htlayoffdays	// 998 DK, 999 NA
rename ER25307 hunemp		// 998 DK, 999 NA

rename ER28022 workcomp		// 998 DK, 999 NA
rename ER25173 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER25101 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER25306 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER25309 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER25311 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER27893 wksolf		// check values. 0 inap.
rename ER27891 wkslayoff
rename ER25127 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER25112 job_startyr	// start year of job 1
rename ER25160 emp_tenure	// tenure with employer

drop ER*
gen year = 2005
compress
sort intid
save fam05, replace 



** Process 2007 data
u family_2007

rename ER36002 intid   //interview number 1999
rename ER36009 id68    //FAMILY NUMBER - id
rename ER41069 famwgt

** INCOME
rename ER41027   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER40921  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER40933 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER40943  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER40999  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER40992  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER41020  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER36003  state   // STATE
rename ER36016  fsize   // # IN FU
rename ER36007   fchg   // family composition change since last wave
rename ER36017    age   // AGE OF HEAD (missing = 999)
rename ER36018    sex   // SEX OF HEAD
rename ER36019   agew   // AGE OF WIFE
rename ER36020   kids
rename ER36023  marit   // MARITAL STATUS
rename ER36109  empst   // WORKING NOW
rename ER36134   self   // SELF-EMPLOYED
rename ER36143 unionj   // Head's Job covered by a union contract
rename ER36144 unioni   // Head belongs to a labor union
rename ER37536 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER38206  disab   // HEAD DISABLED
rename ER38320 weight   // WEIGHT (missing = 999)
rename ER40527  newhd   // whether same head as in last wave 
rename ER40565   race   // RACE
rename ER40572    vet   // HEADS A VETERAN
rename ER40876  hours   // YRLY HEADS HRS
rename ER40993   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER41037   educ   // HEADS EDUCATION

rename ER36005  split    // has info in 01-11 (whether family a splitoff from 1968)

rename ER40922 hrentinc
rename ER40924 hdividendinc
rename ER40926 hinterestinc
rename ER40928 htrustfund
rename ER40937 wdividendinc
rename ER40939 winterestinc
rename ER40935 wrentinc
rename ER40941 wtrustfund
rename ER40901 hassbus
rename ER40931 wassbus
rename ER40898 hassfarm
rename ER40900 hlabbus
rename ER40930 wlabbus
rename ER40997 oassinc
//asset = sum (above)

rename ER38202 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER38203 hhealthbtr	// 1 better, 3 same, 5 worse
rename ER36283 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER36284 hsickdays	// 998 DK, 999 NA
rename ER38208 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER36297 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER36304 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER36305 htlayoffdays	// 998 DK, 999 NA
rename ER36312 hunemp		// 998 DK, 999 NA

rename ER41012 workcomp		// 998 DK, 999 NA
rename ER36178 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER36106 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER36311 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER36314 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER36316 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER40883 wksolf		// check values. 0 inap.
rename ER40881 wkslayoff
rename ER36132 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER36117 job_startyr	// start year of job 1
rename ER36165 emp_tenure	// tenure with employer

drop ER*
gen year = 2007
compress
sort intid
save fam07, replace 



** Process 2009 data
u family_2009

rename ER42002 intid   //interview number 1999
rename ER42009 id68    //FAMILY NUMBER - id
rename ER47012 famwgt

** INCOME
rename ER46935   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER46829  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER46841 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER46851  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER46907  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER46900  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER46928  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER42003  state   // STATE
rename ER42016  fsize   // # IN FU
rename ER42007   fchg   // family composition change since last wave
rename ER42017    age   // AGE OF HEAD (missing = 999)
rename ER42018    sex   // SEX OF HEAD
rename ER42019   agew   // AGE OF WIFE
rename ER42020   kids
rename ER42023  marit   // MARITAL STATUS
rename ER42140  empst   // WORKING NOW
rename ER42169   self   // SELF-EMPLOYED
rename ER42178 unionj   // Head's Job covered by a union contract
rename ER42179 unioni   // Head belongs to a labor union
rename ER43527 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER44179  disab   // HEAD DISABLED
rename ER44293 weight   // WEIGHT (missing = 999)
rename ER46504  newhd   // whether same head as in last wave 
rename ER46543   race   // RACE
rename ER46550    vet   // HEADS A VETERAN
rename ER46767  hours   // YRLY HEADS HRS
rename ER46901   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER46981   educ   // HEADS EDUCATION

rename ER42005  split    // has info in 01-11 (whether family a splitoff from 1968)

rename ER46830 hrentinc
rename ER46832 hdividendinc
rename ER46834 hinterestinc
rename ER46836 htrustfund
rename ER46845 wdividendinc
rename ER46847 winterestinc
rename ER46843 wrentinc
rename ER46849 wtrustfund

rename ER46809 hassbus
rename ER46839 wassbus
rename ER46806 hassfarm
rename ER46808 hlabbus
rename ER46838 wlabbus
rename ER46905 oassinc
//asset = sum (above)

rename ER44175 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER44176 hhealthbtr	// 1 better, 3 same, 5 worse
rename ER42310 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER42311 hsickdays	// 998 DK, 999 NA
rename ER44181 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER42324 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER42331 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER42332 htlayoffdays	// 998 DK, 999 NA
rename ER42339 hunemp		// 998 DK, 999 NA

rename ER46920 workcomp		// 998 DK, 999 NA
rename ER42211 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER42135 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER42338 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER42341 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER42343 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER46780 wksolf		// check values. 0 inap.
rename ER46776 wkslayoff
rename ER42167 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER42152 job_startyr	// start year of job 1
rename ER42200 emp_tenure	// tenure with employer

drop ER*
gen year = 2009
compress
sort intid
save fam09, replace



** Process 2011 data
u family_2011

rename ER47302 intid   //interview number 1999
rename ER47309 id68    //FAMILY NUMBER - id
rename ER52436 famwgt

** INCOME
rename ER52343   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER52237  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER52249 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER52259  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER52315  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER52308  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER52336  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER47303  state   // STATE
rename ER47316  fsize   // # IN FU
rename ER47307   fchg   // family composition change since last wave
rename ER47317    age   // AGE OF HEAD (missing = 999)
rename ER47318    sex   // SEX OF HEAD
rename ER47319   agew   // AGE OF WIFE
rename ER47320   kids
rename ER47323  marit   // MARITAL STATUS
rename ER47448  empst   // WORKING NOW
rename ER47482   self   // SELF-EMPLOYED
rename ER47491 unionj   // Head's Job covered by a union contract
rename ER47492 unioni   // Head belongs to a labor union
rename ER48852 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER49498  disab   // HEAD DISABLED
rename ER49631 weight   // WEIGHT (missing = 999)
rename ER51865  newhd   // whether same head as in last wave 
rename ER51904   race   // RACE
rename ER51911    vet   // HEADS A VETERAN
rename ER52175  hours   // YRLY HEADS HRS
rename ER52309   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER52405   educ   // HEADS EDUCATION

rename ER47305  split    // has info in 01-11 (whether family a splitoff from 1968)

rename ER52238 hrentinc
rename ER52240 hdividendinc
rename ER52242 hinterestinc
rename ER52244 htrustfund
rename ER52253 wdividendinc
rename ER52255 winterestinc
rename ER52251 wrentinc
rename ER52257 wtrustfund
rename ER52217 hassbus
rename ER52247 wassbus
rename ER52214 hassfarm
rename ER52216 hlabbus
rename ER52246 wlabbus
rename ER52313 oassinc
//asset = sum (above)

rename ER49494 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER49495 hhealthbtr	// 1 better, 3 same, 5 worse
rename ER47623 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER47624 hsickdays	// 998 DK, 999 NA
rename ER49500 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER47637 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER47644 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER47645 htlayoffdays	// 998 DK, 999 NA
rename ER47652 hunemp		// 998 DK, 999 NA

rename ER52328 workcomp		// 998 DK, 999 NA
rename ER47524 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER47443 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER47651 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER47654 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER47656 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER52188 wksolf		// check values. 0 inap.
rename ER52184 wkslayoff
rename ER47479 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER47464 job_startyr	// start year of job 1
rename ER47513 emp_tenure	// tenure with employer

drop ER*
gen year = 2011
compress
sort intid
save fam11, replace


** Process 2013 data
u family_2013

rename ER53002 intid   //interview number 1999
rename ER53009 id68    //FAMILY NUMBER - id
rename ER58257 famwgt

** INCOME
rename ER58152   y      // num(7.0) : TOTAL FAMILY INCOME
rename ER58038  ly      // num(7.0) : LABOR INCOME-HEAD
rename ER58050 wly      // num(7.0) : LABOR INCOME-WIFE
rename ER58060  tyhw    // num(7.0) : HD+WF TAXABLE INCOME
rename ER58124  tyoth   // num(7.0) : OFUM TAXABLE INCOME
rename ER58117  trhw    // num(7.0) : HD+WF TRANSFER INCOME
rename ER58145  troth   // num(7.0) : OFUM TRANSFER INCOME
//ftax = .  // IMPUTE FAM INC TAX FROM y, kids USING stata taxsim9

rename ER53003  state   // STATE
rename ER53016  fsize   // # IN FU
rename ER53007   fchg   // family composition change since last wave
rename ER53017    age   // AGE OF HEAD (missing = 999)
rename ER53018    sex   // SEX OF HEAD
rename ER53019   agew   // AGE OF WIFE
rename ER53020   kids
rename ER53023  marit   // MARITAL STATUS
rename ER53148  empst   // WORKING NOW
rename ER53182   self   // SELF-EMPLOYED
rename ER53191 unionj   // Head's Job covered by a union contract
rename ER53192 unioni   // Head belongs to a labor union
rename ER54595 outkid   // SUPPORT ANYONE NOT LIVING WITH YOU
rename ER55248  disab   // HEAD DISABLED
rename ER55379 weight   // WEIGHT (missing = 999)
rename ER57618  newhd   // whether same head as in last wave 
rename ER57659   race   // RACE
rename ER57666    vet   // HEADS A VETERAN
rename ER57976  hours   // YRLY HEADS HRS
rename ER58118   avhy   // HEAD HOURLY EARN (missing = 99.99)
rename ER58223   educ   // HEADS EDUCATION

rename ER53005  split   // has info in 01-11 (whether family a splitoff from 1968)

rename ER58039 hrentinc
rename ER58041 hdividendinc
rename ER58043 hinterestinc
rename ER58045 htrustfund
rename ER58054 wdividendinc
rename ER58056 winterestinc
rename ER58052 wrentinc
rename ER58058 wtrustfund
rename ER58018 hassbus
rename ER58048 wassbus
rename ER58015 hassfarm
rename ER58017 hlabbus
rename ER58047 wlabbus
rename ER58122 oassinc
//asset = sum (above)

rename ER55244 hhealth 		// 1 excellent, 2 very good, 3 good, 4 fair, 5 poor, 8 don't know, 9 N/A
rename ER55245 hhealthbtr	// 1 better, 3 same, 5 worse, 8 don't know, 9 N/A
rename ER53323 hsick		// 1 yes, 5 no, 8 DK, 9 NA
rename ER53324 hsickdays	// 998 DK, 999 NA
rename ER55250 hdisabl		// 0 no, 1 a lot, 3 somewhat, 5 a little, 7 no, 8 DK, 9 NA
rename ER53337 hstrike		// 1 yes, 5 no, 8 DK, 9 NA
rename ER53344 htlayoff		// 1 yes, 5 no, 8 DK, 9 NA
rename ER53345 htlayoffdays	// 998 DK, 999 NA
rename ER53352 hunemp		// 998 DK, 999 NA

rename ER58137 workcomp
rename ER53224 uprevjob		// 3 laid off, 4 quit, 8 completed, 9 NA
rename ER53143 whymoved		// 7 response to outside events, 99 DK NA, 0 has not moved

rename ER53351 wtrunemp		// 8-9 DL-NA. 0 inapplicable
rename ER53354 wksunemp1	// 98-99 DL-NA. 0 inapplicable
rename ER53356 monthsunemp	// 98-99 DL-NA. 0 inapplicable
rename ER57989 wksolf		// check values. 0 inap.
rename ER57985 wkslayoff
rename ER53179 hocc			// head's occupation for job 1 999: DK/NA 0 inapp.
rename ER53164 job_startyr	// start year of job 1
rename ER53213 emp_tenure	// tenure with employer

drop ER*
gen year = 2013
compress
sort intid
save fam13, replace


** Combine years
use fam99, clear
append using fam01
append using fam03
append using fam05
append using fam07
append using fam09
append using fam11
append using fam13

order intid year
save family_combined, replace

erase fam99.dta
erase fam01.dta
erase fam03.dta
erase fam05.dta
erase fam07.dta
erase fam09.dta
erase fam11.dta
erase fam13.dta

log close
