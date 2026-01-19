## Event Notification Configuration

# Property mapping for Pushover webhook body
resource "authentik_property_mapping_notification" "pushover-body" {
  name       = "pushover-body"
  expression = <<-EOF
# Pushover API request body
severity_map = {
    "notice": -1,
    "warning": 0,
    "alert": 1,
}

return {
    "token": "${local.pushover_api_token}",
    "user": "${local.pushover_user_key}",
    "title": f"Authentik: {notification.event.action}",
    "message": notification.body,
    "priority": severity_map.get(notification.severity, 0),
    "url": f"https://sso.${var.cluster_domain}/if/admin/#/events/log/{notification.event.pk}",
    "url_title": "View Event",
}
EOF
}

# Property mapping for Pushover webhook headers
resource "authentik_property_mapping_notification" "pushover-headers" {
  name       = "pushover-headers"
  expression = <<-EOF
return {
    "Content-Type": "application/json",
}
EOF
}

## Event Transport

resource "authentik_event_transport" "pushover" {
  name                    = "pushover"
  mode                    = "webhook"
  webhook_url             = "https://api.pushover.net/1/messages.json"
  webhook_mapping_body    = authentik_property_mapping_notification.pushover-body.id
  webhook_mapping_headers = authentik_property_mapping_notification.pushover-headers.id
  send_once               = true
}

## Event Matcher Policies

resource "authentik_policy_event_matcher" "login-failed" {
  name   = "event-match-login-failed"
  action = "login_failed"
}

resource "authentik_policy_event_matcher" "suspicious-request" {
  name   = "event-match-suspicious-request"
  action = "suspicious_request"
}

resource "authentik_policy_event_matcher" "configuration-error" {
  name   = "event-match-configuration-error"
  action = "configuration_error"
}

resource "authentik_policy_event_matcher" "system-exception" {
  name   = "event-match-system-exception"
  action = "system_exception"
}

resource "authentik_policy_event_matcher" "model-deleted" {
  name   = "event-match-model-deleted"
  action = "model_deleted"
}

resource "authentik_policy_event_matcher" "password-set" {
  name   = "event-match-password-set"
  action = "password_set"
}

resource "authentik_policy_event_matcher" "secret-view" {
  name   = "event-match-secret-view"
  action = "secret_view"
}

resource "authentik_policy_event_matcher" "impersonation-started" {
  name   = "event-match-impersonation-started"
  action = "impersonation_started"
}

## Event Rules

# Security alerts (login failures, suspicious requests, impersonation)
resource "authentik_event_rule" "security-alerts" {
  name       = "security-alerts"
  severity   = "alert"
  destination_group = data.authentik_group.admins.id
  transports = [authentik_event_transport.pushover.id]
}

resource "authentik_policy_binding" "security-login-failed" {
  target = authentik_event_rule.security-alerts.id
  policy = authentik_policy_event_matcher.login-failed.id
  order  = 0
}

resource "authentik_policy_binding" "security-suspicious" {
  target = authentik_event_rule.security-alerts.id
  policy = authentik_policy_event_matcher.suspicious-request.id
  order  = 1
}

resource "authentik_policy_binding" "security-impersonation" {
  target = authentik_event_rule.security-alerts.id
  policy = authentik_policy_event_matcher.impersonation-started.id
  order  = 2
}

# System errors (configuration errors, exceptions)
resource "authentik_event_rule" "system-errors" {
  name       = "system-errors"
  severity   = "warning"
  destination_group = data.authentik_group.admins.id
  transports = [authentik_event_transport.pushover.id]
}

resource "authentik_policy_binding" "system-config-error" {
  target = authentik_event_rule.system-errors.id
  policy = authentik_policy_event_matcher.configuration-error.id
  order  = 0
}

resource "authentik_policy_binding" "system-exception" {
  target = authentik_event_rule.system-errors.id
  policy = authentik_policy_event_matcher.system-exception.id
  order  = 1
}

# Audit events (deletions, secret views, password changes)
resource "authentik_event_rule" "audit-events" {
  name       = "audit-events"
  severity   = "notice"
  destination_group = data.authentik_group.admins.id
  transports = [authentik_event_transport.pushover.id]
}

resource "authentik_policy_binding" "audit-model-deleted" {
  target = authentik_event_rule.audit-events.id
  policy = authentik_policy_event_matcher.model-deleted.id
  order  = 0
}

resource "authentik_policy_binding" "audit-secret-view" {
  target = authentik_event_rule.audit-events.id
  policy = authentik_policy_event_matcher.secret-view.id
  order  = 1
}

resource "authentik_policy_binding" "audit-password-set" {
  target = authentik_event_rule.audit-events.id
  policy = authentik_policy_event_matcher.password-set.id
  order  = 2
}
