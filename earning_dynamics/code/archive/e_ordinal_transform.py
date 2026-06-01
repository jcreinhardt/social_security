"""
author: Ashish Puri
contributors: Michael Yao

this file contains utility functions related to the ordinal transform
"""

import pandas as pd
import numpy as np
import random
import matplotlib as mpl
import matplotlib.pyplot as plt
from scipy import stats 

from a01_parameters import *
import e_final_dist_m
import e_final_dist_f

from e_dpln import *
from e_double_lognorm import *



import e_guv_model


"""
ORDINAL TRANSFORM FUNCTIONALITY
"""

"""ORDINAL TRANSFORM, MAPPING TO A FITTED INCOME DISTRIBUTION"""

#read in parameter estimates for earnings cross sectional distributions (i.e. by cohort-year-gender cell)
df_earndist_male = pd.read_parquet(fp_data / 'intermediate' / 'v5_1m_og.parquet') # CHANGE INPUT HERE IF YOU WANT TO CHANGE PARAMETER ESITMATE USED
df_earndist_female = pd.read_parquet(fp_data / 'intermediate' / 'v5_1f_og.parquet')

print("Using ln estimates")

#get the first and last years we have data for
#do this separately for men
first_year_m = df_earndist_male['year'].min()
last_year_m = df_earndist_male['year'].max()

min_age_m = df_earndist_male['age'].min()
max_age_m = df_earndist_male['age'].max()

#and for women
first_year_f = df_earndist_female['year'].min()
last_year_f = df_earndist_female['year'].max()

min_age_f = df_earndist_male['age'].min()
max_age_f = df_earndist_male['age'].max()

"""GET EARNINGS DISTRBUTION"""

def get_earnings_distribution(gender, age, cohort):
    """
    Pass in gender, age, cohort
    Returns the cross-sectional earnings distribution object.
    Example: dist.rvs(100) would draw 100 samples.
    """

    # calculate the requested year
    year = age + cohort

    if gender == "male":
        # clamp age into available support
        if age < min_age_m:
            age_use = min_age_m
        elif age > max_age_m:
            age_use = max_age_m
        else:
            age_use = age

        # clamp year into available support
        if year < first_year_m:
            year_use = first_year_m
        elif year > last_year_m:
            year_use = last_year_m
        else:
            year_use = year

        # now query with the bounded (age, year) pair
        df_group = df_earndist_male.query('age == @age_use and year == @year_use')
        if df_group.empty:
            raise ValueError(f"No male distribution found for age={age_use}, year={year_use}")

        dist = e_final_dist_m.distm(
            df_group["mu"].iloc[0],
            df_group["sigma"].iloc[0],
            df_group["alpha"].iloc[0],
            df_group["beta"].iloc[0],
            df_group["min_r"].iloc[0],
            df_group["prop_under_1800"].iloc[0]
        )
        # # Create Normal-Laplace distribution
        # dist = nl(df_group["mu"].iloc[0], df_group["sigma"].iloc[0], df_group["alpha"].iloc[0], df_group["beta"].iloc[0])
    

    elif gender == "female":
        # clamp age into available support
        if age < min_age_f:
            age_use = min_age_f
        elif age > max_age_f:
            age_use = max_age_f
        else:
            age_use = age

        # clamp year into available support
        if year < first_year_f:
            year_use = first_year_f
        elif year > last_year_f:
            year_use = last_year_f
        else:
            year_use = year

        # now query with bounded (age, year)
        df_group = df_earndist_female.query('age == @age_use and year == @year_use')
        if df_group.empty:
            raise ValueError(f"No female distribution found for age={age_use}, year={year_use}")

        dist = e_final_dist_f.distf(
            df_group["mu1"].iloc[0],
            df_group["mu2"].iloc[0],
            df_group["s1"].iloc[0],
            df_group["s2"].iloc[0],
            df_group["p_p"].iloc[0],
            df_group["min_r"].iloc[0],
            df_group["prop_under_1800"].iloc[0]
        )

        # dist = double_norm(df_group["mu1"].iloc[0], df_group["mu2"].iloc[0], df_group["s1"].iloc[0], df_group["s2"].iloc[0], df_group["p_p"].iloc[0])

    else:
        return None

    return dist

def get_earnings_cross_section(gender, age, cohort):
    dist = get_earnings_distribution(gender, age, cohort)

    draws = dist.rvs(size=10000)
    plt.hist(draws, bins=100)
    plt.title("gender " + str(gender) + ", age " + str(age) + ", cohort " + str(cohort))
    plt.xlabel("income")
    plt.ylabel("count")

"""THE ORDINAL TRANSFORM"""

def model_fitted_ordinal_transform(results, cohort=1932, gender="male", num_years=30, start = 25):
    results = np.array([r[:num_years] for r in results])

    earnings_dist = []

    for i in range(num_years): 
        earnings_dist.append(get_earnings_distribution(gender, start+i, cohort))

    results_transformed = []

    for i in range(num_years):
        ri = [r[i] for r in results]

        ri_ranks = -1 + stats.rankdata(ri, method="ordinal")
            #ri_percentiles = np.array(ri_ranks)/len(ri)

        earnings_dist_rvs = earnings_dist[i].rvs(len(ri))
        earnings_dist_rvs.sort()

        rti = [earnings_dist_rvs[ri_ranks[k]] for k in range(len(ri))]
            # [earnings_dist[i].ppf(p) for p in ri_percentiles]

        results_transformed.append(rti)

    results_transformed = np.array(results_transformed).T
    #results_transformed /= 1000

    return results_transformed

