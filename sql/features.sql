
CREATE INDEX IF NOT EXISTS ix_perf ON performance(app_id, mob);

DROP VIEW IF EXISTS v_outcome;
CREATE VIEW v_outcome AS
SELECT app_id,
       MAX(dpd_bucket = 4)                                    AS bad_12m,
       MIN(CASE WHEN dpd_bucket = 4 THEN mob END)             AS first_90_mob
FROM performance GROUP BY app_id;


DROP VIEW IF EXISTS v_features;
CREATE VIEW v_features AS
SELECT a.*,
       loan_amount * 1.0 / monthly_turnover                                        AS loan_to_turnover,
       (loan_amount * (1 + 0.15 * tenure_months / 12.0) / tenure_months)
           / monthly_turnover                                                       AS emi_to_turnover,
       monthly_turnover * 1.0
           / AVG(monthly_turnover) OVER (PARTITION BY sector, app_month)           AS turnover_vs_sector,
       o.bad_12m
FROM applications a LEFT JOIN v_outcome o USING (app_id);

DROP VIEW IF EXISTS v_vintage;
CREATE VIEW v_vintage AS
SELECT substr(a.app_month,1,4) || 'Q' || ((CAST(substr(a.app_month,6,2) AS INT) + 2) / 3) AS vintage,
       p.mob,
       COUNT(*)                         AS n_loans,
       AVG(p.dpd_bucket >= 2)           AS rate_30p,
       AVG(p.dpd_bucket = 4)            AS rate_90p
FROM performance p JOIN applications a USING (app_id)
GROUP BY 1, 2;

DROP VIEW IF EXISTS v_roll;
CREATE VIEW v_roll AS
SELECT substr(a.app_month,1,4) AS cohort_year,
       p1.dpd_bucket AS from_bucket, p2.dpd_bucket AS to_bucket, COUNT(*) AS n
FROM performance p1
JOIN performance p2 ON p2.app_id = p1.app_id AND p2.mob = p1.mob + 1
JOIN applications a ON a.app_id = p1.app_id
WHERE p1.dpd_bucket < 4
GROUP BY 1, 2, 3;
