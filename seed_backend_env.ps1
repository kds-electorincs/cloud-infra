# =============================================================================
# KDS Electronics ? push prod config to AWS SSM Parameter Store
# Run from a machine with the kds-client AWS profile configured.
# NOTE: deploy.sh sources SSM at DEPLOY time. Running this script alone does
# NOT change the running app ? a `systemctl restart` will not re-fetch SSM.
# You must trigger an actual deploy for changes here to take effect.
# =============================================================================

$profile = "kds-client"
$region  = "ap-south-1"

function Put-Param {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Type = "String"
    )
    aws ssm put-parameter `
        --name  "/kds/prod/$Name" `
        --value $Value `
        --type  $Type `
        --overwrite `
        --profile $profile `
        --region  $region | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  ok   $Name" -ForegroundColor Green }
    else                     { Write-Host "  FAIL $Name" -ForegroundColor Red }
}

Write-Host "`n--- Secrets (SecureString) ---" -ForegroundColor Cyan
# NOTE: SINGLE quotes on every secret. PowerShell interpolates $ inside double
# quotes ? a value containing $ would be silently corrupted.
Put-Param 'DB_PASSWORD'              '9WKGCHAWhYimsxYWjJhp9WKGCHAWhYimsxYWjJhp'                     'SecureString'
Put-Param 'JWT_SECRET'               '+PKM+acrjF3up1dUz6evE9pL3X1C8J4C7q2G00udwDB+/DKAMFgCiuL4MqRwmrFL' 'SecureString'
Put-Param 'RAZORPAY_KEY_SECRET'      'z4677PTpf58FrEDH7rVB44V7'                                      'SecureString'
Put-Param 'RAZORPAY_WEBHOOK_SECRET'  '>$LJsg-Hft+0_pc@-x6-^fizL7%5[ZTp@1y0?%-o0Nn'                   'SecureString'
Put-Param 'MEILI_MASTER_KEY'         'uWYPle7hyMUZwaxD8o0dtTAREprbXiqs'                              'SecureString'
Put-Param 'MAIL_PURCHASE_PASSWORD'   'gcsuievljbmjteet'                                              'SecureString'
Put-Param 'MAIL_ACCOUNT_PASSWORD'    'gcsuievljbmjteet'                                              'SecureString'

Write-Host "`n--- Core config ---" -ForegroundColor Cyan
Put-Param 'SPRING_PROFILE'     'prod'
Put-Param 'DB_URL'             'jdbc:postgresql://kds-electronics-13062026-db.c7884isim37j.ap-south-1.rds.amazonaws.com:5432/kdselectronics'
Put-Param 'DB_USERNAME'        'kds_admin'
Put-Param 'FRONTEND_BASE_URL'  'https://webkds-mauve.vercel.app/'
Put-Param 'BACKEND_BASE_URL'   'https://dof5qsx1h7mp3.cloudfront.net'
Put-Param 'GOOGLE_CLIENT_ID'   '895892165403-end7d42vrpmecr4ob5oohdnqh1750s0u.apps.googleusercontent.com'

Write-Host "`n--- S3 / CDN ---" -ForegroundColor Cyan
Put-Param 'S3_BUCKET'  'kds-electronics-13062026-images'
Put-Param 'S3_REGION'  'ap-south-1'
Put-Param 'CDN_DOMAIN' 'd3qrireo7rmkke.cloudfront.net'
# S3_PROFILE deliberately NOT set in prod ? EC2 uses its instance role via
# DefaultCredentialsProvider. Setting it would break S3 on the box.

Write-Host "`n--- S3 cleanup job ---" -ForegroundColor Cyan
Put-Param 'S3_CLEANUP_DRY_RUN'     'false'
Put-Param 'S3_CLEANUP_GRACE_HOURS' '48'
# S3_CLEANUP_CRON and S3_CLEANUP_ZONE deliberately NOT set ? the cron value
# contains spaces and the instance-side SSM->env sourcing is unverified for
# that case (systemd EnvironmentFile rejects unquoted spaces). Both are
# correct as file defaults in application-prod.properties. Do not move them
# here without first verifying deploy.sh handles spaced values.

Write-Host "`n--- Search ---" -ForegroundColor Cyan
Put-Param 'MEILI_HOST' 'http://localhost:7700'

Write-Host "`n--- Payments ---" -ForegroundColor Cyan
Put-Param 'RAZORPAY_KEY_ID' 'rzp_test_TQVYIQUNkKvm9P'

Write-Host "`n--- Mail ---" -ForegroundColor Cyan
Put-Param 'MAIL_HOST'                  'smtp.gmail.com'
Put-Param 'MAIL_PORT'                  '587'
Put-Param 'MAIL_AUTH'                  'true'
Put-Param 'MAIL_STARTTLS_ENABLE'       'true'
Put-Param 'MAIL_CONNECTION_TIMEOUT'    '5000'
Put-Param 'MAIL_TIMEOUT'               '10000'
Put-Param 'MAIL_WRITE_TIMEOUT'         '10000'
Put-Param 'MAIL_PURCHASE_USERNAME'     'rajyagurushashvat@gmail.com'
Put-Param 'MAIL_PURCHASE_FROM_ADDRESS' 'rajyagurushashvat@gmail.com'
Put-Param 'MAIL_PURCHASE_FROM_NAME'    'KDS Electronics Orders'
Put-Param 'MAIL_ACCOUNT_USERNAME'      'rajyagurushashvat@gmail.com'
Put-Param 'MAIL_ACCOUNT_FROM_ADDRESS'  'rajyagurushashvat@gmail.com'
Put-Param 'MAIL_ACCOUNT_FROM_NAME'     'KDS Electronics Accounts'

Write-Host "`nDone. Remember: run an actual deploy - systemctl restart won't re-fetch SSM.`n" -ForegroundColor Yellow