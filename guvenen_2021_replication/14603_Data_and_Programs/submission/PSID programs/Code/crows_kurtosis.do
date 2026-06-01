cap prog drop crows_kurtosis
program define crows_kurtosis, rclass
**Calculation of moor's kurtosis
*Inputs - 1) Variable of interest
*         2) Any restrictions (form of "if ...") or weights

_pctile `1' `2', percentile(2.5(2.5)97.5)
*_pctile `1' `2', percentile(12.5(12.5)87.5)
   foreach num of numlist 1/39{
      local c_`num'=r(r`num')
   }
   local crows_kurtosis = (`c_39'-`c_1')/(`c_30'-`c_10')
   local crows_kurtosis: disp %5.4g `crows_kurtosis'
   return scalar m = `crows_kurtosis'
end
   
