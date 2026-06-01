 -----------------------------------
 1. About the program
 -----------------------------------
- The main program used to estimate the benchmark income process described in Section 6 of Guvenen, Karahan, Ozkan and Song 2021, ECMA.
- TikTak algorithm is used as multi-start global optimization algorithm. For more information for this algorithm visit https://github.com/serdarozkan/TikTak#tiktak.
- Great care was taken to make it as compliant with Fortran 90 as possible, but there may be a couple of invocations to Fortran 95 intrinsics.
- We run this code with Intel fortran compiler on MacOs and Unix environment. We provide the makefile that is used to compile the program. 
- For all bugs please contact yfkarahan@gmail.com or serdarozkan@gmail.com.

 -----------------------------------
 2. Description of Fortran source files
 -----------------------------------
|  ESTIMATE.f90 |  the main driver program for the multi-start global optimization algorithm.
|  utilities.f90  |  implementation of Sobol and other helper functions.
|  DFNLS.f90 	  |  open source code for DFNLS algorithm used in local minimization
|  OBJECTIVE.f90  |  this file defines the benchmark income process along with the specific objective function being solved. Require the following functions to be defined: objFun, dfovec, obj_initialize, diagnostic. All model specific parameters are also defined within this file.

In order to adopt the estimation code for other income processes the user needs to modify the SIMULATE SUBROUTINE in OBJECTIVE.f90, specifically, lines between 482 and 567. 

 -----------------------------------
 3. Description of text files
 -----------------------------------

|  initterm.txt |  the value in this file should be set to 1 if the estimations starts from the beginning (cold starts).
|  Makefile 	|   Makefile used for compiling the fortran code
|  Readme.txt |   Instructions for using the code.
|  param_diagnostic.dat |   Initial set of parameters used in the estimation or for diagnostic purposes. This file currently contains our final estimate for the parameters of the benchmark process as we start with an uneducated guess in our estimation. 

 -----------------------------------
 4. Input files for Targeted Moments
 -----------------------------------

| SdSkewKurt_L1.dat |  This file contains the cross-sectional moments of 1-year arc percent growth that are targeted in the estimation.  
| SdSkewKurt_L5.dat |  This file contains the cross-sectional moments of 5-year arc percent growth that are targeted in the estimation.  
| ImpulseA_mean.dat |  This file contains the impulse response moments that are targeted in the estimation.  
| meanLTinc_level.dat |  This file contains the lifetime income growth moments that are targeted in the estimation.  
| var_lny.dat |  This file contains the within cohort variance of log earnings that are targeted in the estimation.  
| EmpCDF.dat |  This file contains the lifetime employment moments that are targeted in the estimation. 

See Appendix D.1. for a detailed explanation of how we constructed these moments. 

 -----------------------------------
 5. Other Input files
 -----------------------------------

All other files with extension .dat are used as input in the code but they are not used in the estimation. Do not change them.

 -----------------------------------
 6. Options in the ESTIMATE.f90
 -----------------------------------

 -- rundiagnostic: If =1, the code simulates the income process for the given set of parameter values (in param_diagnostic.dat) and generate many moments that are used in the estimation as well as diagnostic purposes.
 -- runbootstrap: If =1, the code estimates parametric bootstrap standard errors for parameter estimates.
 -- runcovar: If =1, the code will generate variance-covariance matrix from the income process for both levels and 1-year growth rates of log earnings.
 -- plot_obj: If =1, the code generates output to plot the objective function around the given set of s (in param_diagnostic.dat).

	If above parameters are set to zero, then the code will run the global search algorithm to estimate the income process.
