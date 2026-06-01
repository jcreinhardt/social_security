"""
moments_from_data.py
====================
Python translation of moments_from_data.f90

Reads simulated income panel data (CSV, income in levels, 0 = nonemployed)
and computes the same moments as the MOMENTS subroutine in OBJECTIVE.f90.

INPUT:
    simulated_guv_data.csv
        - 50000 individuals x 36 ages (inc_25 ... inc_60)
        - Values in LEVELS, units = thousands of dollars (0.0 = nonemployed)
        - Age h=1 maps to calendar age 25; h=36 maps to age 60
        - RMINWAGE=1.5 (=$1500/yr) cleanly separates employed from non-employed

OUTPUTS (CSV files):
    SdSkewKurt_L1_sim.csv   cross-sect moments, 1-yr changes  (3 x 13 x 3)
    SdSkewKurt_L5_sim.csv   cross-sect moments, 5-yr changes  (3 x 13 x 3)
    irmoments_sim.csv       impulse response moments           (2 x 8 x 10 x 6)
    incgrwth_sim.csv        lifetime income growth             (15 x 8)
    var_lny_sim.csv         variance of log income by age      (36)
    EmpCDF_sim.csv          employment CDF                     (37)
"""

import numpy as np
import pandas as pd
from scipy import stats

# ============================================================================
# PARAMETERS (match Fortran exactly)
# ============================================================================
NSIM   = 50000
HMAX   = 36
NVASEINC = 13
NVASEMNT = 3
NIRINC   = 8
NIRCHG   = 10
NLAG     = 5
NLTINCPCT= 15
LTH      = 8
EMPCDF_NUM = HMAX + 1
MINOBS  = 3
MINEMP  = 15

RMINWAGE   = 1.5
DPMISSING  = 1.0e15

# Percentile bin boundaries
VASEINCPCT   = np.array([1,2,11,21,31,41,51,61,71,81,91,96,100,101])
IRAVGINCPCT  = np.array([1,6,11,31,51,71,91,96,101])
IRCHGPCT     = np.array([1,3,6,11,31,51,71,91,96,99,101])
LTINCPCT     = np.array([1,2,6,11,21,31,41,51,61,71,81,91,96,98,100,101])

NAGEBIN = np.array([2,2,2])
AGEBINL = np.array([1,9,19]) - 1  # Convert to 0-indexed

# Diff arrays for arc percent change calculations
DF1 = np.array([2,6,1,2,3,4,6,11]) - 1  # Convert to 0-indexed offsets
DF2 = np.array([1,1,0,0,0,0,0,0]) - 1

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def mean_var_miss(income):
    """
    Calculate mean and variance of log income, treating values < RMINWAGE as missing.
    Returns: (mean, variance)
    """
    valid = income >= RMINWAGE
    if np.sum(valid) < 2:
        return 0.0, 0.0
    
    log_income = np.log(income[valid])
    return np.mean(log_income), np.var(log_income, ddof=1)

def mean_miss(x):
    """Mean ignoring DPMISSING values."""
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) == 0:
        return 0.0
    return np.mean(x[valid])

def demean_col(x):
    """Demean a column in-place, ignoring DPMISSING values."""
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) > 0:
        x[valid] = x[valid] - np.mean(x[valid])

def sdskewkurt_miss(x):
    """
    Calculate standard deviation, skewness, and excess kurtosis,
    ignoring DPMISSING values.
    Returns: (sd, skew, kurt)
    """
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) < 2:
        return 0.0, 0.0, 0.0
    
    x_valid = x[valid]
    sd = np.std(x_valid, ddof=1)
    
    if sd == 0:
        return sd, 0.0, 0.0
    
    # Skewness and kurtosis using scipy
    skew = stats.skew(x_valid, bias=False)
    kurt = stats.kurtosis(x_valid, bias=False)  # excess kurtosis
    
    return sd, skew, kurt

