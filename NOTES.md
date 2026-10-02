# NOTES: concepts explained simply (interview prep)

**WoE (Weight of Evidence)** = ln(%good in bin / %bad in bin). Positive → bin is safer than average. Converts every variable to the same "risk scale" so a logistic regression can combine them. Bins are forced to have a monotone bad-rate trend and ≥5% of data each (`fit_bins` in `lib.py`).

**IV (Information Value)** = Σ (%good − %bad) × WoE. Predictive strength of one variable: <0.02 useless, 0.02-0.1 weak, 0.1-0.3 medium, >0.3 strong. Here variables with IV < 0.02 are dropped.

**Scorecard scaling:** score = offset + factor × ln(good:bad odds), with factor = PDO / ln 2. We chose 600 points = 50:1 odds and PDO = 20 (every +20 points doubles good:bad odds). Each bin gets "points"; an applicant's score is the sum.

**Gini / AUC / KS:** all measure ranking power (do bads get lower scores than goods?). Gini = 2·AUC − 1. KS = max gap between the cumulative good and bad score distributions. Typical real SME scorecards land roughly 0.3-0.5 Gini.

**Out-of-time (OOT) validation:** test on a *later* period than training, because the model will be used on the future. Random splits overstate performance.

**PSI (Population Stability Index):** has the score distribution shifted vs development? <0.10 stable, 0.10-0.25 watch, >0.25 act. **CSI** is the same idea per input variable (shows *which* variable moved). `csi_points` converts the shift into average score points.

**Why PSI was not enough here:** in 2024 PSI stays ≤0.10 but the actual bad rate is far above predicted. Population mix changed little, but *risk per customer* rose (concept drift). Hence we also monitor calibration (actual / predicted) and Gini.

**Calibration vs discrimination:** discrimination = ranking; calibration = the level of predicted PD. A model can rank well and still under-predict losses. Fix: recalibrate (shift the intercept) before full rebuild.

**Reject inference:** we only see outcomes for approved loans (selection bias). Fuzzy augmentation re-adds rejected applicants as partly-bad / partly-good rows weighted by an assumed PD. It cannot be proven from data; treat as a sensitivity check.

**Vintage analysis:** delinquency by origination quarter against months on book; shows whether newer cohorts go bad faster. **Roll-rate matrix:** probability of moving between DPD buckets next month (e.g. 30-59 → 60-89).

**Adverse Impact Ratio (AIR):** a group's approval rate ÷ highest group's approval rate; below 0.80 is a common review flag. It is a screen, not proof of unfairness.

## Likely interview questions
1. Why use an interpretable scorecard as the champion context? → transparent risk ranking and easier model governance, while the GBM remains a challenger/reference benchmark.
2. Why was OOT Gini lower than dev? → in-sample optimism, expected; the OOT figure is the honest one.
3. PSI is fine but bad rate is rising: what do you do? → check calibration, CSI drivers, vintages and segment performance; evaluate recalibration and investigate data or portfolio changes before escalating through model governance.
4. What are the weaknesses of your project? → simulated data, limited reject-inference evidence, illustrative monitoring thresholds, and a Python-tested pipeline with an R Shiny investigation layer.
