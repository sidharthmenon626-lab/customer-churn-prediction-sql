-- ============================================================================
-- Customer Churn Cohort Extraction Query (Audited & Leak-Free)
-- Database: PostgreSQL (saas schema)
-- Purpose: Extract account-level transactional, billing, behavioral, and 
--          support interaction features with strict temporal hygiene.
-- ============================================================================

SET search_path TO saas;

WITH latest_sub AS (
    -- Identify the primary subscription per account with deterministic status priority
    SELECT DISTINCT ON (account_id)
        subscription_id,
        account_id,
        CASE 
            WHEN LOWER(TRIM(plan)) IN ('pro', 'professional') THEN 'pro'
            WHEN LOWER(TRIM(plan)) = 'enterprise' THEN 'enterprise'
            WHEN LOWER(TRIM(plan)) = 'starter' THEN 'starter'
            WHEN LOWER(TRIM(plan)) = 'free' THEN 'free'
            ELSE LOWER(TRIM(plan))
        END as plan,
        mrr,
        COALESCE(seat_count, 1) as seat_count,
        status as subscription_status,
        start_date as subscription_start_date,
        cancelled_at,
        cancellation_reason
    FROM saas.subscriptions
    ORDER BY account_id, 
        CASE 
            WHEN status = 'active' THEN 1 
            WHEN status = 'churned' THEN 2 
            WHEN status = 'past_due' THEN 3
            ELSE 4 
        END,
        start_date DESC
),
ticket_metrics AS (
    -- Aggregate customer support interactions strictly BEFORE cancellation
    SELECT 
        t.account_id,
        COUNT(t.ticket_id) as total_tickets,
        ROUND(COALESCE(AVG(t.csat), 0)::numeric, 2) as avg_csat,
        COUNT(CASE WHEN t.priority IN ('urgent', 'high') THEN 1 END) as urgent_tickets,
        COUNT(CASE WHEN t.category = 'billing' THEN 1 END) as billing_tickets
    FROM saas.support_tickets t
    JOIN latest_sub s ON t.account_id = s.account_id
    WHERE s.cancelled_at IS NULL OR t.opened_at <= s.cancelled_at
    GROUP BY t.account_id
),
payment_metrics AS (
    -- Aggregate payment attempts strictly BEFORE cancellation (prevents post-churn retry leakage)
    SELECT 
        p.account_id,
        COUNT(p.attempt_id) as total_payment_attempts,
        COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payment_attempts,
        ROUND(COALESCE(SUM(CASE WHEN p.status = 'failed' THEN p.amount ELSE 0 END), 0)::numeric, 2) as failed_payment_amount
    FROM saas.payment_attempts p
    JOIN latest_sub s ON p.account_id = s.account_id
    WHERE s.cancelled_at IS NULL OR p.attempted_at <= s.cancelled_at
    GROUP BY p.account_id
),
event_metrics AS (
    -- Aggregate product engagement strictly BEFORE cancellation (prevents post-churn activity leakage)
    SELECT 
        e.account_id,
        COUNT(e.event_id) as total_events,
        COUNT(CASE WHEN e.event_type = 'login' THEN 1 END) as login_count,
        COUNT(CASE WHEN e.event_type = 'feature_use' THEN 1 END) as feature_use_count,
        COUNT(CASE WHEN e.event_type = 'api_call' THEN 1 END) as api_call_count,
        COUNT(CASE WHEN e.event_type = 'export' THEN 1 END) as export_count,
        COUNT(CASE WHEN e.event_type = 'dashboard_view' THEN 1 END) as dashboard_view_count,
        MAX(e.occurred_at) as last_event_time
    FROM saas.events e
    JOIN latest_sub s ON e.account_id = s.account_id
    WHERE s.cancelled_at IS NULL OR e.occurred_at <= s.cancelled_at
    GROUP BY e.account_id
),
user_metrics AS (
    -- Aggregate provisioned seat adoption and login activity
    SELECT 
        account_id,
        COUNT(user_id) as total_users,
        MAX(last_login_date) as last_user_login
    FROM saas.users
    GROUP BY account_id
)
SELECT 
    a.account_id,
    a.name as company_name,
    COALESCE(a.account_type, 'self_serve') as account_type,
    COALESCE(LOWER(TRIM(a.industry)), 'unknown') as industry,
    COALESCE(a.employee_count, 1) as employee_count,
    CASE 
        WHEN a.country = 'US' THEN 'United States'
        ELSE COALESCE(a.country, 'Unknown')
    END as country,
    a.signup_date,
    COALESCE(LOWER(TRIM(a.acquisition_channel)), 'unknown') as acquisition_channel,
    
    -- Subscription attributes
    s.subscription_id,
    s.plan,
    s.mrr,
    s.seat_count,
    s.subscription_status,
    s.subscription_start_date,
    s.cancelled_at,
    
    -- Ground Truth Churn Target (1 = Churned, 0 = Active)
    CASE 
        WHEN s.subscription_status = 'churned' THEN 1
        WHEN s.subscription_status = 'active' THEN 0
        ELSE NULL
    END as churn,
    
    -- Support distress metrics (clean zeros if no tickets)
    COALESCE(t.total_tickets, 0) as total_tickets,
    COALESCE(t.avg_csat, 0) as avg_csat,
    COALESCE(t.urgent_tickets, 0) as urgent_tickets,
    COALESCE(t.billing_tickets, 0) as billing_tickets,
    
    -- Payment friction metrics (clean zeros if no attempts/failures)
    COALESCE(p.total_payment_attempts, 0) as total_payment_attempts,
    COALESCE(p.failed_payment_attempts, 0) as failed_payment_attempts,
    COALESCE(p.failed_payment_amount, 0) as failed_payment_amount,
    
    -- Engagement signals (clean zeros if no events)
    COALESCE(e.total_events, 0) as total_events,
    COALESCE(e.login_count, 0) as login_count,
    COALESCE(e.feature_use_count, 0) as feature_use_count,
    COALESCE(e.api_call_count, 0) as api_call_count,
    COALESCE(e.export_count, 0) as export_count,
    COALESCE(e.dashboard_view_count, 0) as dashboard_view_count,
    e.last_event_time,
    
    -- User metrics
    COALESCE(u.total_users, 1) as total_users,
    u.last_user_login

FROM saas.accounts a
JOIN latest_sub s ON a.account_id = s.account_id
LEFT JOIN ticket_metrics t ON a.account_id = t.account_id
LEFT JOIN payment_metrics p ON a.account_id = p.account_id
LEFT JOIN event_metrics e ON a.account_id = e.account_id
LEFT JOIN user_metrics u ON a.account_id = u.account_id
WHERE s.subscription_status IN ('active', 'churned')
ORDER BY a.account_id;
