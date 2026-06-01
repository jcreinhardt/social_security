cap prog drop kelly_skewness
program define kelly_skewness, rclass
**Calculation of kelly skewness
*Inputs - 1) Variable of interest
*         2) Any restrictions (form of "if ...") or weights

   sum `1' `2', d	
   local kelly_skewness = (r(p90)-2*r(p50)+r(p10))/(r(p90)-r(p10))
   local kelly_skewness: disp %5.2g `kelly_skewness'
   return scalar k = `kelly_skewness'
end
   
