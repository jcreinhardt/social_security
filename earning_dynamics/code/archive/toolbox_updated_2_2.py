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

# (3) Impulse Response target moments, slide 13
# ---------------------------------------------------------------------
# First, we create a helper function to clean the data into 2 * 8 * 23 bins.
def impulse_response_bins(
    df,
    age_col="AGE",
    wage_col="REAL_WAGE", 
    recent_earnings_col="RECENT_EARNINGS_5",
    arc_1yr_col="ARC_CHANGE_1YR"
):
    
    df = df.copy()
    
    # 1. Age groups: young (25-34), prime (35-55)
    df['AGE_GROUP'] = pd.cut(
        df[age_col],
        bins=[24, 34, 55], 
        labels=['YOUNG', 'PRIME']
    )

    df = df[df['AGE_GROUP'].notna()]
    
    # 2. Recent Earnings groups (8 percentile groups)
    # Groups: 1-5, 6-10, 11-30, 31-50, 51-70, 71-90, 91-95, 96-100
    def assign_re_groups(group):
        return pd.qcut(
            group[recent_earnings_col],
            q=[0, 0.05, 0.10, 0.30, 0.50, 0.70, 0.90, 0.95, 1.0],
            labels=range(1, 9),
            duplicates='drop'
        )
    df['RE_GROUP'] = df.groupby('AGE_GROUP', group_keys=False).apply(assign_re_groups)
    
    # 3. Past growth bins: 23 groups total
    # Group 0: Nonemployed (wage = 0 or missing)
    # Groups 1-22: Percentile bins of past growth for employed
    df['GROWTH_GROUP'] = 0 
    nonemployed_mask = (df[wage_col] <= 0) | df[wage_col].isna()
    employed = df[~nonemployed_mask].copy()
    percentiles = [0, 0.02, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 
                   0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 
                   0.90, 0.95, 0.98, 1.0]
    employed['GROWTH_GROUP'] = pd.qcut(
        employed[arc_1yr_col],
        q=percentiles,
        labels=range(1, 23),
        duplicates='drop'
    )
    df.loc[employed.index, 'GROWTH_GROUP'] = employed['GROWTH_GROUP']

    return df

# We also need a helper to figure out the arc cent growth in individuals' next 1/2/3/5/10 years.

def horizon_response(
    df,
    id_col="ID",
    time_col="YEAR",
    y_col="REAL_WAGE",
    horizons=[1, 2, 3, 5, 10]
):
    df = df.sort_values([id_col, time_col]).copy()
    for k in horizons:
        y_tk = df.groupby(id_col)[y_col].shift(-k)
        df[f'ARC_CHANGE_{k}YR'] = arc_change(y_tk, df[y_col])
    return df

# Then, we calculate the moment for each bin.
# The dataframe returned should be of these columns: AGE_GROUP (2), RE_GROUP (8), 
# GROWTH_GROUP (23), and the actual moment (4 for each bin given four horizons).
# The formula for the moment is E[Δ^{k}Y_{t+1}^i | age, recent earnings, Δ¹Y_{t-1}^i].
def impulse_response_moments(
    df,
    horizons=[1, 2, 3, 5, 10],
    age_col="AGE",
    wage_col="REAL_WAGE", 
    recent_earnings_col="RECENT_EARNINGS_5",
    arc_1yr_col="ARC_CHANGE_1YR",
    id_col="ID",
    time_col="YEAR", 
    y_col="REAL_WAGE"
):
    
    # 1. First create the bins using the function we already have
    df_binned = impulse_response_bins(
        df, age_col, wage_col, recent_earnings_col, arc_1yr_col
    )
    df_binned = horizon_response(df_binned, id_col, time_col, y_col, horizons)
    grouped = df_binned.groupby(['AGE_GROUP', 'RE_GROUP', 'GROWTH_GROUP'])
    
    # 2. Compute moments for each group
    results = []
    
    for (age_group, re_group, growth_group), bin_df in grouped:
        
        avg_past_growth = bin_df[arc_1yr_col].mean()
        
        horizon_growths = {}
        for k in horizons:
            future_col = f"ARC_CHANGE_{k}YR" 
            avg_future_growth = bin_df[future_col].mean()
            horizon_growths[f'FUTURE_{k}YR'] = avg_future_growth
        
        # Compute the moment: E[Δ^{k}Y_{t+1}^i] - E[Δ¹Y_{t-1}^i]
        impulse_responses = {}
        for k in horizons:
            future_key = f'FUTURE_{k}YR'
            if not np.isnan(horizon_growths[future_key]) and not np.isnan(avg_past_growth):
                impulse = horizon_growths[future_key] - avg_past_growth
            else:
                impulse = np.nan
            impulse_responses[f'IMPULSE_{k}YR'] = impulse
        
        results.append({
            'AGE_GROUP': age_group,
            'RE_GROUP': re_group,
            'PAST_GROWTH_BIN': growth_group,
            'AVG_PAST_GROWTH': avg_past_growth,
            **horizon_growths,
            **impulse_responses
        })
    
    results_df = pd.DataFrame(results)
    
    return results_df


# (2) Lifecycle Earnings Profile target moments
# ---------------------------------------------------------------------
# We target average (level) earnings at 8 points over the life cycle
# (ages 25, 30, ..., 60) for 15 groups of lifetime earnings (LE).
# LE groups: 1, 2–5, 6–10, 11–20, 21–30, ..., 81–90, 91–95, 96–97, 98–99, 100.

