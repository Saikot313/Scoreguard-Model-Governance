import pickle

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from lib import *

M = pickle.load(open(OUT / "model.pkl", "rb"))
c = con()
df = pd.read_sql("SELECT f.*, s.score, s.pd_hat FROM v_features f JOIN scores s USING(app_id)", c)
df["period"] = df.app_month.map(period_of)
_, pts, lab = score_frame(df, M)
base = df.period == "dev"
A = df.decision == "Approved"
o = df[(df.period == "oot") & A]
bench = metrics(o.bad_12m, -o.score)["gini"]         

months = sorted(m for m in df.app_month.unique() if m > DEV_END)
rows, csi = [], []
for i, m in enumerate(months):
    cur = df[df.app_month == m]
    ap = cur[cur.decision == "Approved"]
    win = df[A & df.app_month.isin(months[max(0, i - 2):i + 1])]
    r = dict(app_month=m, n_apps=len(cur), psi=score_psi(df.score[base], cur.score), mean_score=cur.score.mean(),
             legacy_approval_rate=(cur.decision == "Approved").mean(),
             pred_bad=ap.pd_hat.mean(), actual_bad=ap.bad_12m.mean(), gini=metrics(ap.bad_12m, -ap.score)["gini"],
             ks=metrics(ap.bad_12m, -ap.score)["ks"], gini_roll3=metrics(win.bad_12m, -win.score)["gini"])
    r["cal_ratio"] = r["actual_bad"] / r["pred_bad"]
    r["cal_ratio_roll3"] = win.bad_12m.mean() / win.pd_hat.mean()
    full = i >= 2                                            
    lv = max(2 if r["psi"] > .25 else 1 if r["psi"] > .10 else 0,
             (2 if r["gini_roll3"] / bench < .8 else 1 if r["gini_roll3"] / bench < .9 else 0) if full else 0,
             (2 if r["cal_ratio_roll3"] > 1.3 else 1 if r["cal_ratio_roll3"] > 1.15 else 0) if full else 0)
    r["status"] = ["GREEN", "AMBER", "RED"][lv]
    rows.append(r)
    for v in M["vars"]:                                      
        names = sorted(set(lab[v][base]) | set(lab[v][df.app_month == m]))
        e = lab[v][base].value_counts().reindex(names, fill_value=0)
        a = lab[v][df.app_month == m].value_counts().reindex(names, fill_value=0)
        pp = np.array([M["points"][v].get(k, M["neutral"]) for k in names])
        csi.append(dict(app_month=m, variable=v, char_psi=psi_counts(e, a),
                        csi_points=float(((a / a.sum() - e / e.sum()).values * pp).sum())))
mon, csi = pd.DataFrame(rows), pd.DataFrame(csi)

vint = pd.read_sql("SELECT * FROM v_vintage", c)
roll = pd.read_sql("SELECT * FROM v_roll", c)
roll["rate"] = roll.n / roll.groupby(["cohort_year", "from_bucket"]).n.transform("sum")

fm = []                                                     
mon_df = df[df.period == "monitor"]
for dim in ["gender", "region"]:
    for g, grp in mon_df.groupby(dim):
        ap = grp[grp.decision == "Approved"]
        fm.append(dict(dimension=dim, grp=g, n_apps=len(grp), approval_rate=(grp.decision == "Approved").mean(),
                       gini=metrics(ap.bad_12m, -ap.score)["gini"], pred_bad=ap.pd_hat.mean(), actual_bad=ap.bad_12m.mean()))
fm = pd.DataFrame(fm)
fm["air"] = fm.approval_rate / fm.groupby("dimension").approval_rate.transform("max")

for name, t in [("mon_monthly", mon), ("mon_csi", csi), ("mon_vintage", vint), ("mon_roll", roll), ("mon_fairness", fm)]:
    t.to_sql(name, c, if_exists="replace", index=False)
    t.to_csv(OUT / f"{name}.csv", index=False)
c.commit()


