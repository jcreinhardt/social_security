capture program drop autocov_wide
program autocov_wide
	//	syntax [varlist] [if]
	preserve
	local varM="`1'"
	local begin="`2'"
	local end="`3'"
	local nlag=`end'-`begin'+1
	
	matrix covmat = J(`nlag',`nlag', .)
	
	forvalues h=`begin'/`end'{
		local i=`h'-`begin'+1
		forvalues n=`h'/`end'{
			local j=`i'+`n'-`h'
			qui correlate `varM'`h' `varM'`n', covariance
			matrix covmat[`i',`j'] = r(cov_12)
		}
	}

	drop _all
	svmat covmat,names(n)
	save autocovmat_`varM'_`begin'_`end'.dta, replace		
	outsheet using autocovmat_`varM'_`begin'_`end'.txt, replace

end