def sortrows_col1(a):
    """
    Sort rows of 2D array by column 0 (ascending).
    DPMISSING values pushed to end.
    Returns: (sorted_array, nonmiss_count)
    """
    # Separate valid and missing rows
    valid_mask = a[:, 0] < (DPMISSING - 1.0)
    nonmiss = np.sum(valid_mask)
    
    valid_rows = a[valid_mask]
    invalid_rows = a[~valid_mask]
    
    # Sort valid rows by column 0
    sort_idx = np.argsort(valid_rows[:, 0])
    sorted_valid = valid_rows[sort_idx]
    
    # Concatenate
    if len(invalid_rows) > 0:
        result = np.vstack([sorted_valid, invalid_rows])
    else:
        result = sorted_valid
    
    return result, nonmiss

# ============================================================================
# MAIN MOMENTS CALCULATION
# ============================================================================

def calculate_moments(ysim_in):
    """
    Main MOMENTS subroutine - faithful translation from Fortran.
    
    Args:
        ysim_in: (nsim, hmax) array of income in levels
    
    Returns:
        Dictionary containing all moment arrays
    """
    nsim, hmax = ysim_in.shape
    
    # Initialize outputs
    SSK_L1 = np.zeros((3, NVASEINC, NVASEMNT))
    SSK_L5 = np.zeros((3, NVASEINC, NVASEMNT))
    irm = np.zeros((2, NIRINC, NIRCHG, NLAG+1))
    incg = np.zeros((NLTINCPCT, LTH))
    varlny = np.zeros(hmax)
    ecdf = np.zeros(EMPCDF_NUM)
    
    # ── A. Age dummies and variance of log income ──────────────────────────
    agedum = np.zeros(hmax)
    avgagedum = np.zeros(hmax)
    
    for h in range(hmax):
        agedum[h], varlny[h] = mean_var_miss(ysim_in[:, h])
    
    # Convert agedum to levels (it's currently in log space)
    agedum = np.exp(agedum)
    
    # Calculate rolling average of age dummies
    for h in range(hmax):
        count = min(h + 1, 5)
        avgagedum[h] = np.mean(agedum[max(0, h-4):h+1])
    
    # ── B. Build longdata array ────────────────────────────────────────────
    # Ages h=3..30 in Fortran (0-indexed: 2..29), but capped at hmax
    NLONG = min(28, hmax - 2)
    longdata = np.full((nsim * NLONG, 9), DPMISSING)
    
    for h in range(2, min(30, hmax)):
        lb = (h - 2) * nsim
        ub = (h - 1) * nsim
        
        # ── Average past income (normalized) ──
        numobs = np.zeros(nsim, dtype=int)
        avgpastinc = np.zeros(nsim)
        
        # Initialize: if current income < RMINWAGE, set numobs = -5
        numobs[ysim_in[:, h] < RMINWAGE] = -5
        
        # Sum income over last min(h+1, 5) years
        for j in range(min(h + 1, 5)):
            avgpastinc += np.maximum(ysim_in[:, h - j], RMINWAGE)
            numobs[ysim_in[:, h - j] >= RMINWAGE] += 1
        
        # Normalize and filter by MINOBS
        valid = numobs >= MINOBS
        avgpastinc[valid] = avgpastinc[valid] / (min(h + 1, 5) * avgagedum[h])
        avgpastinc[~valid] = DPMISSING
        
        longdata[lb:ub, 0] = avgpastinc
        
        # ── Arc percent changes at various horizons ──
        for j in range(8):
            h_fut = h + DF1[j] + 1  # +1 because DF1 is 0-indexed offset
            h_base = h + DF2[j] + 1
            
            if h_fut < hmax:
                y_base = ysim_in[:, h_base] / agedum[h_base]
                y_fut  = ysim_in[:, h_fut] / agedum[h_fut]
                
                valid_both = (ysim_in[:, h_base] >= RMINWAGE) | (ysim_in[:, h_fut] >= RMINWAGE)
                
                arc_chg = np.full(nsim, DPMISSING)
                arc_chg[valid_both] = (
                    2.0 * (y_fut[valid_both] - y_base[valid_both]) /
                    (y_fut[valid_both] + y_base[valid_both])
                )
                
                longdata[lb:ub, 1 + j] = arc_chg
        
        # ── Demean IR changes (cols 4..9 = indices 3..8) ──
        for l in range(NLAG + 1):
            if h + DF1[2 + l] + 1 < hmax:
                demean_col(longdata[lb:ub, 3 + l])
    
    # ── C. Cross-sectional moments SSK_L1, SSK_L5 ──────────────────────────
    for i in range(3):  # age groups
        for nh in range(NAGEBIN[i]):
            # Identify block in longdata
            if i == 0:
                if nh == 0:
                    lb, ub = 0, 3 * nsim
                else:
                    lb, ub = 3 * nsim, 8 * nsim
            else:
                hstart = AGEBINL[i] + 5 * nh
                lb = hstart * nsim
                ub = lb + 5 * nsim
            
            if ub > len(longdata):
                continue
            
            # Sort on avg past income, keep cols 1 and 2 (arc changes)
            temp = longdata[lb:ub, 0:3].copy()
            temp, nonmiss = sortrows_col1(temp)
            
            for j in range(NVASEINC):
                lb2 = int(np.floor(nonmiss * (VASEINCPCT[j] - 1) / 100))
                ub2 = min(int(np.floor(nonmiss * (VASEINCPCT[j+1] - 1) / 100)), nonmiss - 1)
                
                if ub2 > lb2:
                    ssk = sdskewkurt_miss(temp[lb2:ub2+1, 1])
                    ssk5 = sdskewkurt_miss(temp[lb2:ub2+1, 2])
                    
                    SSK_L1[i, j, :] += np.array(ssk) / NAGEBIN[i]
                    SSK_L5[i, j, :] += np.array(ssk5) / NAGEBIN[i]
    
    # ── D. Impulse response moments ────────────────────────────────────────
    for i in range(2):  # age groups
        if i == 0:
            lb, ub = 0, 8 * nsim
        else:
            lb = 8 * nsim
            ub = min(23 * nsim, len(longdata))
        
        if ub <= lb:
            continue
        
        # Sort on avg past income; keep cols 4..9 (IR changes)
        temp = np.column_stack([
            longdata[lb:ub, 0],
            longdata[lb:ub, 3:9]
        ])
        temp, nonmiss = sortrows_col1(temp)
        
        for j in range(NIRINC):
            lb2 = int(np.floor(nonmiss * (IRAVGINCPCT[j] - 1) / 100))
            ub2 = min(int(np.floor(nonmiss * (IRAVGINCPCT[j+1] - 1) / 100)), nonmiss - 1)
            
            if ub2 <= lb2:
                continue
            
            # Within income group, sort on impact change (col 1 of temp2)
            temp2 = temp[lb2:ub2+1, 1:7].copy()
            temp2, nonmiss2 = sortrows_col1(temp2)
            
            for k in range(NIRCHG):
                lb3 = int(np.floor(nonmiss2 * (IRCHGPCT[k] - 1) / 100))
                ub3 = min(int(np.floor(nonmiss2 * (IRCHGPCT[k+1] - 1) / 100)), nonmiss2 - 1)
                
                if ub3 > lb3:
                    for l in range(NLAG + 1):
                        irm[i, j, k, l] = mean_miss(temp2[lb3:ub3+1, l])
    
    # ── E. Lifetime income growth ──────────────────────────────────────────
    emp = np.zeros(nsim, dtype=int)
    LTinc = np.zeros((nsim, LTH + 1))
    jj = 0
    
    for h in range(hmax):
        LTinc[:, 0] += np.maximum(ysim_in[:, h], RMINWAGE)
        emp[ysim_in[:, h] >= RMINWAGE] += 1
        
        if (h % 5 == 0) and (jj < LTH):
            LTinc[:, 1 + jj] = np.maximum(ysim_in[:, h], RMINWAGE)
            jj += 1
    
    LTinc[:, 0] = LTinc[:, 0] / hmax
    LTinc[emp < MINEMP, 0] = DPMISSING
    
    # Employment CDF
    for i in range(EMPCDF_NUM - 1):
        ecdf[i] = 100.0 * np.sum(emp <= i) / nsim
    ecdf[-1] = 100.0
    
    # Sort on lifetime income
    temp_lt = LTinc.copy()
    temp_lt, nonmiss = sortrows_col1(temp_lt)
    
    for j in range(NLTINCPCT):
        lb = int(np.floor(nonmiss * (LTINCPCT[j] - 1) / 100))
        ub = min(int(np.floor(nonmiss * (LTINCPCT[j+1] - 1) / 100)), nonmiss - 1)
        
        for h in range(LTH):
            if ub > lb:
                incg[j, h] = mean_miss(temp_lt[lb:ub+1, h+1])
    
    return {
        'SdSkewKurt_L1': SSK_L1,
        'SdSkewKurt_L5': SSK_L5,
        'irmoments': irm,
        'incgrwth': incg,
        'var_lny': varlny,
        'EmpCDF': ecdf
    }