x = np.arange(len(mon)); xt = dict(ticks=x[::2], labels=mon.app_month[::2], rotation=60)
fig, ax = plt.subplots(2, 2, figsize=(14, 8))
ax[0, 0].plot(x, mon.psi, "o-"); ax[0, 0].axhline(.10, c="orange", ls="--"); ax[0, 0].axhline(.25, c="red", ls="--")
ax[0, 0].set(title="Score PSI vs development (amber .10 / red .25)")
ax[0, 1].plot(x, mon.gini_roll3, "o-", label="Gini (rolling 3m)"); ax[0, 1].axhline(bench, c="grey", ls="--", label="OOT benchmark")
ax[0, 1].axhline(.8 * bench, c="red", ls=":", label="-20% alert"); ax[0, 1].legend(); ax[0, 1].set(title="Discrimination (Gini) decay")
ax[1, 0].plot(x, mon.pred_bad * 100, "o-", label="Predicted"); ax[1, 0].plot(x, mon.actual_bad * 100, "s-", label="Actual")
ax[1, 0].legend(); ax[1, 0].set(title="Bad rate % (12m, approved loans)")
hm = csi.pivot(index="variable", columns="app_month", values="char_psi")
im = ax[1, 1].imshow(hm.values, aspect="auto", cmap="Reds"); ax[1, 1].set_yticks(range(len(hm)), hm.index)
ax[1, 1].set_xticks(range(0, len(hm.columns), 2), hm.columns[::2], rotation=60); ax[1, 1].set(title="Characteristic drift (CSI heatmap)")
plt.colorbar(im, ax=ax[1, 1])
for a_ in ax.ravel()[:3]:
    a_.set_xticks(**xt)
plt.tight_layout(); plt.savefig(OUT / "fig_monitoring.png", dpi=130)

fig, ax = plt.subplots(1, 3, figsize=(16, 4.5))
for v_, g in vint.groupby("vintage"):
    ax[0].plot(g.mob, g.rate_90p * 100, label=v_)
ax[0].legend(ncol=3, fontsize=7); ax[0].set(title="Vintage: cumulative 90+ DPD % by quarter", xlabel="Months on book")
for k, yr in enumerate(["2022-2023", "2024"]):
    ys = ["2022", "2023"] if k == 0 else ["2024"]
    r_ = roll[roll.cohort_year.isin(ys)].groupby(["from_bucket", "to_bucket"]).n.sum().unstack(fill_value=0)
    r_ = r_.div(r_.sum(axis=1), axis=0)
    im = ax[k + 1].imshow(r_.values, cmap="Blues", vmin=0, vmax=1)
    for (i, j), val in np.ndenumerate(r_.values):
        ax[k + 1].text(j, i, f"{val:.0%}", ha="center", va="center", fontsize=8)
    ax[k + 1].set(title=f"Roll-rate matrix, {yr} cohorts", xlabel="Next month bucket", ylabel="This month bucket",
                  xticks=range(5), yticks=range(4), xticklabels=["0", "1-29", "30-59", "60-89", "90+"], yticklabels=["0", "1-29", "30-59", "60-89"])
plt.tight_layout(); plt.savefig(OUT / "fig_vintage_rollrate.png", dpi=130)


app_all = df.copy()
SECTORS = ["Trading", "Manufacturing", "Services", "Agro"]
REGIONS = ["Dhaka", "Chattogram", "Rajshahi", "Khulna", "Sylhet"]
quality_rows = []
base_apps = app_all[app_all.period == "dev"]
monthly_counts = app_all[app_all.period == "monitor"].groupby("app_month").size()
for m in months:
    cur = app_all[app_all.app_month == m]
    quality_rows.append(dict(
        app_month=m,
        row_count=len(cur),
        row_count_change=(len(cur) / max(float(monthly_counts.median()) if len(monthly_counts) else 1, 1) - 1),
        duplicate_app_id=int(cur.app_id.duplicated().sum()),
        missing_rate=float(cur[NUM + CAT].isna().mean().mean()),
        invalid_month=int((~cur.app_month.astype(str).str.match(r"^20\d{2}-\d{2}$")).sum()),
        negative_turnover=int((cur.monthly_turnover <= 0).sum()),
        negative_loan=int((cur.loan_amount <= 0).sum()),
        invalid_ratio=int(((cur.loan_to_turnover <= 0) | (cur.loan_to_turnover > 20)).sum()),
        category_anomaly=int((~cur.sector.isin(SECTORS)).sum() + (~cur.region.isin(REGIONS)).sum()),
    ))
quality = pd.DataFrame(quality_rows)
quality["status"] = np.where(
    (quality.missing_rate > .02) | (quality.duplicate_app_id > 0) | (quality.category_anomaly > 0) |
    (quality.negative_turnover > 0) | (quality.negative_loan > 0) | (quality.invalid_ratio > 0), "RED",
    np.where((quality.missing_rate > .005) | (quality.row_count_change.abs() > .15), "AMBER", "GREEN"))


