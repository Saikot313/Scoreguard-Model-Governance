library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)
library(dplyr)
library(tidyr)
library(DT)

project_root <- "E:/ML Projects/Data Science Project/scoreguard"

db_path <- file.path(
  project_root,
  "data",
  "scoreguard.db"
)

message("Project root: ", project_root)
message("Database path: ", db_path)

if (!file.exists(db_path)) {
  stop(
    paste0(
      "ScoreGuard database not found at:\n",
      db_path,
      "\n\nPlease run python run_all.py from the project root."
    )
  )
}

message("ScoreGuard database found successfully.")

con <- dbConnect(
  SQLite(),
  db_path
)


read_tbl <- function(n) dbReadTable(con, n)
mon <- read_tbl("mon_monthly")
health <- read_tbl("model_health")
inc <- read_tbl("model_incidents")
seg <- read_tbl("segment_monitoring")
dq <- read_tbl("data_quality")
cc <- read_tbl("champion_challenger")
recal <- read_tbl("recalibration_lab")
csi <- read_tbl("mon_csi")
vint <- read_tbl("mon_vintage")
roll <- read_tbl("mon_roll")
fair <- read_tbl("mon_fairness")

health_value <- health$overall_health[1]
health_status <- health$status[1]


ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background: #f4f7fb;
        font-family: Inter, -apple-system, BlinkMacSystemFont,
                     'Segoe UI', sans-serif;
        color: #172033;
      }

      .container-fluid {
        padding: 0 28px 35px 28px;
      }

      /* ---------- Top Header ---------- */

      .sg-header {
        background: linear-gradient(135deg, #0f172a 0%, #123b52 100%);
        color: white;
        border-radius: 18px;
        padding: 25px 30px;
        margin: 18px 0 22px 0;
        box-shadow: 0 10px 30px rgba(15, 23, 42, .12);
      }

      .sg-title {
        font-size: 27px;
        font-weight: 700;
        letter-spacing: -.5px;
        margin: 0;
      }

      .sg-subtitle {
        margin-top: 7px;
        color: #cbd5e1;
        font-size: 14px;
      }

      .sg-context {
        margin-top: 18px;
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
      }

      .sg-chip {
        display: inline-block;
        padding: 7px 12px;
        border-radius: 999px;
        background: rgba(255,255,255,.10);
        border: 1px solid rgba(255,255,255,.15);
        color: #e2e8f0;
        font-size: 12px;
      }

      /* ---------- KPI Cards ---------- */

      .kpi-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 16px;
        margin-bottom: 20px;
      }

      .kpi-card {
        background: white;
        border: 1px solid #e7edf4;
        border-radius: 16px;
        padding: 20px;
        min-height: 122px;
        box-shadow: 0 5px 18px rgba(15, 23, 42, .05);
        position: relative;
        overflow: hidden;
      }

      .kpi-card:before {
        content: '';
        position: absolute;
        left: 0;
        top: 0;
        bottom: 0;
        width: 4px;
        background: #2563eb;
      }

      .kpi-card.health:before { background: #0f766e; }
      .kpi-card.psi:before { background: #2563eb; }
      .kpi-card.gini:before { background: #7c3aed; }
      .kpi-card.incidents:before { background: #dc2626; }

      .kpi-label {
        color: #64748b;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: .6px;
      }

      .kpi-value {
        font-size: 29px;
        font-weight: 700;
        color: #0f172a;
        margin-top: 7px;
      }

      .kpi-note {
        color: #94a3b8;
        font-size: 12px;
        margin-top: 4px;
      }

      /* ---------- Status ---------- */

      .status-pill {
        display: inline-block;
        margin-top: 7px;
        padding: 5px 11px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: .5px;
      }

      .status-red {
        color: #991b1b;
        background: #fee2e2;
        border: 1px solid #fecaca;
      }

      .status-amber {
        color: #92400e;
        background: #fef3c7;
        border: 1px solid #fde68a;
      }

      .status-green {
        color: #166534;
        background: #dcfce7;
        border: 1px solid #bbf7d0;
      }

      /* ---------- Main Cards ---------- */

      .panel-card {
        background: white;
        border: 1px solid #e7edf4;
        border-radius: 17px;
        padding: 20px;
        margin-bottom: 18px;
        box-shadow: 0 5px 18px rgba(15, 23, 42, .045);
      }

      .section-title {
        font-size: 17px;
        font-weight: 700;
        color: #172033;
        margin-bottom: 3px;
      }

      .section-subtitle {
        color: #64748b;
        font-size: 12px;
        margin-bottom: 16px;
      }

      /* ---------- Health Gauge ---------- */

      .health-wrap {
        display: flex;
        align-items: center;
        gap: 25px;
        padding: 5px 0;
      }

      .health-gauge {
        width: 145px;
        height: 145px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
      }

      .health-gauge-inner {
        width: 112px;
        height: 112px;
        background: white;
        border-radius: 50%;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        box-shadow: inset 0 0 0 1px #edf2f7;
      }

      .health-score {
        font-size: 27px;
        font-weight: 700;
        color: #0f172a;
      }

      .health-caption {
        font-size: 11px;
        color: #64748b;
      }

      .health-details {
        flex: 1;
      }

      .health-row {
        margin-bottom: 12px;
      }

      .health-row-label {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        margin-bottom: 5px;
        color: #475569;
      }

      .health-bar {
        height: 7px;
        background: #e9eef5;
        border-radius: 99px;
        overflow: hidden;
      }

      .health-fill {
        height: 100%;
        border-radius: 99px;
        background: #2563eb;
      }

      .health-fill.good { background: #0f766e; }
      .health-fill.warn { background: #d97706; }
      .health-fill.bad { background: #dc2626; }

      /* ---------- Investigation ---------- */

      .investigation-box {
        border-radius: 14px;
        padding: 15px 17px;
        margin-bottom: 10px;
        border: 1px solid #e7edf4;
        background: #f8fafc;
      }

      .investigation-box.red {
        background: #fff7f7;
        border-color: #fecaca;
      }

      .investigation-box.amber {
        background: #fffbeb;
        border-color: #fde68a;
      }

      .investigation-box.green {
        background: #f0fdf4;
        border-color: #bbf7d0;
      }

      .investigation-title {
        font-size: 13px;
        font-weight: 700;
        color: #1e293b;
      }

      .investigation-text {
        font-size: 12px;
        color: #64748b;
        margin-top: 4px;
        line-height: 1.5;
      }

      /* ---------- Governance Interpretation ---------- */

      .governance-card {
        position: relative;
        overflow: hidden;
        background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
      }

      .governance-accent {
        position: absolute;
        left: 0;
        top: 0;
        bottom: 0;
        width: 5px;
        background: #dc2626;
      }

      .governance-accent.amber {
        background: #d97706;
      }

      .governance-accent.green {
        background: #0f766e;
      }

      .governance-layout {
        display: grid;
        grid-template-columns: 1.2fr 1fr;
        gap: 18px;
        align-items: stretch;
      }

      .governance-summary {
        padding: 3px 4px 3px 8px;
      }

      .governance-eyebrow {
        font-size: 11px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: .7px;
        color: #64748b;
        margin-bottom: 6px;
      }

      .governance-headline {
        font-size: 21px;
        font-weight: 750;
        color: #0f172a;
        margin-bottom: 7px;
      }

      .governance-description {
        font-size: 13px;
        line-height: 1.6;
        color: #64748b;
        max-width: 760px;
      }

      .governance-status {
        display: inline-flex;
        align-items: center;
        padding: 6px 11px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 750;
        margin-top: 11px;
      }

      .governance-status.red {
        color: #991b1b;
        background: #fee2e2;
        border: 1px solid #fecaca;
      }

      .governance-status.amber {
        color: #92400e;
        background: #fef3c7;
        border: 1px solid #fde68a;
      }

      .governance-status.green {
        color: #166534;
        background: #dcfce7;
        border: 1px solid #bbf7d0;
      }

      .governance-evidence {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 10px;
      }

      .evidence-card {
        background: #ffffff;
        border: 1px solid #e7edf4;
        border-radius: 12px;
        padding: 13px;
        min-height: 88px;
      }

      .evidence-label {
        font-size: 10px;
        text-transform: uppercase;
        letter-spacing: .55px;
        color: #94a3b8;
        font-weight: 700;
      }

      .evidence-value {
        font-size: 18px;
        font-weight: 750;
        color: #0f172a;
        margin-top: 5px;
      }

      .evidence-note {
        font-size: 11px;
        line-height: 1.35;
        color: #64748b;
        margin-top: 3px;
      }

      .review-path {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        margin-top: 15px;
      }

      .review-step {
        display: inline-flex;
        align-items: center;
        gap: 7px;
        padding: 7px 10px;
        border-radius: 9px;
        background: #f1f5f9;
        color: #475569;
        font-size: 11px;
        border: 1px solid #e2e8f0;
      }

      .review-step-num {
        width: 20px;
        height: 20px;
        border-radius: 50%;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        background: #0f172a;
        color: #ffffff;
        font-size: 10px;
        font-weight: 700;
      }

      @media (max-width: 900px) {
        .governance-layout {
          grid-template-columns: 1fr;
        }

        .governance-evidence {
          grid-template-columns: 1fr;
        }
      }

      /* ---------- Incident Severity ---------- */

      .severity-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 10px;
      }

      .severity-card {
        border-radius: 12px;
        padding: 13px;
        text-align: center;
        border: 1px solid #e7edf4;
      }

      .severity-number {
        font-size: 23px;
        font-weight: 700;
      }

      .severity-label {
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: .5px;
        margin-top: 2px;
      }

      .severity-red {
        background: #fff7f7;
        border-color: #fecaca;
        color: #991b1b;
      }

      .severity-amber {
        background: #fffbeb;
        border-color: #fde68a;
        color: #92400e;
      }

      .severity-green {
        background: #f0fdf4;
        border-color: #bbf7d0;
        color: #166534;
      }

      /* ---------- Navigation ---------- */

      .nav-tabs {
        border: none !important;
        margin-bottom: 18px;
        display: flex;
        gap: 7px;
        flex-wrap: wrap;
      }

      .nav-tabs > li > a {
        border: 1px solid #e2e8f0 !important;
        border-radius: 10px !important;
        background: white !important;
        color: #475569 !important;
        font-size: 12px;
        font-weight: 600;
        padding: 10px 14px;
        margin-right: 0 !important;
        transition: all .18s ease;
      }

      .nav-tabs > li > a:hover {
        background: #eff6ff !important;
        color: #1d4ed8 !important;
        border-color: #bfdbfe !important;
      }

      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:hover {
        background: #123b52 !important;
        color: white !important;
        border-color: #123b52 !important;
      }

      /* ---------- Tables ---------- */

      .dataTables_wrapper {
        font-size: 12px;
      }

      table.dataTable thead th {
        background: #f8fafc;
        color: #475569;
        font-weight: 700;
        border-bottom: 1px solid #e2e8f0 !important;
      }

      /* ---------- Buttons ---------- */

      .btn {
        border-radius: 9px !important;
        font-size: 12px !important;
        font-weight: 600 !important;
      }

      .btn-default {
        border-color: #dbe3ec !important;
      }

      /* ---------- Responsive ---------- */

      @media (max-width: 1100px) {
        .kpi-grid {
          grid-template-columns: repeat(2, 1fr);
        }
      }

      @media (max-width: 650px) {
        .kpi-grid {
          grid-template-columns: 1fr;
        }

        .health-wrap {
          flex-direction: column;
          align-items: flex-start;
        }

        .severity-grid {
          grid-template-columns: 1fr;
        }

        .container-fluid {
          padding: 0 12px 25px 12px;
        }
      }
    "))
  ),
  div(
    class = "sg-header",
    h1(
      class = "sg-title",
      "ScoreGuard | SME Credit Model Monitoring & Governance"
    ),
    div(
      class = "sg-subtitle",
      "Production-style monitoring, investigation and model governance workspace"
    ),
    div(
      class = "sg-context",
      span(
        class = "sg-chip",
        "Champion: Interpretable SME Scorecard"
      ),
      span(
        class = "sg-chip",
        "Monitoring: 2024 Production Simulation"
      ),
      span(
        class = "sg-chip",
        "Focus: Stability • Performance • Calibration • Governance"
      )
    )
  ),
  uiOutput("kpi_cards"),
  tabsetPanel(
    id = "main_tabs",
    tabPanel(
      "Overview",
      fluidRow(
        column(
          7,
          div(
            class = "panel-card",
            div(
              class = "section-title",
              "Model Health Overview"
            ),
            div(
              class = "section-subtitle",
              "Composite view of stability, discrimination, calibration, data quality and fairness."
            ),
            uiOutput("health_gauge")
          )
        ),
        column(
          5,
          div(
            class = "panel-card",
            div(
              class = "section-title",
              "Incident Severity"
            ),
            div(
              class = "section-subtitle",
              "Current monitoring alerts grouped by governance severity."
            ),
            uiOutput("severity_breakdown")
          )
        )
      ),
      fluidRow(
        column(
          7,
          div(
            class = "panel-card",
            div(
              class = "section-title",
              "Performance vs Observed Outcomes"
            ),
            div(
              class = "section-subtitle",
              "Monthly comparison of predicted and observed bad rates to identify calibration deterioration."
            ),
            plotOutput(
              "performance_plot",
              height = "330px"
            )
          )
        ),
        column(
          5,
          div(
            class = "panel-card",
            div(
              class = "section-title",
              "What Needs Investigation?"
            ),
            div(
              class = "section-subtitle",
              "Evidence-based investigation signals generated from current monitoring results."
            ),
            uiOutput("investigation_panel")
          )
        )
      ),
      fluidRow(
        column(
          12,
          div(
            class = "panel-card governance-card",
            div(
              class = "section-title",
              "Governance Interpretation"
            ),
            div(
              class = "section-subtitle",
              "Management-level interpretation of the current model health assessment and the evidence requiring review."
            ),
            uiOutput("governance_interpretation")
          )
        )
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Model Health Components"
        ),
        div(
          class = "section-subtitle",
          "Component-level diagnostics behind the overall model health assessment."
        ),
        DTOutput("health_table")
      )
    ),
    tabPanel(
      "Drift Investigation",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Population Stability Investigation"
        ),
        div(
          class = "section-subtitle",
          "Monthly PSI identifies whether the monitoring population is shifting relative to the development reference."
        ),
        plotOutput("psi_plot", height = "300px")
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Feature Drift | Characteristic Stability Index"
        ),
        div(
          class = "section-subtitle",
          "CSI highlights which monitored variables show the strongest distribution movement."
        ),
        plotOutput("csi_plot", height = "400px")
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "CSI Evidence"
        ),
        DTOutput("csi_table")
      )
    ),
    tabPanel(
      "Performance",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Discrimination Performance Over Time"
        ),
        div(
          class = "section-subtitle",
          "Rolling Gini tracks whether the champion model continues to separate higher- and lower-risk observations."
        ),
        plotOutput("gini_plot", height = "300px")
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Segment-Level Model Monitoring"
        ),
        div(
          class = "section-subtitle",
          "Performance and calibration diagnostics by monitored business segments."
        ),
        DTOutput("segment_table")
      )
    ),
    tabPanel(
      "Vintage & Roll-rate",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Vintage Performance"
        ),
        div(
          class = "section-subtitle",
          "90+ DPD behavior by months-on-book helps identify deterioration across origination vintages."
        ),
        plotOutput("vintage_plot", height = "350px")
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Roll-rate Transitions"
        ),
        div(
          class = "section-subtitle",
          "Observed movement between delinquency states provides additional portfolio deterioration evidence."
        ),
        DTOutput("roll_table")
      )
    ),
    tabPanel(
      "Calibration Lab",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Recalibration Analysis"
        ),
        div(
          class = "section-subtitle",
          "Compare the existing champion with statistical recalibration candidates before any governance decision."
        ),
        DTOutput("recal_table"),
        br(),
        plotOutput("cal_plot", height = "300px")
      ),
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Champion vs Challenger"
        ),
        div(
          class = "section-subtitle",
          "Descriptive comparison of model discrimination and calibration metrics."
        ),
        DTOutput("cc_table")
      )
    ),
    tabPanel(
      "Data Quality",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Production Data Quality Monitoring"
        ),
        div(
          class = "section-subtitle",
          "Monitor missingness, duplicates, invalid values and structural anomalies before interpreting model performance."
        ),
        plotOutput("dq_plot", height = "300px"),
        DTOutput("dq_table")
      )
    ),
    tabPanel(
      "Fairness",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Fairness Screening"
        ),
        div(
          class = "section-subtitle",
          "Adverse impact ratio is used as a screening signal and requires business and compliance context."
        ),
        DTOutput("fair_table"),
        br(),
        div(
          class = "investigation-box",
          p(
            class = "investigation-text",
            "AIR is a screening measure, not proof of unfairness. Low values should be investigated with appropriate business, legal and compliance context."
          )
        )
      )
    ),
    tabPanel(
      "Incident Center",
      div(
        class = "panel-card",
        div(
          class = "section-title",
          "Model Incident Center"
        ),
        div(
          class = "section-subtitle",
          "Detected monitoring breaches and the evidence supporting each investigation."
        ),
        DTOutput("incident_table"),
        br(),
        div(
          class = "section-title",
          "Investigation Evidence"
        ),
        verbatimTextOutput("incident_detail"),
        br(),
        downloadButton(
          "download_incidents",
          "Download Incident Evidence"
        ),
        downloadButton(
          "download_health",
          "Download Model Health"
        )
      )
    )
  )
)


