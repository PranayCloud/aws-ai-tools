#!/bin/bash
set -e

# ─────────────────────────────────────────────
# CONFIGURATION — edit these before running
# ─────────────────────────────────────────────
REGION="us-east-1"
INSTANCE_TYPE="t3.small"
AMI_ID="ami-0236922087fa98b6e"        # Amazon Linux 2 (us-east-1) — update if needed
KEY_NAME="${KEY_NAME:-<your-key-pair-name>}"        # Must already exist in your AWS account
IAM_INSTANCE_PROFILE="${INSTANCE_PROFILE_NAME:-<your-instance-profile-name>}"  # Must have bedrock:InvokeModel permission
APP_PORT=5000
SG_NAME="nova-lite-sg"
INSTANCE_NAME="nova-lite-app"
# ─────────────────────────────────────────────

echo "==> Checking security group: $SG_NAME"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$REGION")

SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$REGION" 2>/dev/null || echo "None")

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  echo "==> Creating security group: $SG_NAME"
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group for Nova Lite Flask app" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query "GroupId" \
    --output text)

  echo "    Security Group ID: $SG_ID"

  echo "==> Adding inbound rules (SSH + app port)"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 \
    --region "$REGION"

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp --port "$APP_PORT" --cidr 0.0.0.0/0 \
    --region "$REGION"
else
  echo "    ℹ Security group '$SG_NAME' already exists ($SG_ID), skipping creation."
fi

echo "==> Launching EC2 instance"
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile Name="$IAM_INSTANCE_PROFILE" \
  --user-data file://userdata.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --region "$REGION" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "    Instance ID: $INSTANCE_ID"

echo "==> Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region "$REGION")

echo ""
echo "✅ Instance is running!"
echo "   Instance ID : $INSTANCE_ID"
echo "   Public IP   : $PUBLIC_IP"
echo "   App URL     : http://$PUBLIC_IP:$APP_PORT"
echo ""
echo "Note: The app may take ~2 minutes to finish installing on first boot."
echo "SSH  : ssh -i <your-key.pem> ec2-user@$PUBLIC_IP"
