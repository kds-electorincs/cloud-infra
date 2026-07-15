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