# ============================================================================
# OUTPUT FUNCTIONS
# ============================================================================

def write_sdskkurt(arr, filename):
    """Write SdSkewKurt array to CSV."""
    age_labels = ['YNG', 'MID', 'OLD']
    moment_labels = ['sd', 'skew', 'kurt']
    
    rows = []
    for i in range(3):
        for j in range(NVASEINC):
            for k in range(NVASEMNT):
                rows.append({
                    'age_group': age_labels[i],
                    'income_bin': j + 1,
                    'moment': moment_labels[k],
                    'value': arr[i, j, k]
                })
    
    df = pd.DataFrame(rows)
    df.to_csv(filename, index=False)
    print(f"  Written: {filename}")

def write_irmoments(arr, filename):
    """Write impulse response moments to CSV."""
    rows = []
    for i in range(2):
        for j in range(NIRINC):
            for k in range(NIRCHG):
                for l in range(NLAG + 1):
                    rows.append({
                        'age_group': i + 1,
                        'income_bin': j + 1,
                        'shock_bin': k + 1,
                        'lag': l + 1,
                        'value': arr[i, j, k, l]
                    })
    
    df = pd.DataFrame(rows)
    df.to_csv(filename, index=False)
    print(f"  Written: {filename}")

def write_2d(arr, filename):
    """Write 2D array to CSV."""
    nrows, ncols = arr.shape
    rows = []
    for i in range(nrows):
        for j in range(ncols):
            rows.append([i + 1, j + 1, arr[i, j]])
    
    df = pd.DataFrame(rows, columns=['i', 'j', 'value'])
    df.to_csv(filename, index=False, header=False)
    print(f"  Written: {filename}")

