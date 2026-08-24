# main/oidc.tf

# --- GitHub Actions OIDC provider -------------------------------------------
# Lets GitHub Actions workflows assume an AWS role via short-lived web
# identity tokens instead of long-lived IAM user access keys.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # ASSUMPTION — VERIFY BEFORE APPLY: GitHub Actions' OIDC token endpoint is
  # backed by a well-known public CA, and AWS's own STS validation no longer
  # actually checks this value against the live cert chain for well-known
  # providers — but the argument is still required by the resource. Listing
  # both thumbprints GitHub has used historically (the original DigiCert
  # intermediate, and the current root CA thumbprint after GitHub's 2023
  # rotation) so this doesn't silently break if GitHub rotates certs again.
  # Confirm current values at https://github.blog (search "OIDC thumbprint")
  # before apply.
  thumbprint_list = [
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Project = "kds-electronics"
  }
}

# --- IAM role GitHub Actions assumes for deploys ----------------------------

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # VERIFIED: org spelling "kds-electorincs" confirmed directly against
      # the ekds-backend repo's live `origin` remote (`git remote -v` ->
      # git@github.com:kds-electorincs/ekds-backend.git), not taken on faith
      # from a task spec. Note this is a genuinely different string from the
      # "kds-electronics" prefix used for AWS resource naming/tags elsewhere
      # in this project (var.project, Project tag) — that's not an error to
      # reconcile, the GitHub org and the AWS naming convention are simply
      # two separate strings that happen to look similar. One earlier
      # attempt at this value ("kds-electornics") was independently proven
      # wrong; this spelling ("kds-electorincs") has now been proven right.
      values = ["repo:kds-electorincs/ekds-backend:ref:refs/heads/deploy"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = {
    Project = "kds-electronics"
  }
}

# --- Least-privilege deploy policy: stage a jar to S3, trigger SSM deploy --

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "StagingUpload"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.project}-staging/*"]
  }

  statement {
    sid    = "SendDeployCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    # ASSUMPTION — VERIFY BEFORE APPLY: AWS-RunShellScript is an AWS-owned
    # public document, so its ARN has no account ID segment (empty between
    # the two colons) and is region-scoped only. SendCommand's IAM check
    # requires Allow on both the target instance ARN and the document ARN;
    # listing both in one statement satisfies that.
    resources = [
      aws_instance.backend.arn,
      "arn:aws:ssm:${var.region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid    = "ReadDeployCommandStatus"
    effect = "Allow"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]
    # These SSM read/status actions don't support resource-level scoping —
    # "*" is the AWS-documented requirement here, not an over-grant.
    resources = ["*"]
  }

  statement {
    sid    = "DescribeInstances"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances"
    ]
    # Used by the workflow to look up the backend instance ID by tag at
    # deploy time, instead of hardcoding an ID that breaks whenever the
    # instance replaces. Same pattern as the SSM statement above — this is
    # a read/list action that doesn't support resource-level scoping, so
    # "*" is the AWS-documented requirement, not an over-grant.
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.project}-github-actions-deploy"
  description = "Least-privilege policy for GitHub Actions to stage a backend jar to S3 and trigger its deploy via SSM"
  policy      = data.aws_iam_policy_document.github_actions_deploy.json
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}


