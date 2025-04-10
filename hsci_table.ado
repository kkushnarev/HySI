program define hsci_table
    version 16.0
    syntax varlist(min=1) [, Level(real 0.95) Save(string)]

    local k : word count `varlist'
    local alpha = 1 - `level'
    local zcrit = invnormal(1 - `alpha'/2)
	
	quietly list
	quietly count

quietly {
    tempfile resultdata
    preserve
    clear
    set obs `k'

    // Define storage variables
    gen str20 variable = ""
    gen double estimate = .
    gen double se = .
    gen byte selected = .

    gen double naive_lo = .
    gen double naive_hi = .
    gen double posi_lo = .
    gen double posi_hi = .
    gen double sel_lo = .
    gen double sel_hi = .
    gen double hysi_lo = .
    gen double hysi_hi = .

    gen str20 naive_ci = ""
    gen str20 posi_ci = ""
    gen str20 sel_ci  = ""
    gen str20 hysi_ci = ""

    gen double width_naive = .
    gen double width_posi = .
    gen double width_sel = .
    gen double width_hysi = .

    gen str20 best = ""
}
    forvalues j = 1/`k' {
    local var : word `j' of `varlist'

    // Use variable name in scalar references
    capture confirm scalar beta_`var'
    if _rc != 0 continue  // skip this variable if scalars not found

    local b      = scalar(beta_`var')
    local n_lo   = scalar(naive_lo_`var')
    local n_hi   = scalar(naive_hi_`var')
    local p_lo   = scalar(posi_lo_`var')
    local p_hi   = scalar(posi_hi_`var')
    local s_lo   = scalar(sel_lo_`var')
    local s_hi   = scalar(sel_hi_`var')
    local h_lo   = scalar(hysi_lo_`var')
    local h_hi   = scalar(hysi_hi_`var')



        local sel = cond(abs(`b') > 1e-8, 1, 0)
        local se = (`n_hi' - `n_lo') / (2 * `zcrit')

        local w_n = `n_hi' - `n_lo'
        local w_p = `p_hi' - `p_lo'
        local w_s = `s_hi' - `s_lo'
        local w_h = `h_hi' - `h_lo'

        local best = ""
        local sig_h = cond(`h_lo' > 0 | `h_hi' < 0, 1, 0)
        if `sig_h' & `b' >= `h_lo' & `b' <= `h_hi' {
            local minw = min(`w_n', `w_p', `w_s', `w_h')
            if `w_h' == `minw' {
                local best = "HySI"
            }
            else if `w_s' == `minw' {
                local best = "Sel"
            }
            else if `w_p' == `minw' {
                local best = "PoSI"
            }
            else {
                local best = "Naive"
            }
        }

        local ci_naive = "[" + string(`n_lo', "%5.3f") + ", " + string(`n_hi', "%5.3f") + "]"
        local ci_posi  = "[" + string(`p_lo', "%5.3f") + ", " + string(`p_hi', "%5.3f") + "]"
        local ci_sel   = "[" + string(`s_lo', "%5.3f") + ", " + string(`s_hi', "%5.3f") + "]"
        local ci_hysi  = "[" + string(`h_lo', "%5.3f") + ", " + string(`h_hi', "%5.3f") + "]"

        quietly replace variable = "`var'"           in `j'
        quietly replace estimate = `b'               in `j'
        quietly replace se = `se'                    in `j'
        quietly replace selected = `sel'             in `j'

        quietly replace naive_lo = `n_lo'            in `j'
        quietly replace naive_hi = `n_hi'            in `j'
        quietly replace posi_lo = `p_lo'             in `j'
        quietly replace posi_hi = `p_hi'             in `j'
        quietly replace sel_lo = `s_lo'              in `j'
        quietly replace sel_hi = `s_hi'              in `j'
        quietly replace hysi_lo = `h_lo'             in `j'
        quietly replace hysi_hi = `h_hi'             in `j'

        quietly replace naive_ci = "`ci_naive'"      in `j'
        quietly replace posi_ci  = "`ci_posi'"       in `j'
        quietly replace sel_ci   = "`ci_sel'"        in `j'
        quietly replace hysi_ci  = "`ci_hysi'"       in `j'

        quietly replace width_naive = `w_n'          in `j'
        quietly replace width_posi = `w_p'           in `j'
        quietly replace width_sel = `w_s'            in `j'
        quietly replace width_hysi = `w_h'           in `j'

        quietly replace best = "`best'"              in `j'
    }

    gen sig_naive = (naive_lo > 0 | naive_hi < 0) & (estimate >= naive_lo & estimate <= naive_hi)
    gen sig_posi  = (posi_lo  > 0 | posi_hi  < 0) & (estimate >= posi_lo  & estimate <= posi_hi)
    gen sig_sel   = (sel_lo   > 0 | sel_hi   < 0) & (estimate >= sel_lo   & estimate <= sel_hi)
    gen sig_hysi  = (hysi_lo  > 0 | hysi_hi  < 0) & (estimate >= hysi_lo  & estimate <= hysi_hi)

    gen out_naive = (estimate < naive_lo | estimate > naive_hi)
    gen out_posi  = (estimate < posi_lo  | estimate > posi_hi)
    gen out_sel   = (estimate < sel_lo   | estimate > sel_hi)
    gen out_hysi  = (estimate < hysi_lo  | estimate > hysi_hi)

    gen str3 str_selected = cond(selected == 1, "yes", "no")

    format estimate se %9.4f
    format naive_ci posi_ci sel_ci hysi_ci %-20s
    format best %-6s

    di "---------------------------------------------------------------------------------------------------------------------------------------------------"
    di as text ///
       %-9s  "Variable" ///
       %6s   "Sel" ///
       %9s   "Est." ///
       %7s   "SE" ///
       %19s  "Naive CI" %3s "*" %3s "   " ///
       %19s  "PoSI CI"  %3s "*" %3s "   " ///
       %19s  "Sel. CI"  %3s "*" %3s "   " ///
       %19s  "HySI CI"  %3s "*" %3s "   " ///
       %5s   "Best"
    di "---------------------------------------------------------------------------------------------------------------------------------------------------"

    forvalues j = 1/`k' {
        local v   = variable[`j']
        local sel = str_selected[`j']
        local b   = estimate[`j']
        local se  = se[`j']

        local n_ci = naive_ci[`j']
        local p_ci = posi_ci[`j']
        local s_ci = sel_ci[`j']
        local h_ci = hysi_ci[`j']

        local sn = cond(sig_naive[`j'] == 1, "✓", "")
        local sp = cond(sig_posi[`j']  == 1, "✓", "")
        local ss = cond(sig_sel[`j']   == 1, "✓", "")
        local sh = cond(sig_hysi[`j']  == 1, "✓", "")

        local on = cond(out_naive[`j'] == 1, "OUT", "")
        local op = cond(out_posi[`j']  == 1, "OUT", "")
        local os = cond(out_sel[`j']   == 1, "OUT", "")
        local oh = cond(out_hysi[`j']  == 1, "OUT", "")

        local best = best[`j']

        di as text ///
           %-9s "`v'" ///
           %6s "`sel'" ///
           %9.4f `b' ///
           %7.4f `se' ///
           %19s "`n_ci'" %3s "`sn'" %3s "`on'" ///
           %19s "`p_ci'" %3s "`sp'" %3s "`op'" ///
           %19s "`s_ci'" %3s "`ss'" %3s "`os'" ///
           %19s "`h_ci'" %3s "`sh'" %3s "`oh'" ///
           %5s "`best'"
    }

    di "-------------------------------------------------------------------------------------------------------------------------------------------------------------"

    tempvar diff

	quietly {
    gen `diff' = width_naive - width_hysi if best == "HySI" & sig_naive == 1 & sig_hysi == 1
	}

	count if !missing(`diff')
	if r(N) > 1 {
    quietly ttest `diff' = 0
    // Custom summary line only
    di as result "📊 Paired t-test on width difference (Naive - HySI) for best == HySI:"
    di as text   "    t = " %6.3f r(t) ", p = " %6.4f r(p) ///
                 ", 95% CI = [" %6.3f r(lb) ", " %6.3f r(ub) "]"
	}
	else {
    di as error "⚠️ Not enough observations where best == HySI and both CIs are significant for t-test."
	}

	quietly save "temp_table.dta", replace
	
    restore
	
	
	
end
