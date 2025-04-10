mata:
// HySI Step 1: Compute affine constraints
void compute_affine_constraints(real matrix X, real scalar lambda, string vector signs, real scalar n,
                                real matrix A_out, real matrix b_out) {
    real scalar k, i, sgn;
    k = cols(X);
    A_out = J(2*k, n, 0);
    b_out = J(2*k, 1, 0);
    for (i = 1; i <= k; i++) {
        real rowvector xi;
        xi = X[., i]';
        sgn = (signs[i] == "+" ? 1 : -1);
        A_out[2*i-1, .] = xi;
        b_out[2*i-1] = lambda * n * sgn;
        A_out[2*i, .] = -xi;
        b_out[2*i] = -lambda * n * sgn;
    }
}

// Truncated CDF for the normal distribution over [a, b]
real scalar truncated_cdf(real scalar z, real scalar mu, real scalar sigma, real scalar a, real scalar b) {
    real scalar alpha, beta, z_std, result;
    alpha = (a - mu) / sigma;
    beta = (b - mu) / sigma;
    z_std = (z - mu) / sigma;
    result = (normal(z_std) - normal(alpha)) / (normal(beta) - normal(alpha));
    return(result);
}

// Inverse CDF (quantile function) for the truncated normal distribution
real scalar inverse_trunc_cdf(real scalar p, real scalar mu, real scalar sigma, real scalar a, real scalar b) {
    real scalar z;
    z = mu;
    real scalar eps;
    eps = 1e-6;
    real scalar diff;
    diff = 1;
    real scalar maxiter;
    maxiter = 100;
    real scalar i;
    i = 0;
    while (abs(diff) > eps & i < maxiter) {
        i++;
        real scalar cdf_val;
        cdf_val = truncated_cdf(z, mu, sigma, a, b);
        real scalar pdf_val;
        pdf_val = dphi((z - mu) / sigma) / sigma;
        real scalar denom;
        denom = (phi((b - mu) / sigma) - phi((a - mu) / sigma));
        if (abs(denom) < 1e-8) {
            printf("⚠️ Warning: truncation denominator too small.\n");
            break;
        }
        real scalar grad;
        grad = pdf_val / denom;
        diff = (cdf_val - p) / grad;
        z = z - diff;
    }
    if (i == maxiter) {
        printf("⚠️ Warning: inverse_trunc_cdf did not converge (p = %.4f)\n", p);
    }
    return(z);
}

// Simulate the PoSI constant using Monte Carlo simulation
real scalar simulate_posi_constant(real matrix X, real matrix V_hat, real scalar M, real scalar alpha) {
    real scalar n;
    n = rows(X);
    real scalar k;
    k = cols(X);

    real matrix XtXinv;
    XtXinv = invsym(cross(X, X));

    real matrix Q;
    Q = XtXinv * X';

    real matrix max_t;
    max_t = J(M, 1, .);

    real scalar i;
    for (i = 1; i <= M; i++) {
        real matrix e;
        e = rnormal(n, 1, 0, 1);
        real matrix t;
        t = Q * e;
        real matrix t_std;
        t_std = t :/ sqrt(diagonal(V_hat));
        max_t[i] = max(abs(t_std));
    }

    _sort(max_t, 1);

    real scalar idx;
    idx = ceil((1 - alpha) * rows(max_t));
    return(max_t[idx]);
}

// Helper: Extract signs from the beta_hat vector
string vector get_signs_from_betahat(real matrix beta_hat) {
    string vector signs
	signs = J(rows(beta_hat), 1, "+");
    real scalar i;
    for (i = 1; i <= rows(beta_hat); i++) {
        if (beta_hat[i, 1] < 0) signs[i] = "-";
    }
    return(signs);
}

