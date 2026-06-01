import numpy as np
import pandas as pd
import scipy
import scipy.stats

import a01_parameters

# Define percentiles functions for Guvenen's percentiles
def p10(x): return np.percentile(x, 10, method='inverted_cdf')
def p25(x): return np.percentile(x, 25, method='inverted_cdf')
def p50(x): return np.percentile(x, 50, method='inverted_cdf')
def p75(x): return np.percentile(x, 75, method='inverted_cdf')
def p90(x): return np.percentile(x, 90, method='inverted_cdf')
def p98(x): return np.percentile(x, 98, method='inverted_cdf')

# Define moments on log of real wages
def meanlog(x): return np.mean(x)
def sdlog(x): return np.std(x, ddof=1)  # Stata uses sample std dev
def skewlog(x): return scipy.stats.skew(x)
# By default, scipy kurtosis is excess kurtosis, so I explicitly set fisher=False to get the raw kurtosis
def kurtlog(x): return scipy.stats.kurtosis(x, fisher=False)

def toolbox(data, cohort, ages, sex, real_wage_summary, log_wage_summary):
    """A function used to calculate moments and percentiles for each cohort, age, sex group

    Guvenen calculates the following moments and percentiles:
    - mean log, std log, skew log, kurt log, 10th, 25th, 50th, 75th, 90th, 98th percentiles
    
    arguments:
    - data: dataframe which contains individuals, their real incomes, log real incomes, year, age, cohort, sex
    - cohort: list of cohorts to include
    - ages: list of ages to include
    - sex: list of sexes to include
    - real_wage_summary: list of real wage summary statistics to include, names of functions to apply to real wages
    - log_wage_summary: list of log wage summary statistics to include, names of functions to apply to log wages

    returns:
    - a dataframe with moments and percentiles for each group that Guvenen uses
    """  

    # Filter data using isin() method for multiple values
    data_relevant = data[data['COHORT'].isin(cohort)]
    data_relevant = data_relevant[data_relevant['AGE'].isin(ages)]
    data_relevant = data_relevant[data_relevant['SEX'].isin(sex)]

    # Group by multiple columns 
    data_groups = data_relevant.groupby(['COHORT', 'AGE', 'SEX'])

    # Calculate percentiles for each group
    percentiles = data_groups['REAL_WAGE'].agg(real_wage_summary)

    # Calculate moments for each group
    moments = data_groups['LOG_WAGE'].agg(log_wage_summary)

    # Get counts for each group
    counts = data_groups.size().reset_index()
    
    moments = moments.reset_index()
    percentiles = percentiles.reset_index()

    results = counts.merge(moments, on=['COHORT', 'AGE', 'SEX'], how='left')
    results = results.merge(percentiles, on=['COHORT', 'AGE', 'SEX'], how='left')

    # Rename columns
    results = results.rename(columns={0: 'COUNT'})

    return results

# Helpers: normalization, ARC percent change, recent earnings, binning
def age_year_mean(df, age_col="AGE", time_col="YEAR", y_col="REAL_WAGE"):
    """
    Compute mean earnings for each (YEAR, AGE)
    """
    return df.groupby([time_col, age_col])[y_col].transform("mean")

def normalize_earnings(df, age_col="AGE", time_col="YEAR", y_col="REAL_WAGE"):
    """
    Compute Y_it = Y~_it / d~_{t,h}
    """
    d_th = age_year_mean(df, age_col, time_col, y_col)
    return df[y_col] / d_th

import numpy as np

# Slide 9
def arc_percent_change(y_t, y_tk):
    """
    arc percent change.
    """
    denom = (y_tk + y_t) / 2
    out = (y_tk - y_t) / denom
    out = np.where(denom == 0, np.nan, out)
    return out

import pandas as pd

# Slide 10
def compute_recent_earnings(
    df,
    id_col="ID",
    time_col="YEAR",
    y_col="REAL_WAGE",
    ymin_col="Y_MIN",
    window=5
):
    """
    Compute Guvenen's recent earnings:
    
    Ŷ_{i,t-1} = (1/5) * sum_{j=1}^5 max{ Y_{i,t-j}, Y_min,t }
    
    Assumes:
    - df contains one row per (ID, YEAR)
    - ymin_col is Y_min,t (time-t specific floor based on min wage)
    """
    
    df = df.sort_values([id_col, time_col]).copy()
    
    past_wages = []
    for j in range(1, window + 1):
        lag = df.groupby(id_col)[y_col].shift(j)
        past_wages.append(np.maximum(lag, df[ymin_col]))
    
    df[f"RECENT_EARNINGS_{window}"] = np.nanmean(
        np.column_stack(past_wages),
        axis=1
    )
    
    return df

