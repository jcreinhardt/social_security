cap prog drop moors_kurtosis
program define moors_kurtosis, rclass
**Calculation of moor's kurtosis
*Inputs - 1) Variable of interest
*         2) Any restrictions (form of "if ...") or weights

*centile `1' `2', centile(12.5(12.5)100)
_pctile `1' `2', percentile(12.5(12.5)87.5)
   foreach num of numlist 1/8{
      *local c_`num'=r(c_`num')
      local c_`num'=r(r`num')
   }
   local moors_kurtosis = ((`c_7'-`c_5')+(`c_3'-`c_1'))/(`c_6'-`c_2')
   local moors_kurtosis: disp %5.4g `moors_kurtosis'
   return scalar m = `moors_kurtosis'
end
   