// HySI Step 2: OLS estimation and inference
void hysi_step2(real matrix Y, real matrix X, string vector xnames, string vector signs,
                real scalar lambda, real scalar delta, real scalar level) {

    printf("\n✅ Entered hysi_step2()\n");
    printf("Y: %g×%g, X: %g×%g\n", rows(Y), cols(Y), rows(X), cols(X));
    printf("xnames: %g | signs: %g\n", length(xnames), length(signs));

    real scalar i;
    for (i = 1; i <= length(xnames); i++) {
        printf("   → Var: %s | Sign: %s\n", xnames[i], signs[i]);
    }

    real scalar n;
    n = rows(X);
    real scalar k;
    k = cols(X);

    real matrix XtX;
    XtX = cross(X, X);
    real matrix XtY;
    XtY = cross(X, Y);
    real matrix beta_hat;
    beta_hat = invsym(XtX) * XtY;

    // If no signs provided, infer from beta_hat.
    if (length(signs) == 0) {
        signs = get_signs_from_betahat(beta_hat);
        printf("ℹ️ Inferred signs from beta_hat:\n");
        for (i = 1; i <= length(signs); i++) {
            printf("   → Var: %s | Sign: %s\n", xnames[i], signs[i]);
        }
    }

    real matrix resids;
    resids = Y - X * beta_hat;
    real matrix tmp;
    tmp = (resids' * resids) / (n - k);  // tmp is 1×1
    real scalar sigma2;
    sigma2 = tmp[1,1];
    real matrix V_hat;
    V_hat = sigma2 * invsym(XtX);

    printf("sigma2 (raw): %g\n", sigma2);
    if (missing(sigma2)) {
        printf("⚠️ sigma2 is missing!\n");
    }
    printf("OLS done. sigma² = %g\n", sigma2);

    real matrix A, b;
    compute_affine_constraints(X, lambda, signs, n, A, b);
    printf("✅ Constraints: %g rows in A\n", rows(A));

    real scalar posi_const;
    posi_const = simulate_posi_constant(X, V_hat, 1000, 0.05);
    printf("PoSI constant (95 percentage): %g\n", posi_const);

    hysi_compare_ci(Y, X, sigma2, V_hat, beta_hat, A, b, level, xnames, posi_const, delta);
    printf("✅ Inference complete.\n");
}

// Helper functions for normal density and CDF
real scalar phi(real scalar z) {
    return(normal(z));
}
real scalar dphi(real scalar z) {
    return(normalden(z));
}

// HySI Step 3: Use selected and PoSI frameworks to calculate HySI

void hysi_compare_ci(real matrix Y, real matrix X, real scalar sigma2, real matrix V_hat, real matrix beta_hat,
                     real matrix A, real matrix b, real scalar level,
                     string vector xnames, real scalar posi_const, real scalar delta) {

    printf("\n%-12s %-10s %-22s %-22s %-22s %-22s\n", 
           "Variable", "Estimate", "Naive CI", "PoSI CI", "Selective CI", "HySI CI");

    real scalar k;
    k = cols(X);
    real scalar alpha;
    alpha = 1 - level;
    real scalar zcrit;
    zcrit = invnormal(1 - alpha/2);
    real scalar alpha_hysi;
    alpha_hysi = (alpha - delta) / (1 - delta);

    real scalar j;
    for (j = 1; j <= k; j++) {

        real scalar beta;
        beta = beta_hat[j, 1];
        real scalar se;
        se = sqrt(V_hat[j, j]);

        real scalar naive_lo;
        naive_lo = beta - zcrit * se;
        real scalar naive_hi;
        naive_hi = beta + zcrit * se;

        real scalar posi_lo;
        posi_lo = beta - posi_const * se;
        real scalar posi_hi;
        posi_hi = beta + posi_const * se;

        // eta is the j-th predictor as a rowvector (1 x n)
        // real rowvector eta;
        // eta =  X[., j]' / (X[., j]' * X[., j]);
		
		// Normalize the j-th predictor.
		real rowvector xj
		xj = X[., j]';
		real scalar norm_xj_sq
		norm_xj_sq = xj * xj';
		real rowvector c
		c = xj / norm_xj_sq;

		// Compute the pivot statistic and its standard error on the OLS scale.
		real scalar T
		T = (c * Y)[1,1];
		real scalar se_T
		se_T = sqrt(sigma2 / norm_xj_sq);


        // Compute contrast T and its standard error
        // real scalar T;
        // T = (eta * Y)[1,1];
        // real scalar varT;
        // varT = sigma2 * (eta * eta')[1,1];
        // real scalar se_T;
        // se_T = sqrt(sigma2 / (X[., j]' * X[., j]));

        // Compute Ay and Ae, forcing them to be column vectors.
        real matrix Ay, Ae, bounds;
        Ay = colshape(A * Y, rows(A));                   // (2*k x 1)
        Ae = colshape(A * c', rows(A));
        Ay = colshape(Ay, rows(A));     // ensure column vector
        Ae = colshape(Ae, rows(A));     // ensure column vector
        b = colshape(b, rows(A));       // b should already be (2*k x 1)
        
		real matrix cand_bounds;
		cand_bounds = (b - Ay) :/ Ae;        // elementwise division, (2*k x 1)
        cand_bounds = colshape(cand_bounds, rows(A)); // force column shape

				
        real matrix cond_upper
		cond_upper = (Ae :> 1e-8);
        real matrix upper_candidates
		upper_candidates = select(cand_bounds, cond_upper);
		
        // Explicitly create condition matrices for select()
        real matrix cond_lower
		cond_lower = (Ae :< - 1e-8);
		real matrix lower_candidates
		lower_candidates = select(cand_bounds, cond_lower);

        //printf("✅ lower_candidates: %g rows\n", rows(lower_candidates));
        //printf("✅ upper_candidates: %g rows\n", rows(upper_candidates));
        //printf("b - Ay summary: min = %g, max = %g\n", min(b - Ay), max(b - Ay));

        real scalar trunc_lb, trunc_ub;
        if (rows(lower_candidates) > 0) {
            trunc_lb = max(lower_candidates);
        } else {
            trunc_lb = -1e6;
        }
        if (rows(upper_candidates) > 0) {
            trunc_ub = min(upper_candidates);
        } else {
            trunc_ub = 1e6;
        }

		// **** New: Ensure proper ordering of truncation bounds ****
		if (trunc_lb > trunc_ub) {
		real scalar tmp;
		tmp = trunc_lb;
		trunc_lb = trunc_ub;
		trunc_ub = tmp;
		
		

		
}

// Print dimensions for debugging (if nedeed):
// printf("Dimensions: A: %gx%g, Ay: %gx%g, Ae: %gx%g, b: %gx%g\n", rows(A), cols(A), rows(Ay), cols(Ay), rows(Ae), cols(Ae), rows(b), cols(b));
// printf("cand_bounds: %gx%g, lower_candidates: %gx%g, upper_candidates: %gx%g\n", rows(cand_bounds), cols(cand_bounds), rows(lower_candidates), cols(lower_candidates), rows(upper_candidates), cols(upper_candidates));
// printf("DEBUG: T = %g, se_T = %g, trunc_lb = %g, trunc_ub = %g\n", T, se_T, trunc_lb, trunc_ub);

        real scalar sel_lo, sel_hi;
        sel_lo = inverse_trunc_cdf(alpha / 2, T, se_T, trunc_lb, trunc_ub);
        sel_hi = inverse_trunc_cdf(1 - alpha / 2, T, se_T, trunc_lb, trunc_ub);

        real scalar hybrid_lb;
        hybrid_lb = (trunc_lb > posi_lo ? trunc_lb : posi_lo);
        real scalar hybrid_ub;
        hybrid_ub = (trunc_ub < posi_hi ? trunc_ub : posi_hi);
		
		// **** New: Ensure hybrid bounds are properly ordered ****
		if (hybrid_lb > hybrid_ub) {
		real scalar temp;
		temp = hybrid_lb;
		hybrid_lb = hybrid_ub;
		hybrid_ub = temp;
		}

        real scalar hysi_lo;
        hysi_lo = inverse_trunc_cdf(alpha_hysi / 2, T, se_T, hybrid_lb, hybrid_ub);
        real scalar hysi_hi;
        hysi_hi = inverse_trunc_cdf(1 - alpha_hysi / 2, T, se_T, hybrid_lb, hybrid_ub);
		
		// Store CI bounds for variable j in Stata scalars
		string scalar sj
		string scalar vname
		vname = xnames[j]

		stata("scalar beta_" + vname + " = " + strofreal(beta))
		stata("scalar naive_lo_" + vname + " = " + strofreal(naive_lo))
		stata("scalar naive_hi_" + vname + " = " + strofreal(naive_hi))
		stata("scalar posi_lo_" + vname + " = " + strofreal(posi_lo))
		stata("scalar posi_hi_" + vname + " = " + strofreal(posi_hi))
		stata("scalar sel_lo_" + vname + " = " + strofreal(sel_lo))
		stata("scalar sel_hi_" + vname + " = " + strofreal(sel_hi))
		stata("scalar hysi_lo_" + vname + " = " + strofreal(hysi_lo))
		stata("scalar hysi_hi_" + vname + " = " + strofreal(hysi_hi))



        printf("%-12s %-10.4f [%-8.4f, %-8.4f] [%-8.4f, %-8.4f] [%-8.4f, %-8.4f] [%-8.4f, %-8.4f]\n",
               xnames[j],
               beta, 
               naive_lo, naive_hi,
               posi_lo, posi_hi,
               sel_lo, sel_hi,
               hysi_lo, hysi_hi);
    }
}



// HySI Step 4: main wrapper (Loads data from Stata and calls the inference procedure).
real void hysi(string scalar yvar, string scalar selvars, real scalar lambda, real scalar delta, real scalar level, | string vector signs_in)
{
    // Load dependent and independent variables
    real matrix Y
	Y = st_data(., yvar);
    real matrix X
	X = st_data(., selvars);

    // Extract variable names from the predictor list
    string vector xnames
	xnames = tokens(selvars);

    // Initialize signs vector; if not provided (or provided as empty), default to "+"
    string vector signs;
    if ((args() < 7) | (length(signs_in) == 0)) {
        signs = J(cols(X), 1, "+");
    }
    else {
        signs = signs_in;
        if (length(signs) != cols(X)) {
            printf("❌ Error: signs vector length (%g) does not match number of predictors (%g)\n", length(signs), cols(X));
            exit(198);
        }
    }

    // Diagnostics
    printf("\n✅ Entered hysi()\n");
    printf("Dependent variable (Y): %s\n", yvar);
    printf("Predictors: %s\n", selvars);
    printf("λ = %g, δ = %g, level = %g\n", lambda, delta, level);
    printf("Number of predictors: %g\n", cols(X));
    real scalar i;
    for (i = 1; i <= length(xnames); i++) {
        printf("   → Var: %s | Sign: %s\n", xnames[i], signs[i]);
    }

    // Call main inference procedure
    hysi_step2(Y, X, xnames, signs, lambda, delta, level);


}
end
