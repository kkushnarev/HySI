program define begin_hysi
    version 16.0
    syntax using/, vars(string) y(string)

    // --- Step 1: Load the dataset ---
    capture confirm file "`using'"
    if _rc {
        di as error "Dataset `using' not found."
        exit 601
    }
    use "`using'", clear
    di as txt "Loaded dataset: `using'"

    // --- Step 2: Find outcome variable (case-insensitively) ---
    local outcome ""
    foreach var of varlist _all {
         if lower("`var'") == lower("`y'") {
             local outcome "`var'"
             break
         }
    }
    if "`outcome'" == "" {
         di as error "Outcome variable `y' not found."
         exit 198
    }
    di as txt "Outcome variable: `outcome' found"
    local orig_outcome = "`outcome'"

    // --- Step 3: Prepare a temporary mapping file ---
    local base = subinstr("`using'", ".dta", "", .)
    local mapfile_path = "`base'_temp_map.dta"
    tempname maphandle
    postfile `maphandle' str32 xvar str32 origvar using "`mapfile_path'", replace

    // --- Step 4: Rename outcome variable to generic "y" and record mapping ---
    rename `outcome' y
    di as txt "Renamed outcome variable: `orig_outcome' -> y"
    local outcome = "y"
    post `maphandle' ("y") ("`orig_outcome'")

    // --- Step 5: Get full list of variables ---
    ds
    local allvars `r(varlist)'

    // --- Step 6: Rename selected predictor variables (case-insensitively) ---
    local i = 1
    local matched_vars ""
    foreach orig in `vars' {
         local found = 0
         local real_orig = ""
         foreach var of local allvars {
              if lower("`var'") == lower("`orig'") {
                    local found = 1
                    local real_orig "`var'"
                    break
              }
         }
         if (`found' == 1) {
             local newvar = "x" + string(`i')
             di as txt "Renaming `real_orig' -> `newvar'"
             rename `real_orig' `newvar'
             capture confirm numeric variable `newvar'
             if _rc {
                 quietly destring `newvar', replace force
             }
             post `maphandle' ("`newvar'") ("`real_orig'")
             if "`matched_vars'" == "" {
                 local matched_vars "`newvar'"
             }
             else {
                 local matched_vars "`matched_vars' `newvar'"
             }
             local ++i
         }
         else {
             di as error "Variable `orig' not found — skipping"
         }
    }
    postclose `maphandle'

    // --- Step 7: Check if any predictors were renamed ---
    if "`matched_vars'" == "" {
         di as error "No valid predictor variables were renamed. Exiting."
         capture erase "`mapfile_path'"
         exit 111
    }

    // --- Step 8: Save cleaned dataset (keep renamed outcome and predictors) ---
    keep `outcome' `matched_vars'
    save "`base'_XS.dta", replace
    di as result "Saved cleaned dataset: `base'_XS.dta"

    // --- Step 9: Save mapping file without replacing in-memory data ---
    capture confirm file "`mapfile_path'"
    if _rc {
         di as error "Mapping file was not created!"
         exit 499
    }
    // Copy the mapping file to its final destination without loading it into memory.
    copy "`mapfile_path'" "`base'_XS_map.dta", replace
    erase "`mapfile_path'"
    di as result "Saved variable mapping: `base'_XS_map.dta"
	
	quietly count
	local N = r(N)
	local K : word count `matched_vars'
	di as txt "Dimensionality check: N = `N', K = `K'"
	local ratio = `N' / `K'
	di as txt "Sample-to-variable ratio (N/K): " %4.2f `ratio'

	if (`ratio' < 2) {
    di as error "⚠️  Warning: You have fewer than 2 observations per predictor. This may lead to overfitting 	or 	unstable inference."
    local Kmax = floor(`N'/2)
    di as txt "👉 Suggest reducing predictors to ≤ `Kmax'"
	}

	local suggest_lambda = 0.1
	local suggest_delta = 0.05
	local suggest_level = 90

	if (`K' >= 0.5 * `N') {
    local suggest_lambda = 0.4
    local suggest_delta = 0.1
    local suggest_level = 85
	}

	di as result "Suggested defaults based on dimensionality:"
	di as txt    "  lambda(`suggest_lambda')"
	di as txt    "  delta(`suggest_delta')"
	di as txt    "  level(`suggest_level')"

end
