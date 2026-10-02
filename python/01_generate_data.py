
import numpy as np
import pandas as pd
from lib import DB, ROOT, con

rng = np.random.default_rng(42)
months = pd.period_range("2022-01", "2024-12", freq="M")
SECTORS, SP = ["Trading", "Manufacturing", "Services", "Agro"], [.42, .20, .28, .10]
REGIONS, RP = ["Dhaka", "Chattogram", "Rajshahi", "Khulna", "Sylhet"], [.38, .22, .14, .14, .12]
SEC = {"Trading": .10, "Manufacturing": -.10, "Services": 0., "Agro": .35}
REG = {"Dhaka": 0., "Chattogram": 0., "Rajshahi": .05, "Khulna": .05, "Sylhet": .15}
INTERCEPT = -2.1
sig = lambda z: 1 / (1 + np.exp(-z))


def dpd_paths(bad):
   
    n = len(bad)
    T = np.array([[.93, .07, 0, 0], [.6, .15, .25, 0], [.4, .2, .15, .25], [.35, 0, .3, .35]])
    P, s = np.zeros((n, 12), np.int8), np.zeros(n, int)
    for t in range(12):                       
        s = np.minimum((rng.random(n)[:, None] > T[s].cumsum(1)).sum(1), 3)
        P[:, t] = s
    dm = rng.integers(4, 13, n)[:, None]      
    mob = np.arange(1, 13)[None, :]
    ramp = np.select([mob >= dm, mob == dm - 1, mob == dm - 2, mob == dm - 3], [4, 3, 2, 1], default=-1)
    return np.where(bad[:, None], np.where(ramp >= 0, ramp, np.minimum(P, 1)), P)


apps, perf, aid, thr = [], [], 0, None
for i, m in enumerate(months):
    n = int(1400 * (1 + .01 * i) * rng.uniform(.9, 1.1))
    stress = max(0, i - 23) / 12
    sector, region = rng.choice(SECTORS, n, p=SP), rng.choice(REGIONS, n, p=RP)
    turn = np.exp(np.log(450_000) + rng.normal(0, .7, n) + np.where(sector == "Manufacturing", .35, 0)
                  - np.where(sector == "Agro", .2, 0)) * (1 - .15 * stress)
    loan = (np.clip(turn * rng.uniform(1, 6, n), 2e5, 2.5e7) / 1000).round() * 1000
    tenure = rng.choice([12, 24, 36, 48, 60], n, p=[.15, .3, .3, .15, .1])
    age_b = np.clip(np.exp(rng.normal(1.6, .7, n)), .5, 40).round(1)
    coll = np.clip(rng.normal(.9, .5, n), 0, 2).round(2)
    nl = rng.poisson(1.1, n)
    cib = rng.binomial(1, .12 + .06 * stress, n)
    vol = np.clip(rng.normal(.35 + .08 * stress, .15, n), .05, 1.2).round(3)
    lic = rng.binomial(1, .85, n)
    dig = rng.beta(2, 3, n).round(3)
    emi_t = loan * (1 + .15 * tenure / 12) / tenure / turn
    z = (INTERCEPT + .9 * cib - .28 * np.log(age_b) - .45 * (np.log(turn) - np.log(450_000))
         + 2.0 * (emi_t - .14) + .1 * (loan / turn - 3.5) + 1.0 * vol * (1 + 1.0 * stress)
         - .35 * coll - .6 * dig + .12 * nl - .35 * lic
         + np.vectorize(SEC.get)(sector) + np.vectorize(REG.get)(region) + .12 * stress)
    z = -1.8 + 1.5 * (z - INTERCEPT)            
    latent = z + rng.normal(0, .25, n)                    
    bad = rng.random(n) < sig(latent)
    legacy = z + rng.normal(0, .9, n)                     
    thr = np.quantile(legacy, .70) if thr is None else thr  
    appr = legacy <= thr
    ids = np.arange(aid + 1, aid + n + 1); aid += n
    apps.append(pd.DataFrame(dict(
        app_id=ids, app_month=str(m), sector=sector, region=region,
        gender=rng.choice(["M", "F"], n, p=[.82, .18]), owner_age=np.clip(rng.normal(41, 9, n), 23, 70).round(),
        business_age=age_b, monthly_turnover=turn.round(), loan_amount=loan, tenure_months=tenure,
        collateral_ratio=coll, existing_loans=nl, cib_overdue=cib, inflow_volatility=vol,
        digital_txn_share=dig, has_trade_license=lic, decision=np.where(appr, "Approved", "Rejected"))))
    P = dpd_paths(bad[appr])
    perf.append(pd.DataFrame(dict(app_id=np.repeat(ids[appr], 12), mob=np.tile(np.arange(1, 13), appr.sum()),
                                  dpd_bucket=P.ravel())))

DB.unlink(missing_ok=True)
c = con()
pd.concat(apps).to_sql("applications", c, index=False)
pd.concat(perf).to_sql("performance", c, index=False)
c.executescript((ROOT / "sql" / "features.sql").read_text())
c.commit()

f = pd.read_sql("SELECT substr(app_month,1,4) y, COUNT(*) apps, AVG(decision='Approved') approval, "
                "AVG(bad_12m) bad_rate_approved FROM v_features GROUP BY 1", c)
print(f.round(3).to_string(index=False))
