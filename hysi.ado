capture mata: mata drop hysi
capture mata: mata drop hysi_step2
capture mata: mata drop hysi_compare_ci
capture mata: mata drop compute_affine_constraints
quietly do "`c(sysdir_plus)'h/hysi.mata"


program define hysi, eclass
    version 16.0
	

	
    // Parse syntax
    syntax varlist(min=1), OUTCOME(varname) LAMBDA(real) DELTA(real) [LEVEL(real 90)]

    // Assign local variables
    local predictors `varlist'
    local yvar `outcome'
    local lambda `lambda'
    local delta `delta'
    local level `level'

    // Default level if not specified
    if "`level'" == "" {
        local level = 90
    }

    // Display diagnostics
    di as text "→ Running HySI with:"
    di "   Outcome:     `yvar'"
    di "   Predictors:  `predictors'"
    di "   Lambda:      `lambda'"
    di "   Delta:       `delta'"
    di "   Level:       `level'%"

    // Run LASSO silently to determine selected variables
    quietly lasso linear `yvar' `predictors', lambda(`lambda')

    // Extract selected predictors
    matrix b = e(b)
    local selected_vars
    foreach var of varlist `predictors' {
        quietly scalar beta = b[1, colnumb(b, "`var'")]
        if abs(beta) > 1e-8 {
            local selected_vars `selected_vars' `var'
        }
    }

    // Handle case of no selected variables
    if "`selected_vars'" == "" {
        di as error "❌ No predictors selected by LASSO at lambda = `lambda'"
        exit 459
    }

    di as text "✅ Selected predictors for inference:"
    foreach sv in `selected_vars' {
        di "   → `sv'"
    }

    // Call Mata function
    // Use tokens to properly format string list of predictors
    mata: hysi("`yvar'", "`selected_vars'", `lambda', `delta', `level'/100)
	
end