def write_1d(arr, filename):
    """Write 1D array to CSV."""
    rows = []
    for i, val in enumerate(arr):
        rows.append([i + 1, val])
    
    df = pd.DataFrame(rows, columns=['i', 'value'])
    df.to_csv(filename, index=False, header=False)
    print(f"  Written: {filename}")

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("Reading simulated_guv_data.csv ...")
    df = pd.read_csv('simulated_guv_data.csv')
    ysim = df.values
    
    print(f"Data loaded:  NSIM={ysim.shape[0]}  HMAX={ysim.shape[1]}")
    
    print("\nCalculating moments ...")
    moments = calculate_moments(ysim)
    
    print("\nWriting output CSV files ...")
    write_sdskkurt(moments['SdSkewKurt_L1'], 'SdSkewKurt_L1_sim.csv')
    write_sdskkurt(moments['SdSkewKurt_L5'], 'SdSkewKurt_L5_sim.csv')
    write_irmoments(moments['irmoments'], 'irmoments_sim.csv')
    write_2d(moments['incgrwth'], 'incgrwth_sim.csv')
    write_1d(moments['var_lny'], 'var_lny_sim.csv')
    write_1d(moments['EmpCDF'], 'EmpCDF_sim.csv')
    
    print("\nAll output files written.")
