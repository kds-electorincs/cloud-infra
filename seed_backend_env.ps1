$profile = "kds-client"
$region = "ap-south-1"

# --- Secrets (SecureString) ---
aws ssm put-parameter --name "/kds/prod/DB_PASSWORD" --value "9WKGCHAWhYimsxYWjJhp9WKGCHAWhYimsxYWjJhp" --type SecureString --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/JWT_SECRET" --value "+PKM+acrjF3up1dUz6evE9pL3X1C8J4C7q2G00udwDB+/DKAMFgCiuL4MqRwmrFL" --type SecureString --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/RAZORPAY_KEY_SECRET" --value "z4677PTpf58FrEDH7rVB44V7" --type SecureString --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/RAZORPAY_WEBHOOK_SECRET" --value ">$LJsg-Hft+0_pc@-x6-^fizL7%5[ZTp@1y0?%-o0Nn" --type SecureString --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/MEILI_MASTER_KEY" --value "uWYPle7hyMUZwaxD8o0dtTAREprbXiqs" --type SecureString --profile $profile --region $region

# --- Config (String, non-secret) ---
aws ssm put-parameter --name "/kds/prod/DB_URL" --value "jdbc:postgresql://kds-electronics-13062026-db.c7884isim37j.ap-south-1.rds.amazonaws.com:5432/kdselectronics" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/DB_USERNAME" --value "kds_admin" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/FRONTEND_BASE_URL" --value "PASTE_HERE" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/GOOGLE_CLIENT_ID" --value "895892165403-end7d42vrpmecr4ob5oohdnqh1750s0u.apps.googleusercontent.com" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/S3_BUCKET" --value "kds-electronics-13062026-images" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/S3_REGION" --value "ap-south-1" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/CDN_DOMAIN" --value "d3g4lbxrdesurj.cloudfront.net" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/S3_PROFILE" --value "kds-client" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/MEILI_HOST" --value "http://localhost:7700" --type String --profile $profile --region $region
aws ssm put-parameter --name "/kds/prod/RAZORPAY_KEY_ID" --value "rzp_test_TQVYIQUNkKvm9P" --type String --profile $profile --region $region