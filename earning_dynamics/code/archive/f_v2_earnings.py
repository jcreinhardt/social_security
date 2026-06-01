"""
author: Alexander Vu
some of the code is by Michael Yao

This notebook provides three functions:
1. initalize_base_year() initializes earnings histories for all cohorts alive in a base year (e.g. 1937)
2. initial_earnings() generates the first earnings records for a cohort-sex group
3. project_earnings() generates the next year's earnings for that cohort-sex group

The model is from Catherine, Miller, Sarin (2024) "Social Security and Trends in Wealth Inequality" (henceforth CMS)
    which in turn is based off the model from Guvenen et al. (2021) "What Do Data on Millions of U.S. Workers Reveal About Lifecycle Earnings Dynamics?"

The output from CMS can be fed through an "ordinal transformation", mapping earnings to a double Pareto log normal distribution for men
    and a mixture of two log normals for women.

For each person, if they are at the ith percentile of earnings in the CMS output, the ordinal transform will assign then the 
    ith percentile of earnings in the fitted distribution
"""

"""
code dependencies:
- a01_parameters (custom module in /code)
- ordinal_transform (custom module)
- b06_final_dist_m, b06_final_dist_f, b06_dpln, b06_double_lognorm (custom modules)
- scipy.stats
- itertools.product
"""

"""file dependencies:
in /data/intermediate:
- cms_lifecycle_income_male.csv
- cms_lifecycle_income_female.csv
- df_macro_variables.parquet
- v5_1m.parquet
- v5_1f.parquet
- df_epuf_saved.parquet

in /data/raw:
- SSWageIndex.csv
- PCE_Quarterly.xls"""

#cms_model is a custom module which loads the data needed to run the CMS model
#as well as an implementation of the CMS model which simulates income paths from ages 25-60
from f_guv_model import * 

#ordinal_transform is a custom module which loads the relevant income cross-sections 
#and the ordinal transform functionality
import e_ordinal_transform

#needed for random sampling and simulation
from scipy.stats import norm, multivariate_normal, uniform, expon
from a01_parameters import *
from itertools import product

# we will be inputting and outputting PYARROW TABLES
import pyarrow as pa
import pyarrow.compute as pc

"""
SET PARAMETERS FOR CMS MODEL
"""
#from Table IV in Guvenen (2021), also Table D.III in Appendix

"""LIFE-CYCLE PROFILE (alpha, beta)"""

sigma_alpha = 0.299819619
sigma_beta = 0.196328895
corr_alphaBeta = 0.767749193
cov_alphaBeta = corr_alphaBeta * (sigma_alpha * sigma_beta)
cov = np.array([[sigma_alpha**2, cov_alphaBeta], [cov_alphaBeta, sigma_beta**2]]) #covariance matrix
            
