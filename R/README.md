# R / Shiny governance layer

The Shiny application is the interactive investigation interface for ScoreGuard. It focuses on model lifecycle monitoring rather than credit-policy optimisation.

Views include:
- Model health and executive monitoring
- Drift and CSI investigation
- Performance and segment monitoring
- Vintage and roll-rate analysis
- Calibration and challenger analysis
- Data quality
- Fairness screening
- Model incident investigation

Run from the project root:

```r
shiny::runApp("R/shiny")
```
