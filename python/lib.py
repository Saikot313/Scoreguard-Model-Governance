import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import ks_2samp
from sklearn.metrics import roc_auc_score

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "scoreguard.db"
OUT = ROOT / "outputs"
for p in (OUT, ROOT / "data", ROOT / "reports"):
    p.mkdir(exist_ok=True)

NUM = ["business_age", "owner_age", "monthly_turnover", "loan_to_turnover", "emi_to_turnover",
       "collateral_ratio", "existing_loans", "inflow_volatility", "digital_txn_share",
       "turnover_vs_sector", "tenure_months"]
CAT = ["sector", "region", "cib_overdue", "has_trade_license"]
BASE, ODDS, PDO = 600, 50, 20          
DEV_END, OOT_END = "2023-06", "2023-12"  
def con():
    return sqlite3.connect(DB)


def period_of(m):
    return "dev" if m <= DEV_END else "oot" if m <= OOT_END else "monitor"


def metrics(y, risk):
    """AUC / Gini / KS where `risk` is higher for riskier accounts and y=1 is bad."""
    y, risk = np.asarray(y), np.asarray(risk)
    a = roc_auc_score(y, risk)
    return dict(auc=a, gini=2 * a - 1, ks=ks_2samp(risk[y == 1], risk[y == 0]).statistic)



def fit_bins(x, y, kind, minfrac=0.05):
    if kind == "cat":
        s = x.astype(str)
        vc = s.value_counts(normalize=True)
        return {"kind": "cat", "keep": list(vc[vc >= minfrac].index)}
    xv = x.values.astype(float)
    edges = np.unique(np.quantile(xv, np.linspace(0, 1, 11)[1:-1]))
    sign = np.sign(np.corrcoef(xv, y)[0, 1]) or 1.0
    while len(edges):
        idx = np.searchsorted(edges, xv, side="right")
        k = len(edges) + 1
        cnt = np.bincount(idx, minlength=k)
        br = np.bincount(idx, weights=y, minlength=k) / np.maximum(cnt, 1)
        small = np.where(cnt < minfrac * len(xv))[0]
        viol = np.where(np.diff(br) * sign < 0)[0]
        if len(small):
            j = small[0]
            edges = np.delete(edges, j if j < len(edges) else j - 1)
        elif len(viol):
            edges = np.delete(edges, viol[0])
        else:
            break
    return {"kind": "num", "edges": edges}


def assign(x, b):
    if b["kind"] == "cat":
        s = x.astype(str)
        return s.where(s.isin(b["keep"]), "Other").values
    return np.searchsorted(b["edges"], x.values.astype(float), side="right")


def woe_table(lbl, y):
    g = pd.DataFrame({"b": lbl, "bad": y}).groupby("b").agg(n=("bad", "size"), bad=("bad", "sum"))
    g["good"] = g.n - g.bad
    dg = (g.good + .5) / (g.good.sum() + .5 * len(g))
    db = (g.bad + .5) / (g.bad.sum() + .5 * len(g))
    g["woe"] = np.log(dg / db)
    g["iv"] = (dg - db) * g.woe
    g["bad_rate"] = g.bad / g.n
    return g


def bin_names(b, keys):
    if b["kind"] == "cat":
        return {k: str(k) for k in keys}
    e, out = b["edges"], {}
    for k in keys:
        lo = "-inf" if k == 0 else f"{e[k - 1]:.4g}"
        hi = "inf" if k == len(e) else f"{e[k]:.4g}"
        out[k] = f"[{lo}, {hi})"
    return out


def score_frame(d, M):
    pts, lab = pd.DataFrame(index=d.index), pd.DataFrame(index=d.index)
    for v in M["vars"]:
        l = pd.Series(assign(d[v], M["bins"][v]), index=d.index)
        lab[v] = l
        pts[v] = l.map(M["points"][v]).fillna(M["neutral"])
    return pts.sum(axis=1).clip(300, 850).round(), pts, lab


def psi_counts(e, a):
    e = np.clip(np.asarray(e, float) / np.sum(e), 1e-4, None)
    a = np.clip(np.asarray(a, float) / np.sum(a), 1e-4, None)
    return float(((a - e) * np.log(a / e)).sum())


def score_psi(base, cur, nb=10):
    edges = np.unique(np.quantile(base, np.linspace(0, 1, nb + 1)[1:-1]))
    f = lambda s: np.bincount(np.searchsorted(edges, s, side="right"), minlength=len(edges) + 1)
    return psi_counts(f(np.asarray(base)), f(np.asarray(cur)))
