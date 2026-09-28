-- ============================================================================
-- Customer Churn Cohort Extraction Query
-- Database: PostgreSQL (saas schema)
-- Purpose: Extract account-level transactional, billing, behavioral, and 
--          support interaction features for churn prediction modeling.
-- ============================================================================

SET search_path TO saas;

WITH latest_sub AS (
    -- Identify the primary subscription per account with deterministic status priority
    SELECT DISTINCT ON (account_id)
        subscription_id,
        account_id,
        LOWER(TRIM(plan)) as plan,
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
    -- Aggregate customer support interactions and distress signals
    SELECT 
        account_id,
        COUNT(ticket_id) as total_tickets,
        COALESCE(AVG(csat), 0) as avg_csat,
        COUNT(CASE WHEN priority IN ('urgent', 'high') THEN 1 END) as urgent_tickets,
        COUNT(CASE WHEN category = 'billing' THEN 1 END) as billing_tickets
    FROM saas.support_tickets
    GROUP BY account_id
),
payment_metrics AS (
    -- Aggregate invoice payment attempts and friction metrics
    SELECT 
        account_id,
        COUNT(attempt_id) as total_payment_attempts,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_payment_attempts,
        COALESCE(SUM(CASE WHEN status = 'failed' THEN amount ELSE 0 END), 0) as failed_payment_amount
    FROM saas.payment_attempts
    GROUP BY account_id
),
event_metrics AS (
    -- Aggregate product engagement and feature adoption signals
    SELECT 
        account_id,
        COUNT(event_id) as total_events,
        COUNT(CASE WHEN event_type = 'login' THEN 1 END) as login_count,
        COUNT(CASE WHEN event_type = 'feature_use' THEN 1 END) as feature_use_count,
        COUNT(CASE WHEN event_type = 'api_call' THEN 1 END) as api_call_count,
        COUNT(CASE WHEN event_type = 'export' THEN 1 END) as export_count,
        COUNT(CASE WHEN event_type = 'dashboard_view' THEN 1 END) as dashboard_view_count,
        MAX(occurred_at) as last_event_time
    FROM saas.events
    GROUP BY account_id
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
    COALESCE(a.industry, 'Technology') as industry,
    COALESCE(a.employee_count, 1) as employee_count,
    COALESCE(a.country, 'United States') as country,
    a.signup_date,
    COALESCE(a.acquisition_channel, 'organic') as acquisition_channel,
    
    -- Subscription attributes
    s.subscription_id,
    s.plan,
    s.mrr,
    s.seat_count,
    s.subscription_status,
    s.subscription_start_date,
    s.cancelled_at,
    
    -- Ground Truth Churn Target
    CASE 
        WHEN s.subscription_status = 'churned' THEN 1
        WHEN s.subscription_status = 'active' THEN 0
        ELSE NULL
    END as churn,
    
    -- Support distress metrics
    COALESCE(t.total_tickets, 0) as total_tickets,
    ROUND(COALESCE(t.avg_csat, 0)::numeric, 2) as avg_csat,
    COALESCE(t.urgent_tickets, 0) as urgent_tickets,
    COALESCE(t.billing_tickets, 0) as billing_tickets,
    
    -- Payment friction metrics
    COALESCE(p.total_payment_attempts, 0) as total_payment_attempts,
    COALESCE(p.failed_payment_attempts, 0) as failed_payment_attempts,
    ROUND(COALESCE(p.failed_payment_amount, 0)::numeric, 2) as failed_payment_amount,
    
    -- Engagement signals
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