def five_year_age_mean(df, age_col="AGE", time_col="YEAR", y_col="REAL_WAGE", window=5):
    """
    5-year age-year means.
    """
    d = (
        df.groupby([time_col, age_col])[y_col]
          .mean()
          .reset_index(name="d")
          .sort_values([age_col, time_col])
    )
    
    d["d_new"] = (
        d.groupby(age_col)["d"]
         .transform(lambda x: x.rolling(window, min_periods=1).mean())
    )
    
    return df.merge(
        d[[time_col, age_col, "d_new"]],
        on=[time_col, age_col],
        how="left"
    )["d_new"]

def normalize_recent_earnings(df, re_col, age_col="AGE", time_col="YEAR", y_col="REAL_WAGE"):
    d_ht = five_year_age_mean(df, age_col, time_col, y_col)
    return df[re_col] / d_ht

# Slide 11
def rank_within_age_bin(df, value_col, age_col="AGE"):
    """
    Assign percentile ranks within each age bin.
    """
    return df.groupby(age_col)[value_col].rank(pct=True)

def earnings_bins(df, rank_col, n_bins=5):
    """
    Convert percentile ranks into bins.
    """
    return pd.cut(
        df[rank_col],
        bins=np.linspace(0, 1, n_bins + 1),
        labels=False,
        include_lowest=True
    )

# Helpers: ARC change moments and merging
def arc_change(y_now, y_lag):
    denom = y_now + y_lag
    out = 200.0 * (y_now - y_lag) / denom
    out = np.where(denom == 0, np.nan, out)
    return out


def sd_arc(x):
    return np.std(x, ddof=1)


def skew_arc(x):
    return scipy.stats.skew(x, bias=False, nan_policy="omit")


def kurt_arc(x):
    return scipy.stats.kurtosis(x, fisher=False, bias=False, nan_policy="omit")


def add_arc(df, h, id_col="ID", time_col="YEAR", y_col="REAL_WAGE"):
    df = df.sort_values([id_col, time_col]).copy()
    y_lag = df.groupby(id_col)[y_col].shift(h)
    df[f"ARC_G{h}"] = arc_change(df[y_col].to_numpy(), y_lag.to_numpy())
    return df


def arc_moments(group_df, h):
    g = group_df[f"ARC_G{h}"].to_numpy()
    g = g[~np.isnan(g)]
    if g.size < 3:
        return pd.Series({
            f"arc{h}_sd": np.nan,
            f"arc{h}_skew": np.nan,
            f"arc{h}_kurt": np.nan,
            f"arc{h}_n": g.size,
        })
    return pd.Series({
        f"arc{h}_sd": sd_arc(g),
        f"arc{h}_skew": skew_arc(g),
        f"arc{h}_kurt": kurt_arc(g),
        f"arc{h}_n": g.size,
    })


def merge_arc_moments(data, results, cohort, ages, sex, id_col="ID", time_col="YEAR", y_col="REAL_WAGE"):
    data_relevant = data[data['COHORT'].isin(cohort)]
    data_relevant = data_relevant[data_relevant['AGE'].isin(ages)]
    data_relevant = data_relevant[data_relevant['SEX'].isin(sex)]

    tmp = data_relevant.copy()
    tmp = add_arc(tmp, h=1, id_col=id_col, time_col=time_col, y_col=y_col)
    tmp = add_arc(tmp, h=5, id_col=id_col, time_col=time_col, y_col=y_col)

    arc1 = tmp.groupby(['COHORT', 'AGE', 'SEX']).apply(lambda g: arc_moments(g, 1)).reset_index()
    arc5 = tmp.groupby(['COHORT', 'AGE', 'SEX']).apply(lambda g: arc_moments(g, 5)).reset_index()

    results = results.merge(arc1, on=['COHORT', 'AGE', 'SEX'], how='left')
    results = results.merge(arc5, on=['COHORT', 'AGE', 'SEX'], how='left')
    return results