seg_rows = []
mon_seg = app_all[app_all.period == "monitor"].copy()
for dim in ["sector", "region", "gender"]:
    for g, grp in mon_seg.groupby(dim):
        ap = grp[grp.decision == "Approved"]
        if len(ap) < 20:
            continue
        seg_rows.append(dict(segment_type=dim, segment=str(g), n_apps=len(grp), n_approved=len(ap),
                             approval_rate=float((grp.decision == "Approved").mean()),
                             actual_bad=float(ap.bad_12m.mean()), predicted_bad=float(ap.pd_hat.mean()),
                             calibration_ratio=float(ap.bad_12m.mean() / max(ap.pd_hat.mean(), 1e-6)),
                             gini=float(metrics(ap.bad_12m, -ap.score)["gini"]),
                             ks=float(metrics(ap.bad_12m, -ap.score)["ks"]),
                             brier=float(__import__("sklearn.metrics", fromlist=["brier_score_loss"]).brier_score_loss(ap.bad_12m, ap.pd_hat))))
segments = pd.DataFrame(seg_rows)
segments["status"] = np.where((segments.calibration_ratio > 1.30) | (segments.gini < .20), "RED",
                               np.where((segments.calibration_ratio > 1.15) | (segments.gini < .25), "AMBER", "GREEN"))


mm = pd.read_sql("SELECT * FROM mon_model_metrics", c)
challenger = mm[mm.model == "GBM benchmark"].copy().rename(columns={"gini": "challenger_gini", "ks": "challenger_ks", "brier": "challenger_brier"})
champion = mm[mm.model == "Scorecard (champion)"][['period','gini','ks','brier']].rename(columns={'gini':'champion_gini','ks':'champion_ks','brier':'champion_brier'})
champ_chall = champion.merge(challenger[['period','challenger_gini','challenger_ks','challenger_brier']], on='period', how='left')
champ_chall['gini_delta'] = champ_chall.challenger_gini - champ_chall.champion_gini
champ_chall['brier_delta'] = champ_chall.challenger_brier - champ_chall.champion_brier
champ_chall['higher_gini_model'] = np.where(champ_chall.gini_delta > 0, 'Challenger', 'Champion')


from sklearn.linear_model import LogisticRegression
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss
cal_base = df[(df.decision == 'Approved') & (df.period == 'oot')].copy()
cal_mon = df[(df.decision == 'Approved') & (df.period == 'monitor')].copy()
def logit_clip(p):
    p = np.clip(np.asarray(p, float), 1e-5, 1-1e-5)
    return np.log(p/(1-p))
cal_lr = LogisticRegression(C=1e6, fit_intercept=True).fit(logit_clip(cal_base.pd_hat).reshape(-1,1), cal_base.bad_12m)
cal_mon['platt_pd'] = cal_lr.predict_proba(logit_clip(cal_mon.pd_hat).reshape(-1,1))[:,1]
iso = IsotonicRegression(out_of_bounds='clip').fit(cal_base.pd_hat, cal_base.bad_12m)
cal_mon['isotonic_pd'] = iso.predict(cal_mon.pd_hat)
recal_rows = []
for name, p in [('Original', cal_mon.pd_hat), ('Platt', cal_mon.platt_pd), ('Isotonic', cal_mon.isotonic_pd)]:
    recal_rows.append(dict(model=name, period='monitor', brier=float(brier_score_loss(cal_mon.bad_12m,p)),
                           actual_bad=float(cal_mon.bad_12m.mean()), predicted_bad=float(np.mean(p)),
                           calibration_ratio=float(cal_mon.bad_12m.mean()/max(np.mean(p),1e-6))))
recalibration = pd.DataFrame(recal_rows)


latest = mon.iloc[-1]
latest_q = quality.iloc[-1]
latest_seg = segments
fair_score = max(0, min(100, 100 * float(fm.air.min()))) if not fm.empty else 100
stability_score = 100 if latest.psi < .10 else 75 if latest.psi < .25 else 40
disc_ratio = latest.gini_roll3 / max(bench, 1e-6)
disc_score = max(0, min(100, disc_ratio * 100))
cal_score = max(0, min(100, 100 / max(latest.cal_ratio_roll3, 1)))
quality_score = 100 if latest_q.status == 'GREEN' else 70 if latest_q.status == 'AMBER' else 35
overall_health = round(.20*stability_score + .25*disc_score + .25*cal_score + .20*quality_score + .10*fair_score, 1)
health_status = 'GREEN' if overall_health >= 85 else 'AMBER' if overall_health >= 65 else 'RED'

health = pd.DataFrame([dict(as_of=latest.app_month, overall_health=overall_health, stability=round(stability_score,1),
                             discrimination=round(disc_score,1), calibration=round(cal_score,1), data_quality=quality_score,
                             fairness=round(fair_score,1), status=health_status)])

