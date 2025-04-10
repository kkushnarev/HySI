program define export_results
    version 16.0
    syntax, type(string) format(string)

    // --- Load HySI results from temp table ---
    capture quietly use temp_table.dta, clear
    if _rc {
        di as error "❌ Could not load temp_table.dta. Ensure hsci_table was run."
        exit 601
    }

    // --- Confirm 'variable' column exists ---
    capture confirm variable variable
    if _rc {
        di as error "❌ Dataset must contain a 'variable' column from hsci_table."
        exit 111
    }

    // --- Cross-platform scan for *_XS_map.dta file ---
    tempfile filelist
    tempname fh
    local mapfile ""

    if c(os) == "Windows" {
        quietly shell dir /b *_XS_map.dta > "`filelist'"
    }
    else {
        quietly shell ls *_XS_map.dta > "`filelist'"
    }

    capture file open `fh' using "`filelist'", read text
    if _rc {
        di as error "❌ Could not read file list to find *_XS_map.dta."
        exit 601
    }

    file read `fh' line
    while r(eof) == 0 {
        if regexm("`line'", ".*_XS_map\.dta$") {
            local mapfile "`line'"
            continue, break
        }
        file read `fh' line
    }
    file close `fh'

    if "`mapfile'" == "" {
        di as error "❌ No *_XS_map.dta file found in the current directory."
        exit 602
    }

    // --- Extract base name for output
    local prefix : subinstr local mapfile "_XS_map.dta" "", all
    local outputfile = "`prefix'_export"

    // --- Drop & create fresh mapframe ---
    capture confirm frame mapframe
    if !_rc {
        frame change default
        frame drop mapframe
    }
    frame create mapframe
    frame mapframe: use "`mapfile'", clear

    // --- Confirm required variables in mapframe ---
    frame mapframe: capture confirm variable xvar
    if _rc {
        di as error "❌ Mapping file must contain a variable named 'xvar'."
        exit 603
    }

    frame mapframe: capture confirm variable origvar
    if _rc {
        di as error "❌ Mapping file must contain a variable named 'origvar'."
        exit 606
    }

    // --- Merge original names into default frame
    capture frlink m:1 variable, frame(mapframe xvar)
    if _rc {
        di as error "❌ Could not link variable to xvar in mapframe."
        exit 604
    }

    capture frget origvar, from(mapframe)
    if _rc {
        di as error "❌ Could not retrieve origvar from mapframe."
        exit 605
    }

    replace variable = origvar if !missing(origvar)
    drop origvar

    // --- Force all CI columns and 'best' to string (if needed) ---
    foreach col in naive_ci posi_ci sel_ci hysi_ci best {
        capture confirm string variable `col'
        if _rc {
            capture tostring `col', replace force
        }
    }

    // === EXPORT SECTION ===

if "`type'" == "table" & "`format'" == "latex" {
    
    // --- Ensure all columns are strings ---
    foreach col in naive_ci posi_ci sel_ci hysi_ci best {
        capture confirm string variable `col'
        if _rc {
            tostring `col', replace force
        }
    }

    // --- Open LaTeX file ---
    file open texout using "`outputfile'.tex", write replace
    file write texout ///
        "\begin{table}[htbp]\centering" _n ///
        "\caption{HySI CI Table}" _n ///
        "\resizebox{\textwidth}{!}{" _n ///
        "\begin{tabular}{lccccc}" _n ///
        "\hline\hline" _n ///
        "Variable & Naive CI & PoSI CI & Sel. CI & HySI CI & Best \\\\" _n ///
        "\hline" _n

    // --- Generate lines ---
    forvalues i = 1/`=_N' {
        local v = variable[`i']
        local n = naive_ci[`i']
        local p = posi_ci[`i']
        local s = sel_ci[`i']
        local h = hysi_ci[`i']
        local b = best[`i']

        // Escape underscores for LaTeX
        local v : subinstr local v "_" "\\_", all

        file write texout "`v' & `n' & `p' & `s' & `h' & `b' \\\\" _n
    }

    // --- Close LaTeX table ---
    file write texout ///
        "\hline\hline" _n ///
        "\end{tabular}}" _n ///
        "\end{table}"
    file close texout
	di as result "✔ Exported LaTeX table to `outputfile'.tex"
}





    else if "`type'" == "table" & "`format'" == "excel" {
        export excel using "`outputfile'.xlsx", firstrow(variables) replace
        di as result "✔ Exported Excel table to `outputfile'.xlsx"
    }

    else if "`type'" == "table" & "`format'" == "csv" {
        export delimited using "`outputfile'.csv", replace
        di as result "✔ Exported CSV table to `outputfile'.csv"
    }

    else if "`type'" == "table" & "`format'" == "dta" {
        save "`outputfile'.dta", replace
        di as result "✔ Exported Stata dataset to `outputfile'.dta"
    }

    else if "`type'" == "graph" & "`format'" == "png" {
        graph export "`outputfile'.png", replace
        di as result "✔ Exported graph to `outputfile'.png"
    }

    else {
        di as error "❌ Unsupported export type (`type') or format (`format')."
        exit 198
    }

    // === CLEANUP SECTION ===

    // Delete temp_table.dta
    capture confirm file "temp_table.dta"
    if !_rc {
        erase temp_table.dta
        di as text "🧹 Deleted temp_table.dta"
    }

    // Delete temp_* and *_XS_map.dta and *_XS.dta files
    if c(os) == "Windows" {
        shell for %f in (temp_*) do @del "%f" >nul 2>&1
        shell for %f in (*_XS_map.dta) do @del "%f" >nul 2>&1
        shell for %f in (*_XS.dta) do @del "%f" >nul 2>&1
    }
    else {
        shell find . -maxdepth 1 -type f \( -name "temp_*" -o -name "*_XS_map.dta" -o -name "*_XS.dta" \) -exec rm {} \;
    }

    di as text "🧹 Deleted temp_*, *_XS_map.dta, and *_XS.dta files in working directory"
end
