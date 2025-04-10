{smcl}
{* *! version 1.0.0 09apr2025}{...}
{title:Title}

{phang}
{bf:hysi_tools} — Suite of tools for Hybrid Selective Inference (HySI)

{title:Syntax}

{marker begin_hysi}{...}
{phang}
{bf:begin_hysi} {it:using} {cmd:,} {opt vars(varlist)} {opt y(varname)}

{marker hysi}{...}
{phang}
{bf:hysi} {it:varlist}, {opt outcome(varname)} {opt lambda(real)} {opt delta(real)} [{opt level(real)}]

{marker hsci_table}{...}
{phang}
{bf:hsci_table} {it:varlist} [{opt level(real)} {opt save(filename)}]

{marker ci_graphs}{...}
{phang}
{bf:ci_graphs} [{opt vars(varlist)} {opt method(string)} {opt save(filename)}]

{marker export_results}{...}
{phang}
{bf:export_results}, {opt type(string)} {opt format(string)}

{title:Description}

{pstd}
{bf:hysi_tools} is a collection of commands designed for robust post-selection inference following LASSO. It includes:
- {bf:begin_hysi}: prepares a dataset for analysis by renaming variables and saving a clean copy
- {bf:hysi}: runs the HySI method via LASSO selection and Mata-based inference
- {bf:hsci_table}: generates CI comparison tables across methods (Naive, PoSI, Selective, HySI)
- {bf:ci_graphs}: visualizes confidence intervals by method
- {bf:export_results}: exports formatted results to LaTeX, Excel, CSV, PNG, or .dta

{title:Options & Details}

{dlgtab:begin_hysi}
{phang}
{opt using}: Path to the dataset to be loaded.
{phang}
{opt vars(varlist)}: Predictor variables to be included.
{phang}
{opt y(varname)}: Outcome variable (case-insensitive).

{dlgtab:hysi}
{phang}
{opt outcome(varname)}: Dependent variable.
{phang}
{opt lambda(real)}: LASSO penalty value.
{phang}
{opt delta(real)}: Width tuning parameter for HySI.
{phang}
{opt level(real)}: Confidence level (default = 90).

{dlgtab:hsci_table}
{phang}
{opt level(real)}: Confidence level (default = 0.95).
{phang}
{opt save(filename)}: Optionally save the results as a temporary Stata dataset.

{dlgtab:ci_graphs}
{phang}
{opt vars(varlist)}: Variables to include (defaults to all with available scalars).
{phang}
{opt method(string)}: One or more of {it:naive posi sel hysi}.
{phang}
{opt save(filename)}: Save the underlying data used for plotting.

{dlgtab:export_results}
{phang}
{opt type(string)}: Either {it:table} or {it:graph}.
{phang}
{opt format(string)}: Export format (e.g., {it:latex}, {it:excel}, {it:csv}, {it:dta}, {it:png}).

{title:Examples}

{phang}{cmd:. begin_hysi mydata.dta, vars(educ urban age_sq) y(outcome)}{p_end}
{phang}{cmd:. use mydata_XS.dta, clear}{p_end}
{phang}{cmd:. hysi x1 x2 x3, outcome(y) lambda(1) delta(0.05) level(90)}{p_end}
{phang}{cmd:. hsci_table x1 x2 x3, level(0.95)}{p_end}
{phang}{cmd:. ci_graphs, method(hysi sel)}{p_end}
{phang}{cmd:. export_results, type(table) format(latex)}{p_end}

{title:Author}

{phang}
Developed by {bf:You}, {it:April 2025}

{title:Version}

{phang}
v1.0 — Initial public release