incidents = []
for _, r in mon[mon.app_month >= "2024-01"].iterrows():
    checks = [('Score PSI', r.psi, .10, .25, 'feature/score distribution drift'),
              ('Gini decay', r.gini_roll3/bench if bench else 1, .90, .80, 'ranking power deterioration'),
              ('Calibration ratio', r.cal_ratio_roll3, 1.15, 1.30, 'actual risk exceeds predicted risk')]
    for metric, val, amber, red, evidence in checks:
        if (metric == 'Gini decay' and val < red) or (metric != 'Gini decay' and val > red): sev='RED'
        elif (metric == 'Gini decay' and val < amber) or (metric != 'Gini decay' and val > amber): sev='AMBER'
        else: continue
        incidents.append(dict(incident_id=f"INC-{str(r.app_month).replace('-','')}-{metric[:3].upper()}", detected_month=r.app_month,
                              severity=sev, metric=metric, value=float(val), amber_threshold=amber, red_threshold=red,
                              evidence=evidence, affected_segment='Portfolio', status='Open'))
for _, r in quality[(quality.app_month >= "2024-01") & (quality.status != 'GREEN')].iterrows():
    incidents.append(dict(incident_id=f"INC-{str(r.app_month).replace('-','')}-DQ", detected_month=r.app_month,
                          severity=r.status, metric='Data Quality', value=float(r.missing_rate), amber_threshold=.005,
                          red_threshold=.02, evidence='Data quality threshold breached', affected_segment='Portfolio', status='Open'))
incidents = pd.DataFrame(incidents).drop_duplicates('incident_id')
if not incidents.empty:
    if (incidents.severity == 'RED').any(): health.loc[0, 'status'] = 'RED'
    elif (incidents.severity == 'AMBER').any() and health.loc[0, 'status'] == 'GREEN': health.loc[0, 'status'] = 'AMBER'

health.to_csv(OUT / 'model_health.csv', index=False)
quality.to_csv(OUT / 'data_quality.csv', index=False)
segments.to_csv(OUT / 'segment_monitoring.csv', index=False)
champ_chall.to_csv(OUT / 'champion_challenger.csv', index=False)
recalibration.to_csv(OUT / 'recalibration_lab.csv', index=False)
incidents.to_csv(OUT / 'model_incidents.csv', index=False)
for name, t in [('model_health',health),('data_quality',quality),('segment_monitoring',segments),('champion_challenger',champ_chall),('recalibration_lab',recalibration),('model_incidents',incidents)]:
    t.to_sql(name, c, if_exists='replace', index=False)
c.commit()

report = f"""<!doctype html><html><head><meta charset='utf-8'><title>ScoreGuard Monthly Model Governance Report</title>
<style>body{{font-family:Arial;max-width:1100px;margin:40px auto;line-height:1.5}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #ddd;padding:8px}}th{{background:#f3f4f6}}.card{{display:inline-block;padding:18px;margin:6px;border:1px solid #ddd;border-radius:10px}}.red{{color:#b91c1c}}.amber{{color:#b45309}}.green{{color:#15803d}}</style></head><body>
<h1>ScoreGuard Monthly Model Governance Report</h1><p><b>As of:</b> {latest.app_month} &nbsp; <b>Data:</b> simulated SME portfolio</p>
<div class='card'><b>Model Health</b><br><span class='{health.status.iloc[0].lower()}'>{overall_health}/100 ({health.status.iloc[0]})</span></div>
<div class='card'><b>Score PSI</b><br>{latest.psi:.3f}</div><div class='card'><b>Rolling Gini</b><br>{latest.gini_roll3:.3f}</div>
<div class='card'><b>Calibration Ratio</b><br>{latest.cal_ratio_roll3:.2f}</div><div class='card'><b>Open Incidents</b><br>{len(incidents)}</div>
<h2>Key Findings</h2><ul><li>Score PSI alone is not sufficient: calibration and outcome performance are monitored alongside stability.</li><li>Top current segment issues are surfaced in the segment monitoring table.</li><li>Recalibration candidates are evaluated against the original champion.</li></ul>
<h2>Model Health Components</h2>{health.to_html(index=False)}
<h2>Recent Incidents</h2>{incidents.tail(20).to_html(index=False) if not incidents.empty else '<p>No threshold breaches.</p>'}
<h2>Champion vs Challenger</h2>{champ_chall.to_html(index=False)}
<h2>Recalibration Lab</h2>{recalibration.to_html(index=False)}
</body></html>"""
(ROOT / 'reports' / 'monthly_model_governance_report.html').write_text(report, encoding='utf-8')
print('Governance extensions generated:', overall_health, 'health; incidents=', len(incidents))
