import numpy as np
import pandas as pd
import statsmodels.api as sm

LIFECYCLE_INCOME_ORIG = "datastore/raw/lifecycle_income/orig"
START_COHORT = 1949
END_COHORT = 2009
TOTAL_YEARS = END_COHORT - START_COHORT + 1
EXCEL_PATH = f"{LIFECYCLE_INCOME_ORIG}/gksw2017.xlsx"
cohorts = list(range(START_COHORT, END_COHORT + 1))

def create_year_for_each_age(df, cohort):
  """
  Stata code:

  gen year = .
  replace year = cohort if age == 25
  replace year = cohort + (age-25) if age > 25
  """

  df = df.copy()
  df["year"] = np.nan
  df.loc[df["age"] == 25, "year"] = cohort
  df.loc[df["age"] > 25, "year"] = cohort + (df.loc[df["age"] > 25, "age"] - 25)
  return df

def merge_average_ssa_income(df, avg_ssa):
  """
  Stata code:

  merge m:1 year using avg, keep(3) nogen
  """

  # inner join (only keeps rows where year exists for both, which is same as keep(3))
  return df.merge(avg_ssa, on="year", how="inner")

def create_cohort_earnings_variables (log_cohort_earnings, ssa_average_earnings):
  """
  Stata code:

  gen cohort_earnings = exp(log_cohort_earnings)/1000
  gen cohort_earnings_over_average = cohort_earnings/ssa_average_earnings
  gen log_cohort_earnings_over_average = ln(cohort_earnings_over_average)
  """

  cohort_earnings = np.exp(log_cohort_earnings)/1000
  cohort_earnings_over_average = cohort_earnings/ssa_average_earnings
  log_cohort_earnings_over_average = np.log(cohort_earnings_over_average)
  return log_cohort_earnings_over_average

def create_age_polynomials(df):
  """
  Stata code:

  rename age age_1
  gen age_2 = age_1^2
  gen age_3 = age_1^3
  """

  df = df.rename(columns={'age': 'age_1'})
  df['age_2'] = df['age_1'] ** 2
  df['age_3'] = df['age_1'] ** 3
  return df

def main():
    coef_store_male = np.full((4, TOTAL_YEARS), np.nan)
    coef_store_female = np.full((4, TOTAL_YEARS), np.nan)
    avg_ssa = pd.read_excel(EXCEL_PATH, sheet_name="data_mean_2013d_impute")
    avg_ssa = avg_ssa[['year', 'ssa']].rename(columns={'ssa': 'ssa_average_earnings'})

    for sex in ['male', 'female']:
        for cohort in range(START_COHORT, END_COHORT + 1):
            df = pd.read_excel(EXCEL_PATH, sheet_name=f"{sex}_3")
            df = df[['age', f'c_{cohort}']].rename(columns={f'c_{cohort}': 'log_cohort_earnings'})

            df = create_year_for_each_age(df, cohort)
            df = merge_average_ssa_income(df, avg_ssa)
            df = create_age_polynomials(df)

            df['log_cohort_earnings_over_average'] = create_cohort_earnings_variables(
                df['log_cohort_earnings'],
                df['ssa_average_earnings']
            )

            X = df[['age_1', 'age_2', 'age_3']]
            X = sm.add_constant(X)
            y = df['log_cohort_earnings_over_average']
            model = sm.OLS(y, X, missing="drop").fit()

            col_idx = cohort - START_COHORT
            if sex == 'male':
                coef_store_male[0, col_idx] = model.params['age_1']
                coef_store_male[1, col_idx] = model.params['age_2']
                coef_store_male[2, col_idx] = model.params['age_3']
                coef_store_male[3, col_idx] = model.params['const']
            else:
                coef_store_female[0, col_idx] = model.params['age_1']
                coef_store_female[1, col_idx] = model.params['age_2']
                coef_store_female[2, col_idx] = model.params['age_3']
                coef_store_female[3, col_idx] = model.params['const']

            print(f"Coefficients for {sex}s from {cohort} cohort are complete")

    for sex, coef_matrix in [('male', coef_store_male), ('female', coef_store_female)]:
        df_out = pd.DataFrame(coef_matrix, index=["age_1", "age_2", "age_3", "_cons"], columns=[f"c_{c}" for c in cohorts],) 
        output_path = f"datastore/derived/lifecycle_income/lifecycle_income_{sex}.csv"
        df_out.to_csv(output_path, index=True)

if __name__ == "__main__":
   main()