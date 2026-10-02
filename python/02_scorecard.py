
import pickle

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss

from lib import *

c = con()
df = pd.read_sql("SELECT * FROM v_features", c)
df["period"] = df.app_month.map(period_of)
appr = df[df.decision == "Approved"]
dev = appr[appr.period == "dev"]
y = dev.bad_12m.values.astype(float)


bins, woes, ivs = {}, {}, {}
for v in NUM + CAT:
    bins[v] = fit_bins(dev[v], y, "num" if v in NUM else "cat")
    t = woe_table(assign(dev[v], bins[v]), y)
    woes[v], ivs[v] = t.woe.to_dict(), t.iv.sum()
iv = pd.Series(ivs).sort_values(ascending=False)
iv.rename("iv").to_csv(OUT / "iv_summary.csv")
print("IV:\n", iv.round(3).to_string())


def woe_X(d, vs):
    return pd.DataFrame({v: pd.Series(assign(d[v], bins[v]), index=d.index).map(woes[v]) for v in vs}).fillna(0)



cand = list(iv[iv >= 0.02].index)
Xw = woe_X(dev, cand)
keep = []
for v in cand:
    if all(abs(np.corrcoef(Xw[v], Xw[k])[0, 1]) < 0.7 for k in keep):
        keep.append(v)


def fit_lr(vs, sample=None, X=None, yy=None, w=None):
    X = woe_X(dev, vs) if X is None else X[vs]
    yy = (1 - y) if yy is None else yy               
    return LogisticRegression(C=1e6, max_iter=2000).fit(X, yy, sample_weight=w)


lr = fit_lr(keep)
while (lr.coef_[0] <= 0).any():
    keep.pop(int(np.argmin(lr.coef_[0])))
    lr = fit_lr(keep)
print("Final variables:", keep)


def build_model(lr, keep):
    factor = PDO / np.log(2)
    offset = BASE - factor * np.log(ODDS)
    n = len(keep)
    pts = {v: {k: factor * lr.coef_[0][i] * w + (offset + factor * lr.intercept_[0]) / n
               for k, w in woes[v].items()} for i, v in enumerate(keep)}
    return dict(vars=keep, bins=bins, woes=woes, points=pts, neutral=(offset + factor * lr.intercept_[0]) / n,
                factor=factor, offset=offset, coef=dict(zip(keep, lr.coef_[0])), intercept=lr.intercept_[0])


M = build_model(lr, keep)
pd_from_score = lambda s: 1 / (1 + np.exp((s - M["offset"]) / M["factor"]))
score, _, _ = score_frame(df, M)
df["score"], df["pd_hat"] = score, pd_from_score(score)


rej = df[(df.decision == "Rejected") & (df.period == "dev")]
p_bad = np.clip(rej.pd_hat * 1.5, 0, 1).values              
Xa = pd.concat([woe_X(dev, keep), woe_X(rej, keep), woe_X(rej, keep)])
ya = np.r_[1 - y, np.ones(len(rej)), np.zeros(len(rej))]     # good flag
wa = np.r_[np.ones(len(y)), 1 - p_bad, p_bad]
lr_ri = fit_lr(keep, X=Xa, yy=ya, w=wa)
M_ri = build_model(lr_ri, keep)
df["score_ri"] = score_frame(df, M_ri)[0]


Xg = pd.get_dummies(df[NUM + CAT].assign(**{k: df[k].astype(str) for k in CAT}), dtype=float)
gbm = HistGradientBoostingClassifier(max_depth=3, learning_rate=.05, max_iter=150, min_samples_leaf=200, random_state=0)
gbm.fit(Xg.loc[dev.index], y)
df["gbm_pd"] = gbm.predict_proba(Xg)[:, 1]

# ---- 5. validation: dev / out-of-time / monitoring-year (approved loans, known outcomes) ---------
rows = []
for per in ["dev", "oot", "monitor"]:
    d = df[(df.decision == "Approved") & (df.period == per)]
    for name, risk, p in [("Scorecard (champion)", -d.score, d.pd_hat), ("Scorecard + reject inference", -d.score_ri, None),
                          ("GBM benchmark", d.gbm_pd, d.gbm_pd)]:
        r = dict(model=name, period=per, n=len(d), **metrics(d.bad_12m, risk))
        r["brier"] = brier_score_loss(d.bad_12m, p) if p is not None else np.nan
        rows.append(r)
mm = pd.DataFrame(rows)
mm.to_csv(OUT / "model_metrics.csv", index=False)
print(mm.round(3).to_string(index=False))

# ---- 6. scorecard table, calibration, figure -------------------------------------------------------
sc_rows = []
for v in keep:
    t = woe_table(assign(dev[v], bins[v]), y)
    nm = bin_names(bins[v], list(t.index))
    for k, r in t.iterrows():
        sc_rows.append(dict(variable=v, bin=nm[k], n=int(r.n), bad_rate=r.bad_rate, woe=r.woe, iv=r.iv,
                            points=round(M["points"][v][k], 1)))
sc = pd.DataFrame(sc_rows)
sc.to_csv(OUT / "scorecard_points.csv", index=False)

oot = df[(df.decision == "Approved") & (df.period == "oot")].copy()
oot["decile"] = pd.qcut(oot.score, 10, labels=False, duplicates="drop")
cal = oot.groupby("decile").agg(mean_score=("score", "mean"), pred_bad=("pd_hat", "mean"), actual_bad=("bad_12m", "mean"), n=("score", "size"))
cal.to_csv(OUT / "calibration_oot.csv")

fig, ax = plt.subplots(1, 3, figsize=(15, 4.2))
ax[0].plot(cal.pred_bad, cal.actual_bad, "o-"); ax[0].plot([0, cal.pred_bad.max()], [0, cal.pred_bad.max()], "--", c="grey")
ax[0].set(title="Calibration (OOT, score deciles)", xlabel="Predicted bad rate", ylabel="Actual bad rate")
for lab, g in oot.groupby("bad_12m"):
    ax[1].hist(g.score, bins=30, alpha=.6, density=True, label="Bad" if lab else "Good")
ax[1].set(title="Score distribution (OOT)", xlabel="Score"); ax[1].legend()
p = mm[mm.period != "dev"].pivot(index="model", columns="period", values="gini")[["oot", "monitor"]]
p.plot.barh(ax=ax[2], legend=True); ax[2].set(title="Gini: scorecard vs GBM", xlabel="Gini")
plt.tight_layout(); plt.savefig(OUT / "fig_scorecard.png", dpi=130)

# ---- 7. persist ------------------------------------------------------------------------------------
pickle.dump(M, open(OUT / "model.pkl", "wb"))
df[["app_id", "score", "pd_hat"]].to_sql("scores", c, if_exists="replace", index=False)
sc.to_sql("scorecard_points", c, if_exists="replace", index=False)
mm.to_sql("mon_model_metrics", c, if_exists="replace", index=False)
c.commit()
print("saved model + scores")
