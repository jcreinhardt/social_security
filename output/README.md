# output/

Holds one **run directory** per estimation (the shared "workdir" that all TikTak
workers coordinate through). Default: `output/run_2param/`.

A run directory contains the file-based coordination state and results:

```
state                 current phase (INIT … DONE)
*.lock                fcntl advisory locks (mutexes / atomic counters)
sobol_counter         next Sobol index to claim
local_counter         next local-start index to claim
n_sobol, n_starts     phase sizes
sobol_points.npy      the drawn Sobol point set
sobol/<i>.json        one file per Sobol evaluation  {i, x, f}
x_starts.npy          kept best-K local-search start points
x_starts_vals.npy     their objective values
local/<k>.json        one file per local search       {k, x, f}
final_result.json     polished best (written by the engine)
final_results.json    summary + recovery (written by worker 0)
tiktak_2param_results.csv   per-start results (written by worker 0)
```

These are run artifacts and are git-ignored (collaborate via Dropbox, per the
repo `.gitignore`). Start each run with a fresh workdir; `run_tiktak.py --spawn`
wipes the workdir automatically unless `--resume` is passed.