dist_alphaBeta = multivariate_normal([0, 0], cov = cov) #set up distribution of alpha and beta

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
COMPONENTS OF THE INCOME PROCESS
"""

"""LIFE-CYCLE PROFILES (g(t))"""
def gt(df):
    """takes in a pandas dataframe where every row is an observation to simulate
    returns the dataframe with an added column 'gt' corresponding to g(t) in Guvenen/CMS"""

    g_a = 2.580861694
    g_at = 0.811530031
    g_at2 = -0.185093302
        
    # Ensure no duplicate (cohort, sex) rows (added by alex)
    coefs = df_ageProfile_coefs.drop_duplicates(subset=['cohort', 'sex'])
    
    #merge in life-cycle profile estimates for each cohort-sex combination
    #df = df.merge(df_ageProfile_coefs[['cohort', 'sex', 'gt_cons', 'gt_age', 'gt_age2', 'gt_age3']], on = ['cohort', 'sex'], how = 'left')
    # CD commented this out because not using CMS

    #evaluate the cubic polynomial g(t)
    #NOTE: Guvenen's g(t) has t = (age - 24)/10, but CMS has g(t) where t is age in years
    # df['gt'] = df['gt_cons'] + df['gt_age'] * df['age'] + df['gt_age2'] * df['age'] ** 2 + df['gt_age3'] * df['age'] ** 3
    df['t'] = (df['age']-24)/10
    df['g(t)'] = g_a + g_at * df['t'] + g_at2 * df['t'] ** 2

    df = df.drop_duplicates()
    
    return df #returns the same dataframe, but with an added column 'gt'


"""AR(1) (z)"""

def AR1(df):
    """takes in a pandas dataframe where every row is an observation to simulate
    uses column "z_tminus1" in the dataframe to calculate what z should be
    returns the same dataframe with added column z"""

    #draw shocks, eta
    df['ar1_draw'] = uniform.rvs(size = df.shape[0]) #first draw a Unif(0,1) to decide which distribution to draw eta from

    #create a new column called 'eta' with the value of eta, drawn from the correct distribution
    df.loc[(df['ar1_draw'] < pz), 'eta'] = eta_1.rvs(size = df[(df['ar1_draw'] < pz)].shape[0])
    df.loc[(df['ar1_draw'] >= pz), 'eta'] = eta_2.rvs(size = df[(df['ar1_draw'] >= pz)].shape[0])

    #then use z_tminus1 to calculate z
    df['z'] = rho * df['z_tminus1'] + df['eta']

    return df #returns same dataframe, but with new column 'z'


"""TRANSITORY SHOCKS (epsilon)"""   

def trans_shock(df):
    """takes in a pandas dataframe where every row is an observation to simulate
    returns the same dataframe with added column 'eps', which is the transitory shock """

    df['eps_draw'] = uniform.rvs(size = df.shape[0]) #draw Unif(0,1) to decide which dist to draw epsilon from

    #create a new column called 'eps' with the value of epsilon, drawn from the correct distribution
    df.loc[(df['eps_draw'] < peps), 'eps'] = eps_1.rvs(size = df[(df['eps_draw'] < peps)].shape[0])
    df.loc[(df['eps_draw'] >= peps), 'eps'] = eps_2.rvs(size = df[(df['eps_draw'] >= peps)].shape[0])

    return df

"""NONEMPLOYMENT SHOCK (nu)"""

def nonemp(df):
    """takes in a pandas dataframe where every row is an observation to simulate
    returns the same dataframe with added column 'nu', which is the nonemployment shock """

    #first calculate xi, taking note that xi(t) has t=(age-24)/10
    df['xi'] = nu_a + nu_b * df['t'] + nu_c * df['z'] + nu_d * df['z'] * df['t'] 
    df['pnu'] = np.exp(df['xi']) / (1 + np.exp(df['xi'])) #then feed xi into the logistic function

    df['nu_draw'] = uniform.rvs(size = df.shape[0]) #draw Unif(0,1) as before

    #create a column called 'nu' containing the value of nu, drawn from the correct distribution
    df.loc[(df['nu_draw'] >= df['pnu']), 'nu'] = 0
    df.loc[(df['nu_draw'] < df['pnu']), 'nu'] = np.minimum(1, dist_nu.rvs(size = df[(df['nu_draw'] < df['pnu'])].shape[0]))

    #for each year, age, sex group, find the mean value of the nonemployment shock
    df['mean_nu'] = df['nu'].mean()

    return df


""""
GENERATE INITIAL EARNINGS FOR A BASE YEAR
"""

def init_base_year(table_in, year = 1937, sex = 0, transformed = True):
    """initializes incomes in the base year (1937). 
    will produce historical income paths for years before 1937
    
    arguments:
    - table_in: a pyarrow table of people you want to simulate with columns "age", "cohort", "SSN", and "inc_25" through "inc_55". 
            YOU MUST ALSO PROVIDE columns "alpha", "beta", "z_var", and "z_tminus1". I will assume they are already created.
            The lowest age possible is 25.
    - year: the base year
    - sex: 0 for men, 1 for women. NOTE: you must simulate men and women in separate function calls
    - transformed: False means the outputted earnings will be the output from the CMS model, 
                    True means the output earnings will be passed through the ordinal transform
                    The ordinal transform works for ages 25-55, and has data for years 1962-2006
                     
    example call: init_base_year(table_in, year = 1937, sex = 1 , transformed = True) 
    
    returns a pyarrow table containing:
    - SSN, age, cohort as before
    - columns 'inc_25', 'inc_26', ..., 'inc_55' for each worker
        representing their historical income paths. years after the base year are left empty
        earnings are in 2013 dollars (deflated using PCE)
    - alpha, beta, z_tminus1, and z_var for each individual
    """

    # WHAT ALPHA, BETA, Z, VAR(Z) MEAN
    """
    - each worker has one alpha and one beta over their lifetime
        - alpha shifts the level of income at all ages
        - beta controls how quickly income grows with age
        - z is the AR(1) component of income. It contributes persistent shocks, 
            e.g. part-year unemployment and subsequent 'scarring' effects to income
        -var(z) is the variance of z_t. As a technical detail, we need to track the variance of shocks, 
            so that our simulation has the correct mean income.
            
            The mathematics of this have to do with Jensen's inequality:
            Subtracting half the variance of idiosyncratic shocks means that 
                E[exp{g(t) + a + t*b + z + eps - 1/2 Var(a+bt + z + eps)}|t] = exp(g(t))
            Otherwise, 
                E[exp(g(t) + a + t*b + z + eps)|t] > exp(g(t)) 
            by Jensen's inequality, since exp() is convex and alpha, beta, z, and epsilon all have zero mean 
                                                                                    (but positive variance)
    """


    """
    INITIALIZING THE LOOP OVER COHORTS
    """

    #convert sex = 0,1 into male, female
    sex_keys = ["male", "female"]

    #make a list of all the different cohorts to simulate and their respective sizes
    grouped = table_in.group_by("cohort").aggregate([("SSN", "count")])

    # Extract cohort names and sizes
    cohort_sizes = np.array(grouped["SSN_count"])
    cohorts = np.array(grouped["cohort"])  # this is an array of unique cohort values

    """SIMULATION"""

    #now simulate each cohort using cms_model
    for i in range(len(cohorts)):
        #simulate the correct number of people for each cohort
        #recall that sexes and cohorts take in the argument as a LIST
        earnings = model(cohort_sizes[i], sexes = [sex], cohorts = [cohorts[i]], array = False) # from f_guv_model

        # display(earnings)
        
        #extract the earnings histories as a numpy array
        histories = earnings['y_real'].to_numpy().reshape((cohort_sizes[i], 36))

        #if transformed is set to True, apply the ordinal transform
        if transformed == True:
            #feed in the numpy array to the ordinal transform
            histories = e_ordinal_transform.model_fitted_ordinal_transform(histories, cohort=cohorts[i], gender=sex_keys[sex], num_years=31, start = 25)

        """ALEX: Expand earnings to the left to age 16 linear decrease """ ## Will need to remove
        # histories.shape == (num_people, 36)
        num_people, num_years = histories.shape  
        
        # Value at age 25 for each person (column 0)
        start_vals = histories[:, 0]  # shape (num_people,)
        
        # Create 10 columns (ages 15 to 24)
        # For each step back, income is reduced proportionally
        years_before = 10
        left_cols = np.zeros((num_people, years_before))
        
        for j in range(years_before):
            frac = (years_before - j) / years_before  # 1.0 → 0.1
            left_cols[:, j] = start_vals * frac
        
        # Combine: ages 15-24, then original histories (ages 25+)
        histories = np.hstack([left_cols, histories])

        # start at 16 year old
        histories = histories[:, 1:]

        """ALEX: Expand earnings to the right to age 65 1% increase each year""" ## Will need to remove
        current_max_age = 16 + histories.shape[1] - 1
        target_max_age = 65
        
        extra_years = target_max_age - current_max_age
        # print("extra_years:", extra_years)
        
        if extra_years > 0:
            last_val = histories[:, -1][:, None]  # shape (people, 1)
            growth_factors = (1.01) ** np.arange(1, extra_years + 1)
            new_cols = last_val * growth_factors[None, :]
            histories = np.hstack([histories, new_cols])
        
        """MAKE TEMPORARY PANDAS DATAFRAME"""

        #make a temporary pandas dataframe copy of the relevant cohort of table_in
        #get the relevant cohort
        cohort_i = cohorts[i]
        #make a mask for table_in to select relevant rows
        mask = pc.equal(table_in["cohort"], pa.scalar(cohort_i))
        #turn those rows into a pd df
        df_in = table_in.filter(mask).to_pandas()

        """ASSIGNING EARNINGS TO PD DF"""

        #calculate the age each worker was in 1937
        max_age = year - cohort_i
        max_age = min(65, max_age)
        #we'll use max_index to select earnings from the earnings histories numpy array
        max_index = max_age - 16 + 1
        
        #only keep earnings from 1937 and earlier
        histories = histories[:, :max_index]

        #assign earnings histories to correct workers
        col_names = [f'inc_{j}' for j in range(16, max_age + 1)]
        # col_names = [f'inc_{j}' for j in range(25, 25 + histories.shape[1])]

        #it's important to use this .loc[row_indexer, col_indexer] syntax
        #this guarantees that we're assigning values to a VIEW of df_in and NOT a TEMPORARY COPY
        #see the pandas documentation on "Indexing and selecting data" > "Returning a view versus a copy" for more

        df_in.loc[df_in['cohort'] == cohort_i, col_names] = histories

        """ASSIGNING ALPHA, BETA, Z, Z_VAR TO PD DF"""

        #extract alpha, beta, z, z_var
        #it's important to get the VALUES of each slice of the df, so that each variable is a numpy vector
        #it is easy to assign numpy arrays to slices of a dataframe, but hard to assign slices of a dataframe to another dataframe
        # Adjust query_age according to your rules
        if max_age < 25:
            query_age = 25
        elif max_age > 55:
            query_age = 55
        else:
            query_age = max_age
        
        # Now query using query_age instead of max_age
        alpha = earnings.query('cohort == @cohort_i and age == @query_age and sex == @sex')['alpha'].values
        beta = earnings.query('cohort == @cohort_i and age == @query_age and sex == @sex')['beta'].values
        z = earnings.query('cohort == @cohort_i and age == @query_age and sex == @sex')['z'].values
        z_var = earnings.query('cohort == @cohort_i and age == @query_age and sex == @sex')['z_var'].values

        #it's important to use this .loc[row_indexer, col_indexer] syntax, see above for explanation
        df_in.loc[df_in['cohort'] == cohort_i, 'alpha'] = alpha
        df_in.loc[df_in['cohort'] == cohort_i, 'beta'] = beta
        df_in.loc[df_in['cohort'] == cohort_i, 'z_var'] = z_var
        df_in.loc[df_in['cohort'] == cohort_i, 'z_tminus1'] = z
        #value of z at TIME T. 
        #only called t-1 so that you can feed this into next year's projection. 
        # t-1 from the perspective of NEXT YEAR

        """UPDATE PYARROW TABLE USING DF_IN"""
        #turn df_in into pa table
        updated_table = pa.Table.from_pandas(df_in)

        #filter out the old rows from table_in
        mask = pc.not_equal(table_in["cohort"], pa.scalar(cohort_i))
        table_in = table_in.filter(mask)

        # Step 3: Append updated rows
        table_in = pa.concat_tables([table_in, updated_table])

    return table_in


""""
GENERATE INITIAL EARNINGS FOR A COHORT IN THEIR FIRST WORKING YEAR
"""

def initial_earnings(table_in, sex = 0, transformed = True):
    """assigns initial earnings in the first working year (e.g. age 25)
    this CAN handle MULTIPLE age-cohort groups!
      
    arguments:
    - table_in: a pyarrow table of people you want to simulate with columns "age", "cohort", "SSN", 
        "inc_{age}" for the age you want to initialize. 
        YOU MUST ALSO PROVIDE columns "alpha", "beta", "z_var", and "z_tminus1". I will assume they are already created.
    - sex: 0 for men, 1 for women
    - transformed: False means the outputted earnings will be the output from the CMS model, 
                    True means the output earnings will be passed through the ordinal transform.
                    The ordinal transform works for ages 25-55, and has data for years 1962-2006

    example call: initial_earnings(table_in, sex = 1, transformed = True)

    returns a pyarrow table containing 
    - table_in with incomes filled out for "inc_{age}" for the age I simulated
    - earnings in 2013 dollars (deflated using PCE)
    - UPDATED alpha, beta, z_tminus1, and z_var for each individual

    - the order of rows WILL NOT be preserved
    """

    ####WHAT THE ABOVE VARIABLES MEAN####
    """
    - each worker has one alpha and one beta over their lifetime
        - alpha shifts the level of income at all ages
        - beta controls how quickly income grows with age
        - z is the AR(1) component of income. It contributes persistent shocks, 
            e.g. part-year unemployment and subsequent 'scarring' effects to income
        -var(z) is the variance of z_t. As a technical detail, we need to track the variance of shocks, 
            so that our simulation has the correct mean income.
            
            The mathematics of this have to do with Jensen's inequality:
            Subtracting half the variance of idiosyncratic shocks means that 
                E[exp{g(t) + a + t*b + z + eps - 1/2 Var(a+bt + z + eps)}|t] = exp(g(t))
            Otherwise, 
                E[exp(g(t) + a + t*b + z + eps)|t] > exp(g(t)) 
            by Jensen's inequality, since exp() is convex and alpha, beta, z, and epsilon all have zero mean 
                                                                                    (but positive variance)
    """
    
    """LOOP OVER COHORTS"""

    #make a list of all the different cohorts to simulate, and store as a list
    cohorts = pc.unique(table_in["cohort"]).to_pylist()

    for cohort_i in cohorts:
        #filter for only that cohort
        # print("table_in:",table_in.num_rows)
        # print(table_in)
        
        mask = pc.equal(table_in["cohort"], pa.scalar(cohort_i))
        cohort_table = table_in.filter(mask)

        # print("cohort_table:",cohort_table.num_rows)
        # print(cohort_table)
        
        #make a list of all the different cohorts to simulate and their respective sizes
        grouped_ages = cohort_table.group_by("age").aggregate([("SSN", "count")])

        # make a list of ages and sizes
        age_sizes = np.array(grouped_ages["SSN_count"])
        ages = np.array(grouped_ages["age"])  # this is an array of unique cohort values


        """LOOP OVER AGES"""

        for j in range(len(ages)):
            age_j = ages[j]
            if age_j <= 24:
                age_ord_input = 25
            else:
                age_ord_input = age_j

            sampleN = age_sizes[j]

            #select the rows of cohort_table with this age-cohort combination
            #create a mask
            mask = pc.and_(pc.equal(cohort_table["cohort"], cohort_i),
                pc.equal(cohort_table["age"], age_j))
            
            # Filter the table and save as a dataframe
            df = cohort_table.filter(mask).to_pandas()
            
            # print(len(df))
            # print("df before gt:",df)
            
            """SET UP INDIVIDUALS"""

            df['sex'] = sex
            df['t'] = (25 - 24) / 10 #(df['age'] - 24) / 10
            df['year'] = df['cohort'] + 25 #df['age']


            # print(len(df))
            # print("set up indiv df:",df)
            
            """LIFE-CYCLE PROFILES g(t)"""

            df = gt(df)


            """HETEROGENEOUS INCOME PROFILES (alpha, beta)"""

            #each individual is assigned one alpha and beta for their entire life
            #alpha shifts level of earnings at every age
            #beta controls how quickly earnings grow with age
            # print("Sample Size:", sampleN)
            # print(len(df))
            # print("df:",df)
            
            #generate one alpha and one beta for each person
            df[['alpha', 'beta']] = dist_alphaBeta.rvs(sampleN)

            #calculate variance of alpha + t * beta
            #we will later use this variance to adjust for Jensen's inequality
            df['var_alphaBeta'] = sigma_alpha ** 2 + df['t'] ** 2 * sigma_beta ** 2 + 2 * df['t'] * cov_alphaBeta 


            """AR(1) (z)"""

            #initialize the AR(1) at the initial normal. this happens at t=0, before the first simulated period
            df['z_tminus1'] = dist_z0.rvs(sampleN)
            #get z_t for the first simulated period, t=1
            df = AR1(df)

            #calculate variance of z
            #we will use this variance later to adjust for Jensen's inequality
            z_vars = rho**2 * sigma_z0**2 + var_eta

            #merge in the variance of the AR(1)
            df['z_var'] = z_vars


            """TRANSITORY SHOCKS (epsilon)"""
            df = trans_shock(df)


            """NONEMPLOYMENT SHOCKS (nu)"""
            df = nonemp(df)


            """EARNINGS LEVEL (Y)"""

            # We adjust for Jensen's inequality by subtracting half the variance of the idiosyncratic shocks from the new g(t)
            # This is why we stored the variance of alpha, beta, z, eps 

            # Subtracting half the variance means that E[exp{g(t) + a + t*b + z + eps - 1/2 Var(a+bt + z + eps)}|t] = exp(g(t))
            # Otherwise, E[exp(g(t) + a + t*b + z + eps)|t] > exp(g(t)) by Jensen's inequality, since exp() is convex
            #       and alpha, beta, z, and epsilon all have zero mean (but positive variance)

            # df['l2'] = (1 - df['nu'])/(1 - df['mean_nu']) * (np.exp(df['gt'] + df['alpha'] + df['beta'] * df['t'] + df['z'] + df['eps'] 
            #                                                         - (df['var_alphaBeta'] + df['z_var'] + var_eps) / 2))
            df['l2'] = (1 - df['nu']) * np.exp(df['g(t)'] + df['alpha'] + df['beta'] * df['t'] + df['z'] + df['eps'])


            #multiply L2 by the wage index L1, see the CMS main text for more details
            #df = df.merge(SSWageIndex, on = ['year'], how = 'left')
            #df['l'] = df['l1'] * df['l2']

            #deflate to 2013 dollars using the PCE price index
            #df = df.merge(df_pce, on='year', how='left')
            #df['y_real'] = df['l']/df['pce_deflator']
            df['y_real'] = df['l2']

            # above code commented out by CD - removed wage index and pce for Guvenen

            
            """ORDINAL TRANSFORM"""
            
            #create the correct arguments to pass into the ordinal transform function
            #create a column vector where each individual's earnings is one element
            earn_np = np.array(df['y_real'])
            #instead of sex being 0 or 1, in the ordinal transform, gender is coded as "male" or "female"
            sex_keys = ['male', 'female']

            if transformed == True:
                trans_earn = e_ordinal_transform.single_year_transform(earn_np, cohort = cohort_i, gender = sex_keys[sex], age = age_ord_input)
                
                #add transformed earnings to the dataframe
                df['y_trans'] = trans_earn

                #only return relevant variables
                #i is an index for each worker
                output = df[['SSN','y_trans', 'alpha', 'beta', 'z', 'z_var']]
                
                #rename income
                #column 'z' has the values of the AR(1) for the *present year*, but I'll call this column 'z_tminus1'
                #   so that the returned dataframe can be fed into next year's simulation, which expects a column called 'z_tminus1'
                output = output.rename(columns = {'y_trans' : f'inc_{age_j}', 'z' : 'z_tminus1'})
                output_cols = output.columns

            else:
                #only return relevant variables
                #i is an index for each worker
                output = df[['SSN', 'y_real', 'alpha', 'beta', 'z', 'z_var']]
                #rename income
                #column 'z' has the values of the AR(1) for the *present year*, but I'll call this column 'z_tminus1'
                #   so that the returned dataframe can be fed into next year's simulation, which expects a column called 'z_tminus1'
                output = output.rename(columns = {'y_real' : f'inc_{age_j}', 'z' : 'z_tminus1'})
                output_cols = output.columns

            #10% age 25 inco = 16 age inc
            output[f'inc_{age_j}'] = 1/10 * output[f'inc_{age_j}']

            """ASSIGNING EARNINGS"""
            #I'm going to pull a fresh version of df from the cohort_table 
            #this selects cohort_i and age_j
            df = cohort_table.filter(mask).to_pandas()

            #then I'm going to assign output to df
            df.loc[:, output_cols] = output.values
            
            #finally, add the updated df back to table_in

            #turn df into pa table
            updated_table = pa.Table.from_pandas(df)

            #filter out the old rows from table_in
            #invert excludes this age-cohort group
            mask = pc.invert(pc.and_(pc.equal(table_in["cohort"], pa.scalar(cohort_i)),
                                        pc.equal(table_in["age"], pa.scalar(age_j))))
            #filter table_in to remove these rows
            table_in = table_in.filter(mask)

            # if table_in.schema.field('SSN').type != pa.int64():
            #     ssn_array = table_in['SSN'].cast(pa.int64(), safe=False)  # safe=False allows NaNs to remain
            #     table_in = table_in.set_column(
            #         table_in.schema.get_field_index('SSN'),
            #         'SSN',
            #         ssn_array
            #     )
            
            # if updated_table.schema.field('SSN').type != pa.int64():
            #     ssn_array = updated_table['SSN'].cast(pa.int64(), safe=False)
            #     updated_table = updated_table.set_column(
            #         updated_table.schema.get_field_index('SSN'),
            #         'SSN',
            #         ssn_array
            #     )
            
            #now add updated df to table_in
            table_in = pa.concat_tables([table_in, updated_table])

    return table_in


"""
SIMULATE NEXT YEAR'S EARNINGS
"""

def project_earnings(table_in, sex = 0, transformed = True): # Alex VU Not needed
    """simulates next year's earnings for a particular gender.
    this CAN handle MULTIPLE age-cohort groups!
      
    arguments:
    - table_in: a pyarrow table of people you want to simulate with columns "age", "cohort", "SSN", "inc_{age}" for the age you want to simulate,
                and "alpha", "beta", "z_tminus1", "z_var" for each worker.
            I will simulate each age-cohort group as listed in the table.
    - sex: 0 for men, 1 for women
    - transformed: False means the outputted earnings will be the output from the CMS model, 
                    True means the output earnings will be passed through the ordinal transform.
                    The ordinal transform works for ages 25-55, and has data for years 1962-2006

    example call: project_earnings(table_in, sex = 1, transformed = True)

    returns a pyarrow table containing 
    - table_in with incomes filled out for "inc_{age}" for the age I simulated
    - earnings in 2013 dollars (deflated using PCE)
    - UPDATED alpha, beta, z_tminus1, and z_var for each individual

    - the order of rows WILL NOT be preserved
    """

    ####WHAT EACH VARIABLE MEANS####
    """
    - each worker has one alpha and one beta over their lifetime
        - alpha shifts the level of income at all ages
        - beta controls how quickly income grows with age
        - z is the AR(1) component of income. It contributes persistent shocks, 
            e.g. part-year unemployment and subsequent 'scarring' effects to income
        -z_var is the variance of z_t. As a technical detail, we need to track the variance of shocks, 
            so that our simulation has the correct mean income.
    """

    """LOOP OVER COHORTS"""

    
    
    #make a list of all the different cohorts to simulate, and store as a list
    cohorts = pc.unique(table_in["cohort"]).to_pylist()

    for cohort_i in cohorts:
        #filter for only that cohort
        mask = pc.equal(table_in["cohort"], pa.scalar(cohort_i))
        cohort_table = table_in.filter(mask)

        #make a list of all the different cohorts to simulate and their respective sizes
        grouped_ages = cohort_table.group_by("age").aggregate([("SSN", "count")])

        # make a list of ages and sizes
        age_sizes = np.array(grouped_ages["SSN_count"])
        ages = np.array(grouped_ages["age"])  # this is an array of unique cohort values


        """LOOP OVER AGES"""

        for j in range(len(ages)):
            age_j = ages[j]

            #select the rows of cohort_table with this age-cohort combination
            #create a mask
            mask = pc.and_(pc.equal(cohort_table["cohort"], cohort_i),
                pc.equal(cohort_table["age"], age_j))
            
            # Filter the table and save as a dataframe
            df = cohort_table.filter(mask).to_pandas()

            """SET UP INDIVIDUALS"""

            df['sex'] = sex
            df['t'] = (df['age'] - 24) / 10
            df['year'] = df['cohort'] + df['age']

            """LIFE-CYCLE PROFILES g(t)"""

            df = gt(df)             

            """AR(1) (z)"""

            #get z_t for the next simulated period
            df = AR1(df)

            #calculate variance of z
            #we will use this variance later to adjust for Jensen's inequality
            df['z_var'] = rho**2 * df['z_var'] + var_eta

            #ALSO calculate variance of alpha + t * beta
            #we will later use this variance to adjust for Jensen's inequality
            df['var_alphaBeta'] = sigma_alpha ** 2 + df['t'] ** 2 * sigma_beta ** 2 + 2 * df['t'] * cov_alphaBeta 
    
            """TRANSITORY SHOCKS (epsilon)"""
            df = trans_shock(df)

            """NONEMPLOYMENT SHOCKS (nu)"""
            df = nonemp(df)

            """EARNINGS LEVEL (Y)"""

            # We adjust for Jensen's inequality by subtracting half the variance of the idiosyncratic shocks from the new g(t)
            # This is why we stored the variance of alpha, beta, z, eps 

            # Subtracting half the variance means that E[exp{g(t) + a + t*b + z + eps - 1/2 Var(a+bt + z + eps)}|t] = exp(g(t))
            # Otherwise, E[exp(g(t) + a + t*b + z + eps)|t] > exp(g(t)) by Jensen's inequality, since exp() is convex
            #       and alpha, beta, z, and epsilon all have zero mean (but positive variance)

            # df['l2'] = (1 - df['nu'])/(1 - df['mean_nu']) * (np.exp(df['gt'] + df['alpha'] + df['beta'] * df['t'] + df['z'] + df['eps']  
            #                                                         - (df['var_alphaBeta'] + df['z_var'] + var_eps) / 2))
            df['l2'] = (1 - df['nu']) * np.exp(df['g(t)'] + df['alpha'] + df['beta'] * df['t'] + df['z'] + df['eps'])


            #multiply L2 by the wage index L1, see the CMS main text for more details
            #df = df.merge(SSWageIndex, on = ['year'], how = 'left')
            #df['l'] = df['l1'] * df['l2']

            #deflate to 2013 dollars using the PCE price index
            #df = df.merge(df_pce, on='year', how='left')
            #df['y_real'] = df['l']/df['pce_deflator']
            df['y_real'] = df['l2']

            # above code commented out by CD - wage index and pce not used for Guvenen

            """ORDINAL TRANSFORM"""
            #create the correct arguments to pass into the ordinal transform function
            #create a column vector where each individual's earnings is one element
            earn_np = np.array(df['y_real'])
            #instead of sex being 0 or 1, in the ordinal transform, gender is coded as "male" or "female"
            sex_keys = ['male', 'female']

            if transformed == True:
                trans_earn = e_ordinal_transform.single_year_transform(earn_np, cohort = cohort_i, gender = sex_keys[sex], age = age_j)
                
                #add transformed earnings to the dataframe
                df['y_trans'] = trans_earn

                #only return relevant variables
                #i is an index for each worker
                output = df[['SSN','y_trans', 'alpha', 'beta', 'z', 'z_var']]

                # print('output is ' + str(output))
                
                #rename income
                #column 'z' has the values of the AR(1) for the *present year*, but I'll call this column 'z_tminus1'
                #   so that the returned dataframe can be fed into next year's simulation, which expects a column called 'z_tminus1'
                output = output.rename(columns = {'y_trans' : f'inc_{age_j}', 'z' : 'z_tminus1'})
                output_cols = output.columns

            else:
                #only return relevant variables
                #i is an index for each worker
                output = df[['SSN', 'y_real', 'alpha', 'beta', 'z', 'z_var']]
                # print(output)

                #rename income
                #column 'z' has the values of the AR(1) for the *present year*, but I'll call this column 'z_tminus1'
                #   so that the returned dataframe can be fed into next year's simulation, which expects a column called 'z_tminus1'
                output = output.rename(columns = {'y_real' : f'inc_{age_j}', 'z' : 'z_tminus1'})
                output_cols = output.columns

            """ASSIGNING EARNINGS"""
            #I'm going to pull a fresh version of df from the cohort_table 
            #this selects cohort_i and age_j
            df = cohort_table.filter(mask).to_pandas()

            # print('fresh df  ' + str(df))


            #then I'm going to assign output to df
            df.loc[:, output_cols] = output.values

            # print('assigned df  ' + str(df))

            
            #finally, add the updated df back to table_in

            #turn df into pa table
            updated_table = pa.Table.from_pandas(df)

            #filter out the old rows from table_in
            #invert excludes this age-cohort group
            mask = pc.invert(pc.and_(pc.equal(table_in["cohort"], pa.scalar(cohort_i)),
                                        pc.equal(table_in["age"], pa.scalar(age_j))))
            #filter table_in to remove these rows
            table_in = table_in.filter(mask)

            # if table_in.schema.field('SSN').type != pa.int64():
            #     ssn_array = table_in['SSN'].cast(pa.int64(), safe=False)  # safe=False allows NaNs to remain
            #     table_in = table_in.set_column(
            #         table_in.schema.get_field_index('SSN'),
            #         'SSN',
            #         ssn_array
            #     )
            
            # if updated_table.schema.field('SSN').type != pa.int64():
            #     ssn_array = updated_table['SSN'].cast(pa.int64(), safe=False)
            #     updated_table = updated_table.set_column(
            #         updated_table.schema.get_field_index('SSN'),
            #         'SSN',
            #         ssn_array
            #     )

            # display(table_in)
            # display(updated_table) #this table is returning SSN == NaN

            
            #now add updated df to table_in
            table_in = pa.concat_tables([table_in, updated_table])

    return table_in