server <- function(input, output, session) {
  output$kpi_cards <- renderUI({
    latest_psi <- as.numeric(tail(mon$psi, 1))
    latest_gini <- as.numeric(tail(mon$gini_roll3, 1))
    incident_count <- nrow(inc)

    status <- toupper(as.character(health_status))

    status_class <- switch(status,
      "RED" = "status-red",
      "AMBER" = "status-amber",
      "GREEN" = "status-green",
      "status-amber"
    )

    div(
      class = "kpi-grid",

      # Model Health
      div(
        class = "kpi-card health",
        div(
          class = "kpi-label",
          "Model Health"
        ),
        div(
          class = "kpi-value",
          sprintf("%.1f / 100", health_value)
        ),
        span(
          class = paste("status-pill", status_class),
          status
        )
      ),

      # PSI
      div(
        class = "kpi-card psi",
        div(
          class = "kpi-label",
          "Latest PSI"
        ),
        div(
          class = "kpi-value",
          sprintf("%.3f", latest_psi)
        ),
        div(
          class = "kpi-note",
          "Population stability"
        )
      ),

      # Gini
      div(
        class = "kpi-card gini",
        div(
          class = "kpi-label",
          "Rolling Gini"
        ),
        div(
          class = "kpi-value",
          sprintf("%.3f", latest_gini)
        ),
        div(
          class = "kpi-note",
          "Recent discrimination"
        )
      ),

      # Incidents
      div(
        class = "kpi-card incidents",
        div(
          class = "kpi-label",
          "Open Incidents"
        ),
        div(
          class = "kpi-value",
          incident_count
        ),
        div(
          class = "kpi-note",
          "Detected monitoring events"
        )
      )
    )
  })


  output$health_gauge <- renderUI({
    score <- max(
      0,
      min(100, as.numeric(health_value))
    )

    status <- toupper(as.character(health_status))

    gauge_color <- switch(status,
      "RED" = "#dc2626",
      "AMBER" = "#d97706",
      "GREEN" = "#0f766e",
      "#2563eb"
    )

    stability_value <- as.numeric(
      health$stability[1]
    )

    discrimination_value <- as.numeric(
      health$discrimination[1]
    )

    calibration_value <- as.numeric(
      health$calibration[1]
    )

    calibration_class <- if (
      calibration_value < 70
    ) {
      "health-fill bad"
    } else if (
      calibration_value < 85
    ) {
      "health-fill warn"
    } else {
      "health-fill good"
    }

    div(
      class = "health-wrap",

      # Circular gauge
      div(
        class = "health-gauge",
        style = paste0(
          "background: conic-gradient(",
          gauge_color,
          " 0deg ",
          score * 3.6,
          "deg, #e8edf3 ",
          score * 3.6,
          "deg 360deg);"
        ),
        div(
          class = "health-gauge-inner",
          div(
            class = "health-score",
            sprintf("%.0f", score)
          ),
          div(
            class = "health-caption",
            "Overall health"
          )
        )
      ),

      # Component bars
      div(
        class = "health-details",

        # Stability
        div(
          class = "health-row",
          div(
            class = "health-row-label",
            span("Stability"),
            span(
              sprintf("%.1f", stability_value)
            )
          ),
          div(
            class = "health-bar",
            div(
              class = "health-fill good",
              style = paste0(
                "width:",
                stability_value,
                "%;"
              )
            )
          )
        ),

        # Discrimination
        div(
          class = "health-row",
          div(
            class = "health-row-label",
            span("Discrimination"),
            span(
              sprintf(
                "%.1f",
                discrimination_value
              )
            )
          ),
          div(
            class = "health-bar",
            div(
              class = "health-fill good",
              style = paste0(
                "width:",
                discrimination_value,
                "%;"
              )
            )
          )
        ),

        # Calibration
        div(
          class = "health-row",
          div(
            class = "health-row-label",
            span("Calibration"),
            span(
              sprintf(
                "%.1f",
                calibration_value
              )
            )
          ),
          div(
            class = "health-bar",
            div(
              class = calibration_class,
              style = paste0(
                "width:",
                calibration_value,
                "%;"
              )
            )
          )
        )
      )
    )
  })


  output$severity_breakdown <- renderUI({
    if (nrow(inc) == 0) {
      return(
        div(
          class = "investigation-box green",
          div(
            class = "investigation-title",
            "No active incidents detected"
          ),
          div(
            class = "investigation-text",
            "Current monitoring evidence does not contain recorded incident breaches."
          )
        )
      )
    }

    severity_values <- toupper(
      as.character(inc$severity)
    )

    red_count <- sum(
      severity_values == "RED",
      na.rm = TRUE
    )

    amber_count <- sum(
      severity_values == "AMBER",
      na.rm = TRUE
    )

    green_count <- sum(
      severity_values == "GREEN",
      na.rm = TRUE
    )

    div(
      class = "severity-grid",
      div(
        class = "severity-card severity-red",
        div(
          class = "severity-number",
          red_count
        ),
        div(
          class = "severity-label",
          "RED"
        )
      ),
      div(
        class = "severity-card severity-amber",
        div(
          class = "severity-number",
          amber_count
        ),
        div(
          class = "severity-label",
          "AMBER"
        )
      ),
      div(
        class = "severity-card severity-green",
        div(
          class = "severity-number",
          green_count
        ),
        div(
          class = "severity-label",
          "GREEN"
        )
      )
    )
  })


  output$investigation_panel <- renderUI({
    latest_psi <- as.numeric(
      tail(mon$psi, 1)
    )

    latest_gini <- as.numeric(
      tail(mon$gini_roll3, 1)
    )

    latest_calibration <- as.numeric(
      health$calibration[1]
    )

    investigation_items <- list()


    # Calibration deterioration
    if (
      !is.na(latest_calibration) &&
        latest_calibration < 70
    ) {
      investigation_items <- append(
        investigation_items,
        list(
          div(
            class = "investigation-box red",
            div(
              class = "investigation-title",
              "Calibration deterioration detected"
            ),
            div(
              class = "investigation-text",
              paste0(
                "Calibration health is ",
                round(
                  latest_calibration,
                  1
                ),
                "/100. Review the gap between predicted and observed bad rates."
              )
            )
          )
        )
      )
    }


    # PSI investigation
    if (
      !is.na(latest_psi) &&
        latest_psi >= 0.10
    ) {
      investigation_items <- append(
        investigation_items,
        list(
          div(
            class = "investigation-box amber",
            div(
              class = "investigation-title",
              "Population stability requires review"
            ),
            div(
              class = "investigation-text",
              paste0(
                "Latest PSI is ",
                round(
                  latest_psi,
                  3
                ),
                ". Review population movement and affected features."
              )
            )
          )
        )
      )
    }


    # Incidents
    if (
      nrow(inc) > 0
    ) {
      investigation_items <- append(
        investigation_items,
        list(
          div(
            class = "investigation-box red",
            div(
              class = "investigation-title",
              paste0(
                nrow(inc),
                " monitoring incidents recorded"
              )
            ),
            div(
              class = "investigation-text",
              "Use the Incident Center to inspect the breached metric, affected period, threshold and supporting evidence."
            )
          )
        )
      )
    }


    # Gini investigation
    if (
      !is.na(latest_gini) &&
        latest_gini < 0.30
    ) {
      investigation_items <- append(
        investigation_items,
        list(
          div(
            class = "investigation-box amber",
            div(
              class = "investigation-title",
              "Discrimination performance requires review"
            ),
            div(
              class = "investigation-text",
              paste0(
                "Rolling Gini is ",
                round(
                  latest_gini,
                  3
                ),
                ". Compare recent performance against the model's OOT baseline."
              )
            )
          )
        )
      )
    }


    # No investigation signal
    if (
      length(investigation_items) == 0
    ) {
      investigation_items <- list(
        div(
          class = "investigation-box green",
          div(
            class = "investigation-title",
            "No immediate investigation signal"
          ),
          div(
            class = "investigation-text",
            "Current monitored metrics remain within the configured investigation thresholds."
          )
        )
      )
    }


    do.call(
      tagList,
      investigation_items
    )
  })

  output$governance_interpretation <- renderUI({
    health_score <- round(as.numeric(health$overall_health[1]), 1)
    stability <- round(as.numeric(health$stability[1]), 1)
    discrimination <- round(as.numeric(health$discrimination[1]), 1)
    calibration <- round(as.numeric(health$calibration[1]), 1)

    status <- toupper(as.character(health$status[1]))
    incident_count <- nrow(inc)

    if (status == "RED") {
      accent_class <- "red"
      headline <- "Model requires investigation"
      description <- paste0(
        "Stability and discrimination remain strong, but calibration deterioration ",
        "and the detected monitoring incidents require governance review before the ",
        "current production behavior is treated as fully reliable."
      )
      status_text <- "RED • GOVERNANCE REVIEW REQUIRED"
    } else if (status == "AMBER") {
      accent_class <- "amber"
      headline <- "Model requires closer monitoring"
      description <- paste0(
        "The model remains operational, but one or more monitoring dimensions show ",
        "early warning signals. Review the affected metrics and segments before the ",
        "next governance cycle."
      )
      status_text <- "AMBER • ENHANCED MONITORING"
    } else {
      accent_class <- "green"
      headline <- "Model is within monitored thresholds"
      description <- paste0(
        "Current stability, discrimination, calibration, data quality and fairness ",
        "indicators remain within the configured monitoring thresholds."
      )
      status_text <- "GREEN • WITHIN THRESHOLDS"
    }

    div(
      class = "governance-layout",
      div(
        class = "governance-summary",
        div(
          class = "governance-eyebrow",
          "Current governance assessment"
        ),
        div(
          class = "governance-headline",
          headline
        ),
        div(
          class = "governance-description",
          description
        ),
        div(
          class = paste("governance-status", accent_class),
          status_text
        ),
        div(
          class = "review-path",
          div(
            class = "review-step",
            span(class = "review-step-num", "1"),
            "Review incidents"
          ),
          div(
            class = "review-step",
            span(class = "review-step-num", "2"),
            "Check calibration"
          ),
          div(
            class = "review-step",
            span(class = "review-step-num", "3"),
            "Inspect affected segments"
          )
        )
      ),
      div(
        class = "governance-evidence",
        div(
          class = "evidence-card",
          div(class = "evidence-label", "Overall Health"),
          div(class = "evidence-value", paste0(health_score, "/100")),
          div(class = "evidence-note", "Composite model health score")
        ),
        div(
          class = "evidence-card",
          div(class = "evidence-label", "Calibration"),
          div(class = "evidence-value", paste0(calibration, "/100")),
          div(class = "evidence-note", "Primary governance signal")
        ),
        div(
          class = "evidence-card",
          div(class = "evidence-label", "Incidents"),
          div(class = "evidence-value", incident_count),
          div(
            class = "evidence-note",
            paste0(
              "Stability ",
              stability,
              " • Discrimination ",
              discrimination
            )
          )
        )
      ),
      div(
        class = "governance-accent",
        style = paste0(
          "background:",
          ifelse(
            accent_class == "red",
            "#dc2626",
            ifelse(
              accent_class == "amber",
              "#d97706",
              "#0f766e"
            )
          ),
          ";"
        )
      )
    )
  })


  # =======================================================
  # YOUR EXISTING OUTPUTS
  # =======================================================

  output$performance_plot <- renderPlot({
    x <- mon %>%
      select(
        app_month,
        pred_bad,
        actual_bad
      ) %>%
      tidyr::pivot_longer(
        -app_month
      )

    ggplot(
      x,
      aes(
        app_month,
        value,
        color = name,
        group = name
      )
    ) +
      geom_line() +
      geom_point() +
      labs(
        x = NULL,
        y = "Bad rate",
        color = NULL
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(
          angle = 60,
          hjust = 1
        )
      )
  })


  output$health_table <- renderDT(
    datatable(
      health,
      options = list(
        dom = "t",
        pageLength = 5
      ),
      rownames = FALSE
    )
  )


  output$psi_plot <- renderPlot({
    ggplot(
      mon,
      aes(app_month, psi)
    ) +
      geom_line() +
      geom_point() +
      geom_hline(
        yintercept = .10,
        linetype = 2
      ) +
      geom_hline(
        yintercept = .25,
        linetype = 2
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(
          angle = 60,
          hjust = 1
        )
      )
  })


  output$csi_plot <- renderPlot({
    ggplot(
      csi,
      aes(
        app_month,
        variable,
        fill = char_psi
      )
    ) +
      geom_tile() +
      theme_minimal() +
      theme(
        axis.text.x = element_text(
          angle = 60,
          hjust = 1
        )
      ) +
      labs(
        x = NULL,
        y = NULL,
        fill = "CSI"
      )
  })


  output$csi_table <- renderDT(
    datatable(
      csi %>%
        arrange(desc(char_psi)),
      options = list(
        pageLength = 12
      ),
      rownames = FALSE
    )
  )


  output$gini_plot <- renderPlot({
    ggplot(
      mon,
      aes(
        app_month,
        gini_roll3
      )
    ) +
      geom_line() +
      geom_point() +
      geom_hline(
        yintercept = mean(
          mon$gini_roll3,
          na.rm = TRUE
        ),
        linetype = 2
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(
          angle = 60,
          hjust = 1
        )
      )
  })


  output$segment_table <- renderDT(
    datatable(
      seg %>%
        arrange(
          desc(calibration_ratio)
        ),
      options = list(
        pageLength = 15
      ),
      rownames = FALSE
    )
  )


  output$vintage_plot <- renderPlot({
    ggplot(
      vint,
      aes(
        mob,
        rate_90p,
        color = vintage,
        group = vintage
      )
    ) +
      geom_line() +
      theme_minimal() +
      labs(
        x = "Months on book",
        y = "90+ DPD rate"
      )
  })


  output$roll_table <- renderDT(
    datatable(
      roll,
      options = list(
        pageLength = 15
      ),
      rownames = FALSE
    )
  )


  output$recal_table <- renderDT(
    datatable(
      recal,
      options = list(
        dom = "t"
      ),
      rownames = FALSE
    )
  )


  output$cal_plot <- renderPlot({
    ggplot(
      recal,
      aes(
        model,
        brier,
        fill = model
      )
    ) +
      geom_col() +
      theme_minimal() +
      guides(
        fill = "none"
      ) +
      labs(
        x = NULL,
        y = "Brier score"
      )
  })


  output$cc_table <- renderDT(
    datatable(
      cc,
      options = list(
        dom = "t"
      ),
      rownames = FALSE
    )
  )


  output$dq_plot <- renderPlot({
    ggplot(
      dq,
      aes(
        app_month,
        missing_rate * 100
      )
    ) +
      geom_line() +
      geom_point() +
      theme_minimal() +
      labs(
        x = NULL,
        y = "Missing rate (%)"
      ) +
      theme(
        axis.text.x = element_text(
          angle = 60,
          hjust = 1
        )
      )
  })


  output$dq_table <- renderDT(
    datatable(
      dq,
      options = list(
        pageLength = 12
      ),
      rownames = FALSE
    )
  )


  output$fair_table <- renderDT(
    datatable(
      fair,
      options = list(
        pageLength = 10
      ),
      rownames = FALSE
    )
  )


  output$incident_table <- renderDT(
    datatable(
      inc %>%
        arrange(
          desc(detected_month)
        ),
      options = list(
        pageLength = 12
      ),
      selection = "single",
      rownames = FALSE
    )
  )


  output$incident_detail <- renderPrint({
    req(
      input$incident_table_rows_selected
    )

    print(
      inc[
        input$incident_table_rows_selected,
      ]
    )
  })


  output$download_incidents <- downloadHandler(
    filename = function() {
      "model_incidents.csv"
    },
    content = function(file) {
      write.csv(
        inc,
        file,
        row.names = FALSE
      )
    }
  )


  output$download_health <- downloadHandler(
    filename = function() {
      "model_health.csv"
    },
    content = function(file) {
      write.csv(
        health,
        file,
        row.names = FALSE
      )
    }
  )
}
shinyApp(ui, server)