def single_year_transform(results, cohort=1932, gender="male", age = 25):
    """pass in a numpy array of earnings to transform (should be 1-D vector, with each row a separate person in one year), 
        as well as cohort, gender, and age to simulate

        e.g. model_fitted_ordinal_transform(earnings, cohort = 1940, gender = "male", age = 25)

        returns a numpy array of ordinally transformed earnings, deflated to 2013 dollars by the PCE
    """
    #get the distribution we need to draw from
    earnings_dist = get_earnings_distribution(gender, age, cohort)
     
    #rankdata gives each entry a rank, w the smallest value given a 1
    ranks = -1 + stats.rankdata(results, method="ordinal") 
        #ri_percentiles = np.array(ri_ranks)/len(ri)

    #draw an income for each individual from the appropriate distribution
    earnings_dist_rvs = earnings_dist.rvs(len(results))
    earnings_dist_rvs = np.sort(earnings_dist_rvs) #sort smallest to largest

    #rti are the transformed earnings for the ith year/age
    #for each individual k, look up their original income rank ri_ranks[k]
    #then look up their income in the sorted draws from the fitted distribution
    rti = [earnings_dist_rvs[ranks[k]] for k in range(len(results))] 
        # [earnings_dist[i].ppf(p) for p in ri_percentiles]

    rti = np.array(rti).T #output as numpy

    return rti

## ordinal transform by raw epuf data ##

def sample_truncated_distribution(dist, threshold, k=100):
    samples = []
    while len(samples) < k:
        sample = dist.rvs(size=k)
        samples.extend(sample[sample > threshold])

    return np.array(samples)

df_epuf_saved = pd.read_parquet(fp_data / 'intermediate' / 'df_epuf_saved.parquet')

def get_epuf_cohort_data(gender="male", age=25, cohort=1932):
    if(gender=="male"):
        gender=0
    else:
        gender=1

    df_epuf = df_epuf_saved[df_epuf_saved['sex']==gender]
    df_epuf = df_epuf[df_epuf['cohort']==cohort]
    df_epuf = df_epuf[df_epuf['age']==age]

    return df_epuf

def get_epuf_cohort_earnings_list(gender="male", age=25, cohort=1932):
    df = get_epuf_cohort_data(gender, age, cohort)

    return np.array(df['taxable_earnings']/(df['pce_deflator'].iloc[0]))

def model_raw_ordinal_transform(results, cohort=1932, gender="male", num_years=30):
    results = np.array([r[:num_years] for r in results])

    results_transformed = []

    for i in range(num_years):
        ri = [r[i] for r in results]
        ri_ranks = -1 + stats.rankdata(ri, method="ordinal")

        ### ATTACH DPLN TAIL TO EPUF DRAWS TO DEAL WITH TAXABLE MAXIMUM
        earnings_list = get_epuf_cohort_earnings_list(gender, 25+i, cohort)
        taxable_maximum = max(earnings_list)
        num_tail = np.sum(earnings_list >= taxable_maximum)
        earnings_dist = get_earnings_distribution(gender, 25+i, cohort)
        tail_samples = sample_truncated_distribution(earnings_dist, taxable_maximum, num_tail)
        earnings_list = np.append(earnings_list, tail_samples)

        earnings_list_draws = random.choices(list(earnings_list), k=len(ri))
        earnings_list_draws.sort()

        rti = [round(earnings_list_draws[ri_ranks[k]],2) for k in range(len(ri))]
                # [earnings_dist[i].ppf(p) for p in ri_percentiles]

        results_transformed.append(rti)

    results_transformed = np.array(results_transformed).T
    results_transformed /= 1000

    return results_transformed

## ordinal transform plotting ##

def plot_ordinal_transform_comp(results, results_transformed, num_lines=5):
    num_years = min(len(results[0]), len(results_transformed[0]))
    results = np.array([r[:num_years] for r in results])
    results_transformed = np.array([r[:num_years] for r in results_transformed]) 

    t = np.arange(0,len(results[0]))

    fig, ax = plt.subplots(2)

    for r in results[:num_lines]:
        ax[0].plot(t, r, linewidth=1)
    ax[0].set_title("Trajectories without transformation")
    ax[0].set_xlabel("time")
    ax[0].set_ylabel("earnings")
    ax[0].set_ylim(0,300)

    for rt in results_transformed[:num_lines]:
        ax[1].plot(t, rt, linewidth=1)
    ax[1].set_title("Trajectories with transformation")
    ax[1].set_xlabel("time")
    ax[1].set_ylabel("earnings")
    ax[1].set_ylim(0,300)

    plt.show()

def plot_superimposed_trajectories(results, results_transformed, num_lines=6, num_years=30):
    num_years = min(len(results[0]), len(results_transformed[0]))
    results = np.array([r[:num_years] for r in results])
    results_transformed = np.array([r[:num_years] for r in results_transformed]) 

    t = np.arange(0,num_years)

    fig,ax = plt.subplots(int((num_lines+1)/3), 3, figsize=(15,8))

    for i in range(int((num_lines+1)/3)):
        for j in range(3):
            ax[i][j].plot(t, results[3*i+j], linewidth=1, label="original")
            ax[i][j].plot(t, results_transformed[3*i+j], linewidth=1, label="transformed")

            ax[i][j].set_xlabel("time")
            ax[i][j].set_ylabel("earnings")

            ax[i][j].legend(loc = "upper left", fontsize="small")

    fig.suptitle("Sample Sarin Trajectories vs Transformed Trajectories")
    plt.show()