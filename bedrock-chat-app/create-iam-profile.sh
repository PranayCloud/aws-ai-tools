#!/bin/bash
set -e

# ─────────────────────────────────────────────
# CONFIGURATION — only edit this section
# ─────────────────────────────────────────────
REGION="us-east-1"
KEY_NAME="aws-ai-practioner-key"         # Must already exist in your AWS account
ROLE_NAME="nova-lite-ec2-role"
POLICY_NAME="nova-lite-bedrock-policy"
INSTANCE_PROFILE_NAME="nova-lite-instance-profile"
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── STEP 1: Check dependencies ────────────────
check_dependencies() {
  echo "==> Checking dependencies"

  if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found. Install it: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
  fi
  echo "    ✔ AWS CLI: $(aws --version 2>&1 | head -n1)"

  if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found. Please install Python 3."
    exit 1
  fi
  echo "    ✔ Python: $(python3 --version)"

  if ! command -v pip3 &>/dev/null; then
    echo "❌ pip3 not found. Please install pip."
    exit 1
  fi
  echo "    ✔ pip3 found"

  echo "==> Installing Python packages (boto3, flask)"
  pip3 install --quiet boto3 flask
  echo "    ✔ boto3 and flask installed"

  # Verify AWS credentials are configured
  if ! aws sts get-caller-identity --region "$REGION" &>/dev/null; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
  fi
  echo "    ✔ AWS credentials valid"

  # Validate key pair exists
  if [[ "$KEY_NAME" == "<your-key-pair-name>" ]]; then
    echo "❌ Please set KEY_NAME in this script before running."
    exit 1
  fi
  if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
    echo "❌ Key pair '$KEY_NAME' not found in region $REGION."
    exit 1
  fi
  echo "    ✔ Key pair '$KEY_NAME' found"
}

# ── STEP 2: Create IAM role + instance profile ─
create_iam_profile() {
  echo "==> Creating IAM role: $ROLE_NAME"

  # Skip if role already exists
  if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "    ℹ Role '$ROLE_NAME' already exists, skipping creation."
  else
    aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Principal": { "Service": "ec2.amazonaws.com" },
          "Action": "sts:AssumeRole"
        }]
      }' \
      --description "EC2 role for Nova Lite app to invoke Amazon Bedrock" > /dev/null
    echo "    ✔ Role created"
  fi

  echo "==> Attaching Bedrock InvokeModel policy"
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [{
        \"Effect\": \"Allow\",
        \"Action\": \"bedrock:InvokeModel\",
        \"Resource\": \"arn:aws:bedrock:$REGION::foundation-model/amazon.nova-lite-v1:0\"
      }]
    }"
  echo "    ✔ Policy attached"

  echo "==> Creating instance profile: $INSTANCE_PROFILE_NAME"
  if aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME" &>/dev/null; then
    echo "    ℹ Instance profile already exists, skipping creation."
  else
    aws iam create-instance-profile \
      --instance-profile-name "$INSTANCE_PROFILE_NAME" > /dev/null
    aws iam add-role-to-instance-profile \
      --instance-profile-name "$INSTANCE_PROFILE_NAME" \
      --role-name "$ROLE_NAME"
    echo "    ✔ Instance profile created and role attached"

    # IAM propagation delay
    echo "    ⏳ Waiting 10s for IAM propagation..."
    sleep 10
  fi
}

# ── STEP 3: Launch EC2 ────────────────────────
launch_ec2() {
  echo "==> Handing off to launch-ec2.sh"

  if [[ ! -f "$SCRIPT_DIR/launch-ec2.sh" ]]; then
    echo "❌ launch-ec2.sh not found in $SCRIPT_DIR"
    exit 1
  fi

  chmod +x "$SCRIPT_DIR/launch-ec2.sh"

  # Pass resolved values as env vars so launch-ec2.sh needs no manual edits
  export REGION KEY_NAME INSTANCE_PROFILE_NAME
  bash "$SCRIPT_DIR/launch-ec2.sh"
}

# ── MAIN ──────────────────────────────────────
echo ""
echo "🚀 Nova Lite — Full Deployment"
echo "────────────────────────────────"
check_dependencies
create_iam_profile
launch_ec2
