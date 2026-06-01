"""
author: Michael Yao

Adapted from code by Jackson Howell

This script implements the function model(), which outputs a numpy array/pd dataframe of earnings for one cohort over 36 years, deflated to 2013 dollars

The model is from Catherine, Miller, Sarin (2024) "Social Security and Trends in Wealth Inequality" (henceforth CMS)
    which in turn is based off the model from Guvenen et al. (2021) "What Do Data on Millions of U.S. Workers Reveal About Lifecycle Earnings Dynamics?"
"""

"""
dependencies:
- a01_parameters
- random
- scipy.stats
- itertools.product
"""
import random
from scipy.stats import norm, multivariate_normal, uniform, expon

from a01_parameters import *

from itertools import product

"""
LOAD DATA
"""

"""file dependencies:
in /data/intermediate:
- cms_lifecycle_income_male.csv
- cms_lifecycle_income_female.csv
- df_macro_variables.parquet

in /data/raw:
- SSWageIndex.csv
- PCE_Quarterly.xls"""

"""LIFE-CYCLE PROFILES"""
###############################################################################################################################################################
#pull life-cycle profile estimates
#estimates are stored in data/intermediate

#the following two files are life-cycle profiles from the CMS replication package
lifecycle_m = pd.read_csv(fp_data / 'intermediate' / 'cms_lifecycle_income_male.csv').T.reset_index()
lifecycle_f = pd.read_csv(fp_data / 'intermediate' / 'cms_lifecycle_income_female.csv').T.reset_index()

#CMS fit cubics to the life-cycle profile of the mean earnings of each cohort
#we load in their parameters for men
lifecycle_m = lifecycle_m.rename(columns = {'index' : 'cohort', 0 : 'gt_age', 1 : 'gt_age2', 2:'gt_age3', 3:'gt_cons'})
lifecycle_m['cohort'] = lifecycle_m['cohort'].str[-4:].astype(int)
lifecycle_m['cohort'] = lifecycle_m['cohort'] - 25
lifecycle_m['sex'] = 0

#use the 1924 parameters for cohorts 1800-1924 
lifecycle_1924m = lifecycle_m.loc[lifecycle_m['cohort']==1924, :]
past_lifecycle_m = pd.DataFrame(np.repeat(lifecycle_1924m.values, 1924-1800, axis=0))
past_lifecycle_m.iloc[:,0] = np.arange(1800, 1923 + 1)
past_lifecycle_m.columns = lifecycle_m.columns

#use 1984 parameters for cohorts 1984-2100
lifecycle_1984m = lifecycle_m.loc[lifecycle_m['cohort']==1984, :]
future_lifecycle_m = pd.DataFrame(np.repeat(lifecycle_1984m.values, 2100-1984 + 1, axis=0))
future_lifecycle_m.iloc[:,0] = np.arange(1984, 2100 + 1)
future_lifecycle_m.columns = lifecycle_m.columns

#merge these into the male parameters
lifecycle_m = pd.concat([lifecycle_m, past_lifecycle_m, future_lifecycle_m], axis=0).sort_values(by='cohort')

#cubic parameters for women
lifecycle_f = lifecycle_f.rename(columns = {'index' : 'cohort', 0 : 'gt_age', 1 : 'gt_age2', 2:'gt_age3', 3:'gt_cons'})
lifecycle_f['cohort'] = lifecycle_f['cohort'].str[-4:].astype(int)
lifecycle_f['cohort'] = lifecycle_f['cohort'] - 25
lifecycle_f['sex'] = 1

#use the 1924 parameters for cohorts 1800-1924 
lifecycle_1924f = lifecycle_f.loc[lifecycle_f['cohort']==1924, :]
past_lifecycle_f = pd.DataFrame(np.repeat(lifecycle_1924f.values, 1924-1800, axis=0))
past_lifecycle_f.iloc[:,0] = np.arange(1800, 1923 + 1)
past_lifecycle_f.columns = lifecycle_f.columns

