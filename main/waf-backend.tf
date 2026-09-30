# main/waf-backend.tf

# --- AWS WAFv2 Web ACL: edge-level, coarse, IP-only flood protection -------
#
# Sits in front of the backend API CloudFront distribution
# (aws_cloudfront_distribution.backend, cloudfront-backend.tf). Complements
# — does not replace — the app-level Bucket4j rate-limit filter already in
# kds-web (see RateLimitFilter / kds-rate-limit.properties in the ekds repo):
# that filter enforces tight, per-endpoint-group limits (5/min login,
# 60/min search, 30/min cart, ...) inside the app; this Web ACL is a much
# looser backstop against volumetric floods, evaluated before a request
# ever reaches CloudFront's origin.
#
# RECON NOTE: the brief named CloudFront domain d1jlyjicb9jfz0.cloudfront.net
# as the attach target. That domain does not resolve and does not match
# either distribution actually in this AWS account (checked via
# `aws cloudfront list-distributions --profile kds-client`):
#   - kds-electronics-13062026 backend API      -> dof5qsx1h7mp3.cloudfront.net (aws_cloudfront_distribution.backend)
#   - kds-electronics-13062026 catalog images   -> d3qrireo7rmkke.cloudfront.net (aws_cloudfront_distribution.images)
# Neither had a web_acl_id set. This Web ACL is attached to
# aws_cloudfront_distribution.backend (see cloudfront-backend.tf) since that's
# the one actually fronting API traffic — the one the Bucket4j filter also
# guards, matching the brief's stated intent ("complements the app-level
# filter"). Flagging this rather than silently trusting the given domain;
# confirm before applying if a different distribution was actually meant.

# CLOUDFRONT-scope Web ACLs must live in us-east-1 regardless of the
# distribution's own region (ap-south-1) — see the aws.us_east_1 provider
# alias added in versions.tf.
resource "aws_wafv2_web_acl" "backend" {
  provider = aws.us_east_1

  name        = "${var.project}-backend-waf"
  description = "Edge-level flood protection for the backend API CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # --- AWS Managed Rule Groups: COUNT mode, NOT enforced yet -----------------
  # Deliberately left in COUNT (override_action = count, not block) so
  # Shashvat can review CloudWatch sampled requests / false-positive risk
  # against real traffic before flipping either group to BLOCK
  # (override_action -> none, so each rule's own action inside the group
  # applies). Do not change these to enforcing mode without that review.

  rule {
    name     = "aws-common-rule-set-count-only"
    priority = 1

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-common-rule-set-count"
    }
  }

  rule {
    name     = "aws-known-bad-inputs-count-only"
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-known-bad-inputs-count"
    }
  }

  # --- Rate-based rule: the actual enforcement rule in this ACL -------------
  # Aggregates by client IP, WAF's native rolling 5-minute window. 2000
  # req/5min is intentionally loose relative to the app-level Bucket4j
  # limits — this rule's job is stopping volumetric floods, not normal
  # endpoint-level abuse (that's already handled inside the app).
  rule {
    name     = "ip-rate-limit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-ip-rate-limit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-backend-waf"
  }

  tags = {
    Project = "kds-electronics"
    Purpose = "backend-api-waf"
  }
}

# --- Alerting -----------------------------------------------------------
#
# RECON NOTE: grepped the whole repo for "sns_topic" / "kds-alerts" — no
# existing SNS topic of any name exists yet (the brief said "reuse ... if
# present", anticipating this could go either way). Creating a new,
# minimal topic here rather than leaving the alarm without an action —
# it's WAF/CloudWatch-adjacent, not a pre-existing unrelated resource, and
# it's easy to redirect (or drop) before apply. No subscription is created
# (an email subscription would need manual confirmation anyway, and
# guessing a destination isn't this task's call) — Shashvat can add one to
# this topic once it exists.
resource "aws_sns_topic" "kds_alerts" {
  provider = aws.us_east_1
  name     = "${var.project}-alerts"

  tags = {
    Project = "kds-electronics"
    Purpose = "ops-alerts"
  }
}

# Fires if the Web ACL blocks an unusual number of requests in 5 minutes —
# i.e. a real flood is actually being stopped, not silently absorbed.
# Must live in us-east-1 alongside the Web ACL: CLOUDFRONT-scope WAFv2
# metrics are only published to CloudWatch in that region regardless of
# where the distribution itself runs.
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  provider = aws.us_east_1

  alarm_name          = "${var.project}-waf-blocked-requests-high"
  alarm_description   = "Backend API WAF blocked more than 100 requests in a 5-minute window"
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.backend.name
    Region = "us-east-1"
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.kds_alerts.arn]
  ok_actions    = [aws_sns_topic.kds_alerts.arn]

  tags = {
    Project = "kds-electronics"
    Purpose = "backend-api-waf"
  }
}
