# Executive Memo: Random Forest Classifier & Model Comparison

**To:** Vice President of Customer Success  
**From:** Sidharth Menon, Lead Data Analyst  
**Date:** September 28, 2026  
**Subject:** Milestone 4 Technical Readout — Random Forest Ensemble Evaluation, Side-by-Side Model Comparison & Threshold Tuning  

---

### 1. Executive Summary & Problem Context
In Milestone 3, our linear baseline confirmed that churn risk is concentrated in the early onboarding window. However, customer churn behavior exhibits **non-linear threshold cliffs**—for instance, an account on a month-to-month plan experiencing a sudden spike in ticket velocity combined with payment retries suffers an exponential churn spike rather than a simple additive increase.

To model these non-linear interactions, we trained a **Random Forest Classifier** ($100$ estimators, `max_depth=6`, `min_samples_split=5`) on the identical $80/20$ stratified customer split ($N_{\text{train}} = 687$, $N_{\text{test}} = 172$). The non-linear ensemble achieved superior discrimination, improving test accuracy to **98.26%**, ROC-AUC to **0.9949**, and capturing **93.62% of churners** with **zero false alarms** at default threshold.

---

### 2. Side-by-Side Model Benchmarking Matrix ($N_{\text{test}} = 172$)

| Performance Metric | Naive Baseline | Logistic Regression | Random Forest ($p=0.50$) | Random Forest ($p=0.35$)* |
| :--- | :---: | :---: | :---: | :---: |
| **Accuracy** | 72.67% | 95.93% | **98.26%** | 97.67% |
| **ROC-AUC Score** | 0.5000 | 0.9896 | **0.9949** | **0.9949** |
| **PR-AUC Score** | 0.2733 | 0.9796 | **0.9891** | **0.9891** |
| **Precision** | 0.00% | 97.62% | **100.00%** | 97.78% |
| **Recall (Sensitivity)** | 0.00% | 87.23% | **93.62%** | **93.62%** |
| **F1-Score** | 0.00% | 92.13% | **96.70%** | 95.65% |
| **True Negatives (TN)** | 125 | 124 | **125** | 124 |
| **False Positives (FP)** | 0 | 1 | **0** | 1 |
| **False Negatives (FN)** | 47 | 6 | **3** | 3 |
| **True Positives (TP)** | 0 | 41 | **44** | 44 |

*\*Note: Evaluated at recommended operational threshold $p = 0.35$. Lowering further to $p = 0.20$ catches 45 of 47 churners (95.74% Recall).*

---

### 3. Confusion Matrix Breakdown & Error Reduction
* **Missed Churners Cut in Half:** Random Forest reduced False Negatives from **6 down to 3**, rescuing an additional 3 high-risk accounts representing **$6,289.56 in preserved annual recurring revenue** ($174.71 average monthly MRR $\times 12$ months $\times 3$).
* **Zero False Alarm Rate at $p=0.50$:** Random Forest produced **0 False Positives** (100% Precision), completely eliminating wasted outreach costs and preventing alert fatigue for Customer Success managers.

---

### 4. Feature Importance Comparison: Tree Impurity vs. Linear Odds Ratios
While Logistic Regression evaluated isolated marginal shifts (odds ratios), Random Forest's Mean Decrease in Impurity (Gini MDI) highlights feature dominance:
1. **Tenure Dominance (`tenure_days`: $34.96\%$, `tenure_months`: $33.21\%$):** Tree splits immediately isolate accounts with $<90$ days tenure into high-hazard branches.
2. **Behavioral Telemetry Velocity (`events_per_month`: $5.23\%$, `login_frequency`: $4.09\%$):** Sudden drop-offs in recurring monthly usage trigger downstream exit leaves.
3. **Friction Velocity (`ticket_velocity`: $1.35\%$, `urgent_tickets`: $1.15\%$):** In tree logic, support distress acts as a conditional modifier—amplifying churn risk primarily when tenure is low.

---

### 5. Threshold Tuning & Commercial Retention Economics
In customer retention, **False Negatives are exponentially more costly than False Positives:**
* **Cost of False Negative:** Losing an average customer costs **$2,096.52/year** in lost LTV.
* **Cost of False Positive:** Reaching out to a healthy customer costs approximately **$50–$75** in team capacity or a small proactive retention perk.

By tuning the decision threshold:
* At **$p = 0.35$**, the model maintains $93.62\%$ Recall with a $97.78\%$ Precision (only 1 false alarm).
* At **$p = 0.20$**, Recall increases to **$95.74\%$** (catching 45 of 47 churners) with $91.84\%$ Precision (4 false alarms), yielding the maximum net campaign ROI of **+$18,568** across the test cohort.
* **Recommendation:** CS operations should implement a dual-tier alert system: flag accounts with churn probability $\ge 0.35$ for high-touch phone outreach, and accounts between $0.20 \le p < 0.35$ for automated in-app re-engagement sequences.

---

### 6. Answers to Exploration Questions
* **Cost of FP vs FN:** Missing a churner costs 100% of account ARR, whereas a false alarm costs minimal CS effort. Lowering the threshold to favor Recall is commercially optimal.
* **Feature Importance vs. Linear Coefficients:** Random Forest identifies non-linear threshold barriers that linear models dilute through continuous smoothing.
* **Why ROC-AUC beats Accuracy on Imbalanced Data:** Accuracy is distorted by majority-class prevalence (a useless model gets $72.67\%$ accuracy). ROC-AUC evaluates discrimination across the full spectrum of true-positive vs false-positive operating points.