def lifetime_earnings(
    df,
    id_col="ID",
    age_col="AGE",
    y_col="REAL_WAGE",
    ymin_col=None,
    age_min=25,
    age_max=55,
    min_obs=1
):
    """Compute worker-level lifetime earnings (LE).

    LE_i = mean_{age in [age_min, age_max]} max(Y_i, Y_min) (if ymin_col provided),
           otherwise mean of Y_i over the window.

    Returns a dataframe with columns [id_col, 'LE'].
    """
    tmp = df.loc[(df[age_col] >= age_min) & (df[age_col] <= age_max), [id_col, age_col, y_col] + ([ymin_col] if ymin_col else [])].copy()

    if ymin_col is not None:
        tmp["Y_FLOORED"] = np.maximum(tmp[y_col].to_numpy(), tmp[ymin_col].to_numpy())
        y_use = "Y_FLOORED"
    else:
        y_use = y_col

    le = (
        tmp.groupby(id_col, as_index=False)[y_use]
           .mean()
           .rename(columns={y_use: "LE"})
    )

    # Optionally drop IDs with too few observations in the window
    if min_obs > 1:
        counts = tmp.groupby(id_col).size().reset_index(name="LE_N")
        le = le.merge(counts, on=id_col, how="left")
        le.loc[le["LE_N"] < min_obs, "LE"] = np.nan
        le = le.drop(columns=["LE_N"])

    return le


def add_le_groups(
    df,
    le_df,
    id_col="ID",
    le_col="LE",
    group_col="LE_GROUP",
    name_col="LE_GROUP_NAME"
):
    """Attach LE and LE groups to the panel.

    Uses percentile rank of LE over all individuals, then assigns 15 groups:
    [0,1], (1,5], (5,10], (10,20], (20,30], ..., (80,90], (90,95], (95,97], (97,99], (99,100]
    Returns df with added columns [le_col, group_col, name_col].
    """
    tmp = le_df[[id_col, le_col]].copy()

    # Percentile rank in (0,1]; 'first' ensures a strict ordering if ties exist
    tmp["LE_PCT"] = tmp[le_col].rank(method="first", pct=True)

    # Quantile cutpoints (share scale)
    q = [0.0, 0.01, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.97, 0.99, 1.0]
    labels = list(range(1, 16))
    names = [
        "P1",
        "P2-P5",
        "P6-P10",
        "P11-P20",
        "P21-P30",
        "P31-P40",
        "P41-P50",
        "P51-P60",
        "P61-P70",
        "P71-P80",
        "P81-P90",
        "P91-P95",
        "P96-P97",
        "P98-P99",
        "P100",
    ]

    tmp[group_col] = pd.cut(tmp["LE_PCT"], bins=q, labels=labels, include_lowest=True)
    tmp[name_col] = pd.cut(tmp["LE_PCT"], bins=q, labels=names, include_lowest=True)

    out = df.merge(tmp[[id_col, le_col, group_col, name_col]], on=id_col, how="left")
    return out


def lifecycle_earnings_profile_moments(
    df,
    id_col="ID",
    age_col="AGE",
    y_col="REAL_WAGE",
    ymin_col=None,
    le_age_min=25,
    le_age_max=55,
    le_min_obs=1,
    target_ages=None,
    group_col="LE_GROUP",
    name_col="LE_GROUP_NAME"
):
    """Compute the Lifecycle Earnings Profile moments (8 ages × 15 LE groups).

    Steps:
    1) Compute LE_i over [le_age_min, le_age_max]
    2) Assign LE groups based on LE percentiles (15 groups)
    3) For each target age and LE group, compute mean earnings in levels.

    Returns a long dataframe with columns:
      [name_col, age_col, 'MEAN_EARNINGS', 'N']
    """
    if target_ages is None:
        target_ages = [25, 30, 35, 40, 45, 50, 55, 60]

    # 1) LE_i
    le = lifetime_earnings(
        df,
        id_col=id_col,
        age_col=age_col,
        y_col=y_col,
        ymin_col=ymin_col,
        age_min=le_age_min,
        age_max=le_age_max,
        min_obs=le_min_obs
    )

    # 2) Attach LE groups
    df2 = add_le_groups(
        df,
        le_df=le,
        id_col=id_col,
        le_col="LE",
        group_col=group_col,
        name_col=name_col
    )

    # 3) Use floored earnings if ymin_col provided
    tmp = df2.copy()
    if ymin_col is not None:
        tmp["Y_FLOORED"] = np.maximum(tmp[y_col].to_numpy(), tmp[ymin_col].to_numpy())
        y_use = "Y_FLOORED"
    else:
        y_use = y_col

    tmp = tmp.loc[tmp[age_col].isin(target_ages)].copy()

    out = (
        tmp.groupby([name_col, age_col], observed=False)[y_use]
           .agg(["mean", "count"])
           .reset_index()
           .rename(columns={"mean": "MEAN_EARNINGS", "count": "N"})
    )

    # Ensure consistent ordering of LE groups
    le_order = [
        "P1","P2-P5","P6-P10","P11-P20","P21-P30","P31-P40","P41-P50",
        "P51-P60","P61-P70","P71-P80","P81-P90","P91-P95","P96-P97","P98-P99","P100"
    ]
    out[name_col] = pd.Categorical(out[name_col], categories=le_order, ordered=True)
    out = out.sort_values([name_col, age_col]).reset_index(drop=True)

    return out


def lifecycle_earnings_profile_wide(
    life_profile_long,
    group_name_col="LE_GROUP_NAME",
    age_col="AGE",
    value_col="MEAN_EARNINGS"
):
    "pivot lifecycle profile to wide (rows=LE groups, cols=ages)."
    wide = life_profile_long.pivot(index=group_name_col, columns=age_col, values=value_col)
    return wide
