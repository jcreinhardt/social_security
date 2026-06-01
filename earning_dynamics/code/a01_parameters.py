# Title: a01_parameters
#
# By: Jackson J. Howell
# Updated: 05/28/2024
#
# Code Dependencies: a02, b block
#
# Data Input: None
#
# Data Output: None
#
# This code file imports Python packages throughout the entire repository. It also sets important variables
# like the file paths directing scripts to data, code, and output directories. It sets parameters used for the
# construction of historical and projected cohort flows, such as the assumed maximum age of life, the years
# bounding our historical data, and options for how historical flows are constructed.

## Import statements

# fp variables contain file paths to important parts of repository

from pathlib import Path
fp_root = Path('a01_parameters.py').parent.absolute().parent.absolute() # we get where this file is located
fp_code = fp_root / 'code' # relative to the fp_root we define code, data, and output folders
fp_data = fp_root / 'data'
fp_outp = fp_root / 'output'

#Import libraries
import pandas as pd
import numpy as np
import pickle

import pyarrow as pa 
import pyarrow.parquet as pq
import pyarrow.compute as pc
import pyarrow.csv as pcsv

import statsmodels.api as sm



# import ranond so we can use a seed to reproduce randomness
import random  
import importlib
import os
import sys


# #import multiprocessing
# import multiprocessing as mp
# from multiprocessing import Manager, Value, Pool
# numCores = mp.cpu_count() - 1
# print("Number of Cores:",numCores)

# ## import dask dependencies
# import dask
# from dask import delayed, compute
# from dask.distributed import Client
# import dask.dataframe as dd

#use mpi
# from mpi4py import MPI



pd.options.display.max_rows = 200 # set the number of rows avaliable shown in a dataframe
pd.options.display.max_columns = 200

import matplotlib.pyplot as plt
plt.style.use('a02_presentation.mplstyle')
from matplotlib import cm

from statistics import mean

from itertools import product

## Set parameters for producing population
seed = 998
fractionalPerson = True
weight = 10000
# Demographic parameters

lifeage_first = 0
lifeage_last = 119

workage_first = 0
workage_last = 99

histyear_first = 1937
histyear_last = 2020

histcohort_first = histyear_first - lifeage_last
histcohort_last = histyear_last

baseyear = 2023
projyear = 2023

projyear_first = histyear_last + 1
projyear_last = 3000

projcohort_first = histcohort_first
projcohort_last = projyear_last

# Program parameters

smoothing_sensitivity = 1

## Import convenience functions

# from b01_smooth import *
# from b02_get_discount_vector import *
# from b03_project_flows import *
# from b04_construct_mat_proj import *
# from b05_slnp import *
# from b06_dpln import *


