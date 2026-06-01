from guv_model import model
import numpy as np
import pandas as pd

def guv_to_toolbox(income_array):
    # constants
    STARTING_AGE = 25
    MIN_EARNINGS = 1.885 # 2013 minimum earnings: 13*40*7.25*0.5

    n_workers, T = income_array.shape

    ages = np.arange(STARTING_AGE, STARTING_AGE + T)
    ages_long = np.tile(ages, n_workers) # tiles ages for all workers

    id = np.arange(0, n_workers)
    id_long = np.repeat(id, T) # repeats id for T years for workers 

    # cohort = np.random.randint(1960, 1996, n_workers)
    cohort = np.repeat(1970, n_workers)
    cohort_long = np.repeat(cohort, T) # repeats cohorts for T years for workers

    # gender =  np.random.randint(0, 2, n_workers)
    gender = np.repeat(0, n_workers)
    gender_long = np.repeat(gender, T) # repeats gender for T years for workers 

    year_long = cohort_long + ages_long

    earnings_long = income_array.reshape(-1)

    y_min_long = np.repeat(MIN_EARNINGS, T * n_workers)

    # only takes log of earnings over minimum
    mask = earnings_long > MIN_EARNINGS
    log_earnings = np.full_like(earnings_long, np.nan, dtype=float)
    log_earnings[mask] = np.log(earnings_long[mask])

    output_df = pd.DataFrame({"ID": id_long,
                            "REAL_WAGE": earnings_long, 
                            "LOG_WAGE": log_earnings,
                            "YEAR": year_long,
                            "AGE": ages_long,
                            "COHORT": cohort_long,
                            "SEX": gender_long,
                            "Y_MIN": y_min_long})
    
    return output_df