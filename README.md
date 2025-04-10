# hysi - An implementation of a hybrid confidence interval method

Annotation: [McCloskey (Biometrika, 2024)](https://arxiv.org/abs/2011.12873) proposes a hybrid confidence interval (HySi) method to adjust coverage after a model selection event. This method combines the PoSI framework with a frequentist approach and constructs valid confidence intervals regardless of the model selection outcome, drawn from a set of alternatives. I implement the HySi framework in Stata (the hysi package) for LASSO regression using a fixed, user-chosen lambda. 

An upcoming update will extend the package to support data-driven lambda selection. To facilitate comparison with other post-selection inference methods, the hysi package also includes alternative approaches such as PoSI and selective inference [(Lee et al., 2016)](https://projecteuclid.org/journals/annals-of-statistics/volume-44/issue-3/Exact-post-selection-inference-with-application-to-the-lasso/10.1214/15-AOS1371.full). Detailed functionality is available in the package help file. To familiarise the user with post-selected inference, I will soon publish a document guides on the theory and the applications to the LASSO framework.

# Installation

There are two ways to install the package:

### 1. Directly using `net install`

```
. net install hysi, replace from("https://raw.githubusercontent.com/kkushnarev/hysi/main/")
```

### 2. Using the `github` package

First, install the GitHub installer (if not already installed):

```
. net install github, from("https://haghish.github.io/github/")
```

Then install the `hysi` package:

```
. github install kkushnarev/hysi
```

# Usage

