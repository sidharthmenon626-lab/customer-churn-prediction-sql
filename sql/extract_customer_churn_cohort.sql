/*
question number: milestone 2 - customer churn cohort extraction
business question: can we extract a clean, leak-free account-level cohort from postgresql to predict customer churn 30 days prior to cancellation?
owner: sidharth menon (lead data analyst)
last updated: 2026-09-28
sanity-check assertion: total accounts = 859 (624 active, 235 churned); zero events, tickets, or payment attempts after cancelled_at.
*/

set search_path to saas;

with latest_subscriptions as (
    select distinct on (s.account_id)
        s.subscription_id
      , s.account_id
      , case 
            when lower(trim(s.plan)) in ('pro', 'professional') then 'pro'
            when lower(trim(s.plan)) = 'enterprise' then 'enterprise'
            when lower(trim(s.plan)) = 'starter' then 'starter'
            when lower(trim(s.plan)) = 'free' then 'free'
            else lower(trim(s.plan))
        end as plan
      , s.mrr
      , coalesce(s.seat_count, 1) as seat_count
      , s.status as subscription_status
      , s.start_date as subscription_start_date
      , s.cancelled_at
      , s.cancellation_reason
    from saas.subscriptions s
    order by 
        s.account_id
      , case 
            when s.status = 'active' then 1 
            when s.status = 'churned' then 2 
            when s.status = 'past_due' then 3
            else 4 
        end
      , s.start_date desc
)

, support_ticket_metrics as (
    select 
        st.account_id
      , count(st.ticket_id) as total_tickets
      , round(coalesce(avg(st.csat), 0)::numeric, 2) as avg_csat
      , count(case when st.priority in ('urgent', 'high') then 1 end) as urgent_tickets
      , count(case when st.category = 'billing' then 1 end) as billing_tickets
    from saas.support_tickets st
    join latest_subscriptions sub
        on st.account_id = sub.account_id
    where sub.cancelled_at is null or st.opened_at <= sub.cancelled_at
    group by 
        st.account_id
)

, payment_attempt_metrics as (
    select 
        pa.account_id
      , count(pa.attempt_id) as total_payment_attempts
      , count(case when pa.status = 'failed' then 1 end) as failed_payment_attempts
      , round(coalesce(sum(case when pa.status = 'failed' then pa.amount else 0 end), 0)::numeric, 2) as failed_payment_amount
    from saas.payment_attempts pa
    join latest_subscriptions sub
        on pa.account_id = sub.account_id
    where sub.cancelled_at is null or pa.attempted_at <= sub.cancelled_at
    group by 
        pa.account_id
)

, event_telemetry_metrics as (
    select 
        ev.account_id
      , count(ev.event_id) as total_events
      , count(case when ev.event_type = 'login' then 1 end) as login_count
      , count(case when ev.event_type = 'feature_use' then 1 end) as feature_use_count
      , count(case when ev.event_type = 'api_call' then 1 end) as api_call_count
      , count(case when ev.event_type = 'export' then 1 end) as export_count
      , count(case when ev.event_type = 'dashboard_view' then 1 end) as dashboard_view_count
      , max(ev.occurred_at) as last_event_time
    from saas.events ev
    join latest_subscriptions sub
        on ev.account_id = sub.account_id
    where sub.cancelled_at is null or ev.occurred_at <= sub.cancelled_at
    group by 
        ev.account_id
)

, user_seat_metrics as (
    select 
        u.account_id
      , count(u.user_id) as total_users
      , max(u.last_login_date) as last_user_login
    from saas.users u
    group by 
        u.account_id
)

select 
    acc.account_id
  , acc.name as company_name
  , coalesce(acc.account_type, 'self_serve') as account_type
  , coalesce(lower(trim(acc.industry)), 'unknown') as industry
  , coalesce(acc.employee_count, 1) as employee_count
  , case 
        when acc.country = 'US' then 'United States'
        else coalesce(acc.country, 'Unknown')
    end as country
  , acc.signup_date
  , coalesce(lower(trim(acc.acquisition_channel)), 'unknown') as acquisition_channel
  , sub.subscription_id
  , sub.plan
  , sub.mrr
  , sub.seat_count
  , sub.subscription_status
  , sub.subscription_start_date
  , sub.cancelled_at
  , case 
        when sub.subscription_status = 'churned' then 1
        when sub.subscription_status = 'active' then 0
        else null
    end as churn
  , coalesce(stm.total_tickets, 0) as total_tickets
  , coalesce(stm.avg_csat, 0) as avg_csat
  , coalesce(stm.urgent_tickets, 0) as urgent_tickets
  , coalesce(stm.billing_tickets, 0) as billing_tickets
  , coalesce(pam.total_payment_attempts, 0) as total_payment_attempts
  , coalesce(pam.failed_payment_attempts, 0) as failed_payment_attempts
  , coalesce(pam.failed_payment_amount, 0) as failed_payment_amount
  , coalesce(etm.total_events, 0) as total_events
  , coalesce(etm.login_count, 0) as login_count
  , coalesce(etm.feature_use_count, 0) as feature_use_count
  , coalesce(etm.api_call_count, 0) as api_call_count
  , coalesce(etm.export_count, 0) as export_count
  , coalesce(etm.dashboard_view_count, 0) as dashboard_view_count
  , etm.last_event_time
  , coalesce(usm.total_users, 1) as total_users
  , usm.last_user_login
from saas.accounts acc
join latest_subscriptions sub
    on acc.account_id = sub.account_id
left join support_ticket_metrics stm
    on acc.account_id = stm.account_id
left join payment_attempt_metrics pam
    on acc.account_id = pam.account_id
left join event_telemetry_metrics etm
    on acc.account_id = etm.account_id
left join user_seat_metrics usm
    on acc.account_id = usm.account_id
where sub.subscription_status in ('active', 'churned')
order by 
    acc.account_id;
