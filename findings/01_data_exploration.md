# Executive Memo: Exploratory Data Analysis & Feature Preparation

**To:** Vice President of Customer Success  
**From:** Sidharth Menon, Lead Data Analyst  
**Date:** September 28, 2026  
**Subject:** Milestone 2 Technical Readout — Baseline Churn Dynamics, Behavioral Indicators & Feature Store  

---

### 1. Executive Summary & Problem Framing
Customer Success currently operates reactively—discovering account cancellations only after the churn event has transpired. To transition toward proactive retention, we analyzed our customer cohort of **859 accounts** extracted from our PostgreSQL production records, examining tenure trajectories, billing friction, customer distress signals, and product engagement telemetry.

Our modeling cohort exhibits a **27.36% baseline churn rate** (235 churned accounts vs. 624 active retained accounts). Our objective is to engineer a leak-free predictive feature store to flag at-risk accounts 30 days prior to cancellation.

---

### 2. Class Imbalance & The "Accuracy Trap"
A naive benchmark that simply predicts "no customer will ever churn" achieves **72.64% overall accuracy** on this dataset. However, such a model is commercially catastrophic:
* It produces a **0% Recall** on churned accounts, detecting zero at-risk customers.
* By masking churn behind an artificially inflated accuracy score, the business would lose 100% of at-risk Monthly Recurring Revenue ($174.71 average MRR per churned account) without triggering an intervention.
* Consequently, model evaluation in subsequent milestones will prioritize **ROC-AUC, Precision-Recall AUC, and Recall at fixed operational thresholds**, rather than raw accuracy.

---

### 3. Core Behavioral Signals & Hazard Dynamics
Our bivariate exploratory analysis identified three primary drivers of customer attrition:

1. **Tenure & Early-Life Hazard ($r = -0.62$):** Churn risk is heavily front-loaded. Accounts in their first 1–3 months exhibit the steepest cancellation rates, whereas accounts reaching 6+ months of continuous usage display high lifetime stickiness.
2. **Support Distress & Velocity ($r = +0.15$):** It is not total tickets that predicts churn, but **ticket velocity** (tickets per month of active tenure). Accounts logging $>1.5$ tickets per month or escalating urgent issues churn at nearly double the baseline rate. Conversely, zero-ticket accounts also risk "silent churn" due to lack of engagement.
3. **Product Integration Stickiness ($r = -0.13$ to $-0.28$):** Accounts utilizing technical integrations (API calls: 28% lower churn probability) and regular data exports demonstrate significantly higher retention than passive dashboard viewers.

---

### 4. Feature Engineering & Strict Temporal Hygiene
To ensure our machine learning algorithms remain statistically sound, we engineered **14 derived predictive features** categorized into four domains:
* **Contract Value:** `tenure_months`, `mrr_per_seat`, `plan_tier` (Free, Starter, Pro, Enterprise).
* **Payment Friction:** `payment_failure_rate`, `failed_payment_attempts`, `has_failed_payments`.
* **Support Pressure:** `ticket_velocity`, `urgent_tickets`, `avg_csat`.
* **Adoption Intensity:** `login_frequency`, `feature_use_ratio`, `has_api_usage`, `log_total_events`.

**Anti-Leakage Safeguard:** All interaction telemetry (events, payment retries, support tickets) was strictly bounded prior to the customer’s cancellation timestamp (`occurred_at <= cancelled_at`). Post-churn automated billing retries (572 attempts) and cancellation survey responses were quarantined, eliminating target leakage.

The finalized feature matrix $X$ and ground truth vector $y$ have been materialized to `data/processed_features.csv` for baseline Logistic Regression training in Milestone 3.
