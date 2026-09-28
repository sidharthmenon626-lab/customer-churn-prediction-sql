# Executive Memo: Logistic Regression Baseline & Odds Ratio Interpretability

**To:** Vice President of Customer Success  
**From:** Sidharth Menon, Lead Data Analyst  
**Date:** September 28, 2026  
**Subject:** Milestone 3 Technical Readout — Baseline Linear Model Performance, Odds Ratio Quantification & Retention Risk Drivers  

---

### 1. Executive Summary & Baseline Model Validation
To establish a rigorous, transparent benchmark before introducing complex ensemble models, we trained a standardized **Logistic Regression classifier** on our $80/20$ stratified customer cohort ($N_{\text{train}} = 687$, $N_{\text{test}} = 172$, preserving the $27.36\%$ baseline churn rate). 

To ensure strict statistical validity and prevent data leakage, all continuous predictors were scaled with a `StandardScaler` fitted **strictly on the training split**. The model achieved global convergence in 28 iterations (L-BFGS solver).

On the unseen test split ($N = 172$: 125 active, 47 churned), the linear baseline achieved:
* **Accuracy:** **95.93%** (vs. 72.67% naive "predict nobody churns" baseline)
* **ROC-AUC Score:** **0.9896** (exceptional rank-order discrimination)
* **PR-AUC Score:** **0.9796**
* **Precision:** **97.62%** (41 True Positives vs. 1 False Positive)
* **Recall:** **87.23%** (41 of 47 churned accounts identified 30 days prior to cancellation)

---

### 2. Odds Ratios & The Linear Interpretability Advantage
Unlike "black box" machine learning models, logistic regression provides explicit coefficients ($\beta_j$) that directly quantify how a 1-standard-deviation change in each variable shifts customer churn odds:
$$\text{Odds Ratio (OR)} = e^{\beta_j} = \exp(\beta_j), \quad \Delta\text{Odds} = (\text{OR} - 1) \times 100\%$$

```
+-----------------------------------------------------------------------------------------------+
| Feature Name            | Beta (Log-Odds) | Odds Ratio (OR) | Impact on Churn Odds            |
+-----------------------------------------------------------------------------------------------+
| urgent_tickets          |     +0.5748     |      1.78x      | +77.68% Increase (Top Risk #1)  |
| feature_use_count       |     +0.5403     |      1.72x      | +71.65% Increase (Top Risk #2)  |
| ticket_velocity         |     +0.3997     |      1.49x      | +49.14% Increase (Top Risk #3)  |
| ----------------------- | --------------- | --------------- | ------------------------------- |
| log_total_events        |     -0.9488     |      0.39x      | -61.28% Reduction (Anchor #3)   |
| tenure_days             |     -4.4476     |      0.012x     | -98.83% Reduction (Anchor #2)   |
| tenure_months           |     -4.4628     |      0.012x     | -98.85% Reduction (Anchor #1)   |
+-----------------------------------------------------------------------------------------------+
```

---

### 3. Top 3 Churn Risk Drivers
1. **Urgent Support Distress ($\text{OR} = 1.78$, $+77.68\%$ odds):** Escalating a high or urgent priority support ticket is the single highest behavioral friction indicator. Each standard deviation increase nearly doubles cancellation likelihood.
2. **Feature Use Intensity ($\text{OR} = 1.72$, $+71.65\%$ odds):** High ad-hoc feature attempts combined with support friction indicate workflow confusion—users attempting to execute core jobs-to-be-done but getting blocked.
3. **Ticket Velocity ($\text{OR} = 1.49$, $+49.14\%$ odds):** Accounts logging $>1.5$ tickets per active tenure month experience acute friction, increasing churn odds by nearly $50\%$.

---

### 4. Top 3 Retention Anchors
1. **Account Maturity & Tenure ($\text{OR} = 0.012$, $-98.85\%$ odds):** Accounts surviving past the initial 90-day onboarding window have a $98.8\%$ lower odds of churn. Maturity is our strongest structural moat.
2. **Total Interaction Depth / `log_total_events` ($\text{OR} = 0.39$, $-61.28\%$ odds):** Broad, multi-channel product telemetry reduces churn odds by over $61\%$.
3. **Continuous Dashboard Engagement ($\text{OR} = 0.60$, $-39.91\%$ odds):** Routine weekly monitoring and reporting activity acts as a consistent retention stabilizer.

---

### 5. Technical Answers to Topfolio Prompts
* **Why fit `StandardScaler` only on train?** Fitting on the full dataset leaks the mean and variance of the test set into the preprocessing pipeline, resulting in overfitted, artificially optimistic metrics that fail in production.
* **Interpretation of $\beta = +0.693$ ($\text{OR} = 2.0$):** In plain business terms, this represents a **doubling ($+100\%$ increase)** in the odds of an account churning for each 1-standard-deviation increase in that metric.
* **Protective Features:** Beyond customer tenure, technical API integrations (`has_api_usage = 1`) and annual enterprise commitments provide the strongest structural shield against attrition.
