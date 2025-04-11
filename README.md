# hysi – Hybrid Selective Inference for LASSO in Stata

**Author**: [Kirill Kushnarev](https://github.com/kkushnarev)  
**Reference**: [McCloskey (Biometrika, 2024)](https://arxiv.org/abs/2011.12873)

## Overview

The **hysi** package implements the Hybrid Confidence Intervals (HySI) method in Stata for valid inference after LASSO-based model selection. The HySI method, proposed by McCloskey (2024), combines the PoSI framework with a selective intervals approach by Lee et al. (2016) to construct confidence intervals that remain valid regardless of the model selected.

This implementation supports:
- LASSO with a fixed, user-chosen lambda
- Confidence intervals from:
  - Naive (frequentist) method
  - PoSI
  - Selective inference [(Lee et al., 2016)]([https://projecteuclid.org/euclid.aos/1462892507](https://projecteuclid.org/journals/annals-of-statistics/volume-44/issue-3/Exact-post-selection-inference-with-application-to-the-lasso/10.1214/15-AOS1371.full))
  - HySI

*An upcoming update will support data-driven lambda selection.*

*A guide to post-selection inference theory and applications to LASSO will also be published soon.*

## Installation

### Option 1: Using `net install`

```stata
. net install hysi, replace from("https://raw.githubusercontent.com/kkushnarev/hysi/main/")
```

### Option 2: Using the `github` package

First, install the GitHub installer (if not already installed):

```stata
. net install github, from("https://haghish.github.io/github/")
```

Then install the hysi package:

```stata
. github install kkushnarev/hysi
```

## Commands

The package provides five commands:

### 1. `begin_hysi`

Prepares a dataset for post-selection inference:
- Standardizes variable names  
- Destrings variables of interest  
- Maps user-specified variables to generic names (`x1`, `x2`, ..., `xn`)  
- Generates a mapping file to restore original variable names during export  
- Checks dimensional consistency
- Suggest a range of suitable a LASSO penalty and an Adjustment parameter based on data dimensionality
  
```stata
begin_hysi using filename, vars(varlist) y(depvar)
```

- `using(filename)` – Path to the Stata dataset (.dta)
- `vars(varlist)` – List of predictors
- `y(depvar)` – Outcome variable

**Example:**

```stata
begin_hysi using Monte_Carlo.dta, vars(Age Education Parents_Income) y(Income)
```

This command creates two temporary files with the suffix `_XS`:

  - One file contains the dataset with renamed and destringed variables.
  - The other is a mapping file that links generic variable names (e.g., `x1`, `x2`, ...) to the original variable names.

Use the `_XS` dataset for all subsequent commands.

These temporary files will be automatically deleted after export.

### 2. `hysi`

Runs LASSO-based variable selection and computes confidence intervals using four methods.

```stata
hysi varlist, outcome(varname) lambda(real) delta(real) [level(real)]
```

- `outcome(varname)` – Dependent variable
- `lambda(real)` – LASSO penalty
- `delta(real)` – Adjustment parameter
- `level(real)` – Confidence level (default: 90)

**Example:**

```stata
hysi x1 x2 x3 x4, outcome(Y) lambda(0.1) delta(0.05) level(90)
```

### 3. `hsci_table`

Generates a table summarizing the confidence intervals and compares widths of Naive and HySI intervals. Also flags significance and out-of-interval results.

```stata
hsci_table x1 x2 x3 x4 [, level(real)]
```

**Example:**

```stata
hsci_table x1 x2 x3 x4
```

### 4. `ci_graphs`

Plots confidence intervals for selected methods.

```stata
ci_graphs [, vars(varlist) method(string) save(string)]
```

- `vars(varlist)` – Variables to include in the plot (auto-detects if omitted)
- `method(string)` – Methods to include (e.g., `"naive posi hysi"`)
- `save(string)` – File path to save CI data

**Example:**

```stata
ci_graphs, method("naive hysi")
```

### 5. `export_results`

Exports results from `hsci_table` or `ci_graphs` to various formats. Automatically remaps generic variable names (e.g., `x1`, `x2`) to original names.

```stata
export_results, type(string) format(string)
```

- `type(string)` – `"table"` or `"graph"`
- `format(string)` – File format:
  - For tables: `latex`, `csv`, `excel`, `dta`
  - For graphs: `png`

**Example:**

```stata
export_results, type(graph) format(png)
```

## Citation and Acknowledgments 

If you use this package, please cite:

McCloskey, A. (2024). *Hybrid Confidence Intervals after Model Selection*. Biometrika.  
[arXiv:2011.12873](https://arxiv.org/abs/2011.12873)

Best wishes to Adam McCloskey, and many thanks for his kind permission to implement his method in Stata.
