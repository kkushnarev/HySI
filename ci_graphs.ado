program define ci_graphs
    version 16.0
    syntax [, VARS(varlist) METHOD(string) SAVE(string)]

    // Step 1: Auto-detect variables from scalars if not provided
    if "`vars'" == "" {
        local vars ""
        tempname logfile
        tempfile scalarlog
		quietly {
        log using `scalarlog', text replace name(`logfile')
		}
        scalar dir
        log close `logfile'

        file open sf using `scalarlog', read text
        file read sf line
        while r(eof) == 0 {
            local eq = strpos("`line'", "=")
            if `eq' > 0 {
                local rawname = substr("`line'", 1, `=`eq'-1')
                if regexm("`rawname'", "^\s*beta_(\S+)\s*$") {
                    local vname = regexs(1)
                    capture confirm scalar beta_`vname'
                    if !_rc & scalar(beta_`vname') != . {
                        local vars `vars' `vname'
                    }
                }
            }
            file read sf line
        }
        file close sf
    }

    // Step 2: Validate found or given variables
    local nvars : word count `vars'
    if `nvars' == 0 {
        di as error "❌ No variables found or provided."
        exit 198
    }

	quietly {
		
    tempfile base
    preserve
    clear
    set obs `nvars'
    gen id = _n
    gen str32 varname = ""
    gen str10 method = ""
    gen double lo = .
    gen double hi = .
    gen double beta = .
	
	
    local i = 1
    foreach v of local vars {
        replace varname = "`v'" in `i'
        local ++i
	}
    }
	quietly {
    save `base', replace
	}
    // Step 3: Extract scalars for each method
    tempfile results
	quietly {
    save `results', emptyok replace
	}
    local allmethods "naive posi sel hysi"
    foreach m of local allmethods {
        if ("`method'" == "" | strpos(" `method' ", "`m'")) {
            use `base', clear
			quietly {
            replace method = "`m'"
			}
            local i = 1
            foreach v of local vars {
                capture confirm scalar `m'_lo_`v'
                if _rc == 0 {
                    quietly replace lo = scalar(`m'_lo_`v') in `i'
                    quietly replace hi = scalar(`m'_hi_`v') in `i'
                    quietly replace beta = scalar(beta_`v') in `i'
                }
                else {
                    quietly replace lo = . in `i'
                    quietly replace hi = . in `i'
                    quietly replace beta = . in `i'
                }
                local ++i
            }
			quietly {
            drop if missing(lo) | missing(hi)
            
			append using `results'
            save `results', replace
			}
        }
    }

    use `results', clear

    // Step 4: CI coverage check
	quietly {
    gen covered = (beta >= lo & beta <= hi)
	}
    quietly {
        count if covered == 0
        if r(N) > 0 {
            di as error "⚠️  The following intervals DO NOT contain the point estimate:"
            levelsof method if covered == 0, local(bad_methods)
            foreach m of local bad_methods {
                levelsof varname if method == "`m'" & covered == 0, local(bad_vars)
                foreach v of local bad_vars {
                    di as error "  → Method: `m' | Variable: `v'"
                }
            }
        }
        else {
            di as result "✅ All CIs contain the point estimate."
        }
    }

    // Step 5: Create offset variable for plotting
    quietly {
	gen offset = 0
    replace offset = -0.3 if method == "naive"
    replace offset = -0.1 if method == "posi"
    replace offset =  0.1 if method == "sel"
    replace offset =  0.3 if method == "hysi"
	}
    // Step 6: Label axis
    levelsof varname, local(varlist)
    local i = 1
    foreach v of local varlist {
        label define varlab `i' "`v'", add
        local ++i
    }
// Map varname to numeric id for plotting (realname-safe)
    quietly {
	egen id_fixed = group(varname)
    label values id_fixed varlab
	}
    quietly {
	gen xplot = id_fixed + offset
	}
    count
    if r(N) == 0 {
        di as error "❌ No data left to plot (maybe all intervals were dropped)."
        exit 198
    }

    // Step 7: Plot CIs and point estimates
    twoway ///
        (rcap lo hi xplot if method=="naive", lcolor(blue) lwidth(medthick)) ///
        (scatter beta xplot if method=="naive", msymbol(circle) mcolor(blue) msize(medlarge)) ///
        (rcap lo hi xplot if method=="posi", lcolor(red) lwidth(medthick)) ///
        (scatter beta xplot if method=="posi", msymbol(square) mcolor(red) msize(medlarge)) ///
        (rcap lo hi xplot if method=="sel", lcolor(green) lwidth(medthick)) ///
        (scatter beta xplot if method=="sel", msymbol(diamond) mcolor(green) msize(medlarge)) ///
        (rcap lo hi xplot if method=="hysi", lcolor(orange) lwidth(medthick)) ///
        (scatter beta xplot if method=="hysi", msymbol(triangle) mcolor(orange) msize(medlarge)) ///
    , ///
        xlabel(1/`nvars', valuelabel angle(45)) ///
        xtitle("Variables") ///
        ytitle("Estimate ± CI") ///
        legend(order(1 "Naive" 3 "PoSI" 5 "Selective" 7 "HySI")) ///
        title("Confidence Intervals by Method") ///
		name(ci_plot, replace) ///
        yscale(range(0 .)) ///
        graphregion(color(white)) ///
        plotregion(margin(zero))

    // Step 8: Save output if requested
    if "`save'" != "" {
        save "`save'", replace
        display as result "✔️ CI data saved to: `save'"
    }

    restore
end