#use 1984 parameters for cohorts 1984-2100
lifecycle_1984f = lifecycle_f.loc[lifecycle_f['cohort']==1984, :]
future_lifecycle_f = pd.DataFrame(np.repeat(lifecycle_1984f.values, 2100-1984 + 1, axis=0))
future_lifecycle_f.iloc[:,0] = np.arange(1984, 2100 + 1)
future_lifecycle_f.columns = lifecycle_f.columns

#merge these into the male parameters
lifecycle_f = pd.concat([lifecycle_f, past_lifecycle_f, future_lifecycle_f], axis=0).sort_values(by='cohort')

#store params for men and women in one df
df_ageProfile_coefs = pd.concat([lifecycle_m, lifecycle_f], ignore_index = True) 



"""SOCIAL SECURITY AVERAGE WAGE INDEX"""

# pull social social security wage index
# the average wage index goes from 1944 to 2019
SSWageIndex = pd.read_csv(fp_data / 'raw' / 'SSWageIndex.csv', names = ['l1'], header = None)
SSWageIndex['year'] = np.arange(1944, 2019 + 1)

#assume that the average wage from 2020-2100 is the 2019 value
av_wage_2020 = SSWageIndex.query('year == 2019')['l1'].values[0]
av_wage_2020 = np.repeat(av_wage_2020, 2100-2020 +1)
av_wage_after_2020 = pd.DataFrame(data = av_wage_2020, columns=['l1'])
av_wage_after_2020['year'] = np.arange(2020, 2100+1)

#assume the average wage index from 1800-1943 is the 1944 value
av_wage_1944 = SSWageIndex.query('year == 1944')['l1'].values[0]
av_wage_1944 = np.repeat(av_wage_1944, 1944-1800)
av_wage_before_1944 = pd.DataFrame(data = av_wage_1944, columns=['l1'])
av_wage_before_1944['year'] = np.arange(1800, 1944)

#merge the assumed average wage before 1944 and the average wage after 2019 into the average wage index
#and sort the rows by year
SSWageIndex = pd.concat([SSWageIndex, av_wage_before_1944, av_wage_after_2020], axis=0).sort_values(by='year')

###############################################################################################################################################################
"""MACRO VARIABLES"""

# pull macro variables file that Jackson has been using
df_macro_variables = pd.read_parquet(fp_data / 'intermediate' / 'df_macro_variables.parquet').rename(columns = {'avgearn_tot': 'avgearn_tot_base'})


"""PCE PRICE INDEX"""

# get the PCE (a deflator) to turn everything into 2013 dollars/real terms

df_pce = pd.read_excel(fp_data / 'raw' / 'PCE_Quarterly.xls', sheet_name = 1)[['DATE', 'PCECTPI']]
df_pce['year'] = pd.DatetimeIndex(df_pce['DATE']).year

df_pce = df_pce.groupby('year').agg(pce_deflator = ('PCECTPI', 'mean')).reset_index()
df_pce['pce_deflator'] = df_pce['pce_deflator'] / df_pce.loc[df_pce['year'] == 2013, 'pce_deflator'].values[0]

#assume that the PCE from 2016-2100 is the 2015 value
PCE_2015 = df_pce.loc[df_pce['year']==2015, 'pce_deflator'].values[0]
PCE_2015 = np.repeat(PCE_2015, 2100-2016 +1)
PCE_after_2015 = pd.DataFrame(data = PCE_2015, columns=['pce_deflator'])
PCE_after_2015['year'] = np.arange(2016, 2100+1)

#assume that the PCE from 1800-1947 is the 1947 value
PCE_1947 = df_pce.loc[df_pce['year']==1947, 'pce_deflator'].values[0]
PCE_1947 = np.repeat(PCE_1947, 1947-1800)
PCE_before_1947 = pd.DataFrame(data = PCE_1947, columns=['pce_deflator'])
PCE_before_1947['year'] = np.arange(1800, 1947)

