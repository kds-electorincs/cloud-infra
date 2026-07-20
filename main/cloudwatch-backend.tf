# main/cloudwatch-backend.tf

# --- Grant the backend EC2's existing role permission to push metrics/logs -

resource "aws_iam_role_policy_attachment" "backend_cloudwatch" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
