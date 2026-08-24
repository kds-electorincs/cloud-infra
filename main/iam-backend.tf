# main/iam-backend.tf

# --- IAM: backend access to the image bucket --------------------------------

# Policy document — least-privilege, scoped to JUST the image bucket
data "aws_iam_policy_document" "backend_s3" {
  statement {
    sid    = "ObjectLevel"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.images.arn}/*",
    ]
  }

  statement {
    sid    = "BucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.images.arn,
    ]
  }
}

resource "aws_iam_policy" "backend_s3" {
  name        = "${var.project}-backend-s3"
  description = "Allows the KDS backend to sign presigned PUT/GET URLs for the image bucket"
  policy      = data.aws_iam_policy_document.backend_s3.json
}

# Role the EC2 backend will assume (instance profile attached at the EC2 stage)
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${var.project}-backend"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Project = "kds-electronics"
  }
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend_s3.arn
}

# --- IAM: SSM Session Manager access (replaces open-SSH need) ---------------

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- IAM: backend read access to Parameter Store (app config/secrets) ------

data "aws_iam_policy_document" "backend_parameter_store" {
  statement {
    sid    = "ReadProdParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParametersByPath",
    ]
    # ASSUMPTION — VERIFY BEFORE APPLY: account ID left as wildcard (matches
    # the style of other ARNs in this file where the account is implicit);
    # confirm this resolves correctly for this account, or replace "*" with
    # the literal 12-digit account ID if stricter scoping is preferred.
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/kds/prod/*",
    ]
  }
}

resource "aws_iam_policy" "backend_parameter_store" {
  name        = "${var.project}-backend-parameter-store"
  description = "Allows the KDS backend to read its config/secrets from SSM Parameter Store under /kds/prod/"
  policy      = data.aws_iam_policy_document.backend_parameter_store.json
}

resource "aws_iam_role_policy_attachment" "backend_parameter_store" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend_parameter_store.arn
}

# --- IAM: backend read access to the deploy staging bucket -----------------

data "aws_iam_policy_document" "backend_staging_read" {
  statement {
    sid       = "ReadStagingJar"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.staging.arn}/*"]
  }
  statement {
    sid       = "ListStagingBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.staging.arn]
  }
}

resource "aws_iam_policy" "backend_staging_read" {
  name        = "${var.project}-backend-staging-read"
  description = "Allows the backend EC2 to pull the deployed jar from the staging bucket"
  policy      = data.aws_iam_policy_document.backend_staging_read.json
}

resource "aws_iam_role_policy_attachment" "backend_staging_read" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend_staging_read.arn
}