#merge the assumed PCE before 1947 and the PCE after 2015 into the PCE series
#and sort the rows by year
df_pce = pd.concat([df_pce, PCE_before_1947, PCE_after_2015], axis=0).sort_values(by='year')


"""
MAIN SIMULATION
"""


def model(sampleN, sexes=[1], cohorts=[1945], array = True):
    """simulates income paths using the guv model from ages 25 to 60

    arguments:
    - number of simulated workers (sampleN)
    - sexes as a list
    - cohorts as a list
    - (optional) array: set by default to True. If True, model() will return a numpy array of earnings.
                                                If False, model() will return a dataframe of earnings

    e.g. model(1000, sexes = [0, 1], cohorts = [1950])

    returns:
    - if array == True, a sampleN (multiplied by sexes and cohorts) by 36 numpy array
    - array == False, a long dataframe (i.e. one row for each year for each individual) with earnings stored in 'y_real' 
    - simulated earnings are deflated to 2013 dollars"""


    """
    SET PARAMETERS
    """ 
    #from Table IV in Guvenen (2021), also Table D.III in Appendix


    ages = np.arange(25, 60 + 1)
    t = (ages - 24) / 10

    """LIFE-CYCLE PROFILE (alpha, beta)"""
    # Deterministic lifecycle profile
    
    g_a = 2.580861694
    g_at = 0.811530031
    g_at2 = -0.185093302
    
    sigma_alpha = 0.299819619
    sigma_beta = 0.196328895
    corr_alphaBeta = 0.767749193
    cov_alphaBeta = corr_alphaBeta * (sigma_alpha * sigma_beta)
    cov = np.array([[sigma_alpha**2, cov_alphaBeta], [cov_alphaBeta, sigma_beta**2]]) #covariance matrix
                
    dist_alphaBeta = multivariate_normal([0, 0], cov = cov) #set up distribution of alpha and beta

    #calculate variance of alpha + t * beta
    #we will later use this variance to adjust for Jensen's inequality
    var_alphaBeta = sigma_alpha ** 2 + t ** 2 * sigma_beta ** 2 + 2 * t * cov_alphaBeta 
    df_alphaBeta = pd.DataFrame({'t': t, 'var_alphaBeta': var_alphaBeta})

    """AR(1) (z)"""

    ###innovations (eta)

    pz = 0.406559194

    mu_eta_1 = -0.085236482
    sigma_eta_1 = 0.363928061
    eta_1 = norm(mu_eta_1, sigma_eta_1)

    mu_eta_2 = -mu_eta_1 * pz / (1 - pz) #set mu_eta_2 make eta zero mean overall
    sigma_eta_2 = 0.06891405
    eta_2 = norm(mu_eta_2, sigma_eta_2)

    #calculate var_eta using the law of total variance
    var_eta = pz * sigma_eta_1 ** 2 + (1 - pz) * sigma_eta_2 ** 2 + pz * mu_eta_1 ** 2 + (1 - pz) * mu_eta_2 ** 2 - (pz * mu_eta_1 + (1 - pz) * mu_eta_2)**2

    ###initial draw of z

    sigma_z0 = 0.713648178
    dist_z0 = norm(0, sigma_z0)

    ###setting up the AR(1)

    rho = 0.959229453

    z_vars = np.zeros(60 - 25 + 1)

    ###calculate variance of z
    #we will use this variance later to adjust for Jensen's inequality
    z_vars[0] = sigma_z0 ** 2 

    for age in range(26, 60 + 1):
        
        z_vars[age - 25] = rho ** 2 * z_vars[age - 1 - 25] + var_eta
        
    z_vars = pd.DataFrame(np.array([range(25, 60 + 1), z_vars]).T, columns = ['age', 'z_var'])

    """TRANSITORY SHOCKS (epsilon)"""

    peps = 0.129904327

    mu_eps_1 = 0.271112226
    sigma_eps_1 = 0.284541004
    eps_1 = norm(mu_eps_1, sigma_eps_1)

    mu_eps_2 = -mu_eps_1 * peps / (1 - peps)
    sigma_eps_2 = 0.036545913
    eps_2 = norm(mu_eps_2, sigma_eps_2)

    #calculate the variance of epsilon using the law of total variance
    #used later to adjust for Jensen's inequality
    var_eps = peps * sigma_eps_1 ** 2 + (1 - peps) * sigma_eps_2 ** 2 + peps * mu_eps_1 ** 2 + (1 - peps) * mu_eps_2 ** 2 - (peps * mu_eps_1 + (1 - peps) * mu_eps_2)**2

    """NONEMPLOYMENT SHOCK"""
    nu_a = -3.352949544
    nu_b = -0.859498283
    nu_c = -5.034075647
    nu_d = -2.895204912

    lmbda = 0.000265509

    dist_nu = expon(1 / lmbda) #set up the distribution of nu


    """
    SIMULATION
    """

    """SET UP INDIVIDUALS"""

    #make a dataframe containing every observation we need to simulate
    #that is, sampleN people per cohort per sex
    #multiple people will share the same i. Each person is only uniquely specified by cohort, sex, i
    df_id = pd.DataFrame(product(cohorts, sexes, range(sampleN)), columns = ['cohort', 'sex', 'i'])

    #now generate one alpha and one beta for each person
    df_id[['alpha', 'beta']] = dist_alphaBeta.rvs(df_id.shape[0])

    #for each person, create a list of ages to simulate
    df = pd.DataFrame(product(range(sampleN), ages), columns = ['i', 'age']).merge(df_id, on = 'i', how = 'left')
    
    df['year'] = df['cohort'] + df['age']
    df['t'] = (df['age'] - 24) / 10

    """LIFE-CYCLE PROFILES (g(t))"""

    df = df.merge(df_macro_variables[['year', 'taxable_maximum', 'cpi_deflator']], on = 'year', how = 'left')
    df = df.merge(SSWageIndex, on = ['year'], how = 'left')

    #merge in life-cycle profile estimates for each cohort-sex combination
    # df = df.merge(df_ageProfile_coefs[['cohort', 'sex', 'gt_cons', 'gt_age', 'gt_age2', 'gt_age3']], on = ['cohort', 'sex'], how = 'left')
    
    # CD commented out to avoid confusion ^^

    #evaluate the cubic polynomial g(t)
    #NOTE: Guvenen's g(t) has t = (age - 24)/10, but CMS has g(t) where t is age in years
    # df['gt'] = df['gt_cons'] + df['gt_age'] * df['age'] + df['gt_age2'] * df['age'] ** 2 + df['gt_age3'] * df['age'] ** 3

    df['t'] = (df['age']-24)/10
    df['g(t)'] = g_a + g_at * df['t'] + g_at2 * df['t'] ** 2 #AV: Changed to guvenen

    #merge in the variance of (alpha + beta * t)
    df = df.merge(df_alphaBeta, on = 't', how = 'left')

    """AR(1) (z)"""

    #draw shocks
    df['ar1_draw'] = uniform.rvs(size = df.shape[0]) #first draw a Unif(0,1) to decide which distribution to draw eta from
    df.loc[(df['ar1_draw'] < pz), 'eta'] = eta_1.rvs(size = df[(df['ar1_draw'] < pz)].shape[0])
    df.loc[(df['ar1_draw'] >= pz), 'eta'] = eta_2.rvs(size = df[(df['ar1_draw'] >= pz)].shape[0])

    #initialize the AR(1) at the initial normal
    df.loc[df['age'] == ages[0], 'z'] = dist_z0.rvs(df[df['age'] == ages[0]].shape[0])

    #then simulate the AR(1) for each age
    for age in ages[1:]:
        df.loc[df['age'] == age, 'z'] = rho * df.loc[df['age'] == age - 1, 'z'].to_numpy() + df.loc[df['age'] == age, 'eta'].to_numpy()

    #merge in the variance of the AR(1)
    df = df.merge(z_vars, on = 'age', how = 'left')

    """TRANSITORY SHOCKS (epsilon)"""   

    df['eps_draw'] = uniform.rvs(size = df.shape[0]) #draw Unif(0,1) to decide which dist to draw epsilon from
    df.loc[(df['eps_draw'] < peps), 'eps'] = eps_1.rvs(size = df[(df['eps_draw'] < peps)].shape[0])
    df.loc[(df['eps_draw'] >= peps), 'eps'] = eps_2.rvs(size = df[(df['eps_draw'] >= peps)].shape[0])

    """NONEMPLOYMENT SHOCK (nu)"""
    #first calculate xi, taking note that xi(t) has t=(age-24)/10
    df['xi'] = nu_a + nu_b * df['t'] + nu_c * df['z'] + nu_d * df['z'] * df['t'] 
    df['pnu'] = np.exp(df['xi']) / (1 + np.exp(df['xi'])) #then feed xi into the logistic function

    df['nu_draw'] = uniform.rvs(size = df.shape[0]) #draw Unif(0,1) as before
    df.loc[(df['nu_draw'] >= df['pnu']), 'nu'] = 0
    df.loc[(df['nu_draw'] < df['pnu']), 'nu'] = np.minimum(1, dist_nu.rvs(size = df[(df['nu_draw'] < df['pnu'])].shape[0]))

    #for each year, age, sex group, find the mean value of the nonemployment shock
    df_mean_nu = df.groupby(['year', 'age', 'sex'])['nu'].mean().reset_index().rename(columns = {'nu' : 'mean_nu'})
    #store this mean in the df, we'll divide by it later
    df = df.merge(df_mean_nu, on = ['year', 'sex', 'age'], how = 'left') 
    df['mean_nu'] = np.minimum(df['mean_nu'].to_numpy(), 0.9999) #to prevent divide by zero errors

    """EARNINGS LEVEL (Y)"""

    # We adjust for Jensen's inequality by subtracting half the variance of the idiosyncratic shocks from the new g(t)
    # This is why we stored the variance of alpha, beta, z, eps 

    # Subtracting half the variance means that E[exp(g(t) + a + t*b + z + eps)|t] = exp(g(t))
    # Otherwise, E[exp(g(t) + a + t*b + z + eps)|t] > exp(g(t)) by Jensen's inequality, since exp() is convex

    # df['l2'] = (1 - df['nu'])/(1 - df['mean_nu']) * (np.exp(df['gt'] + df['alpha'] + df['beta'] * df['t'] 
    #                                                         + df['z'] + df['eps'] - 
    #                                                         (df['var_alphaBeta'] + df['z_var'] + var_eps) / 2))

    df['l2'] = (1 - df['nu']) * np.exp(df['g(t)'] + df['alpha'] + df['beta'] * df['t'] + df['z'] + df['eps'])
    
    #multiply L2 by the wage index L1, see the CMS main text for more details
    # df['l'] = df['l1'] * df['l2']

    #censor variable taxearn at the taxable maximum
    # df['taxearn'] = np.minimum(df['taxable_maximum'], df['l']) / (df['l1'])

    #deflate to 2013 dollars using the PCE price index
    # df = df.merge(df_pce, on='year', how='left')
    # df['y_real'] = df['l']/df['pce_deflator']
    df['y_real'] = df['l2']

    # CD removed wage index and pce deflating

    #convert the output dataframe to numpy array
    results_np = df['y_real'].to_numpy().reshape((len(sexes) * len(cohorts) * sampleN, 36))

    if array == True:
        return results_np
    elif array == False:
        return df