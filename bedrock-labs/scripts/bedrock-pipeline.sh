```bash
#!/bin/bash

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${BUCKET_NAME:-tes-aws-july-batch-bucket}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INPUT_DIR="$PROJECT_ROOT/input"
OUTPUT_DIR="$PROJECT_ROOT/output"
INVOICE_FILE="${INVOICE_FILE:-$PROJECT_ROOT/input/invoice-image.jfif}"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

if [ ! -f "$INVOICE_FILE" ]; then
    echo "Missing invoice file: $INVOICE_FILE"
    echo "Place the invoice image there or set INVOICE_FILE to a valid local path before running the pipeline."
    exit 1
fi

echo "=================================================="
echo " AWS AI DOCUMENT PROCESSING PIPELINE"
echo "=================================================="

echo ""
echo "--------------------------------"
echo "STEP 1 - Uploading invoice image to S3"
echo "--------------------------------"

aws s3 cp "$INVOICE_FILE" "s3://$BUCKET_NAME/image/invoice-image.jfif" --region "$REGION"

echo "✅ Image uploaded to S3"

echo ""
echo "--------------------------------"
echo "STEP 2 - Running Textract OCR"
echo "--------------------------------"

aws textract detect-document-text \
    --document "S3Object={Bucket=$BUCKET_NAME,Name=image/invoice-image.jfif}" \
    --region "$REGION" \
    > "$OUTPUT_DIR/textract-output.json"

echo "✅ Textract output saved"

echo ""
echo "--------------------------------"
echo "STEP 3 - Extracting clean text"
echo "--------------------------------"

python3 "$SCRIPT_DIR/extract-textract-text.py"

echo ""
echo "--------------------------------"
echo "STEP 4 - Creating Bedrock request"
echo "--------------------------------"

python3 "$SCRIPT_DIR/create-bedrock-request.py"

echo ""
echo "--------------------------------"
echo "STEP 5 - Invoking Amazon Bedrock"
echo "--------------------------------"

aws bedrock-runtime invoke-model \
    --model-id amazon.nova-lite-v1:0 \
    --body "file://$INPUT_DIR/bedrock-request.json" \
    --region "$REGION" \
    --cli-binary-format raw-in-base64-out \
    > "$OUTPUT_DIR/output.json"

echo "✅ Bedrock response generated"

echo ""
echo "--------------------------------"
echo "STEP 6 - Extracting Bedrock response"
echo "--------------------------------"

python3 "$SCRIPT_DIR/extract.py"

echo ""
echo "--------------------------------"
echo "STEP 7 - Uploading summary to S3"
echo "--------------------------------"

aws s3 cp "$OUTPUT_DIR/final-response.txt" "s3://$BUCKET_NAME/output/final-response.txt" --region "$REGION"

echo "✅ Summary uploaded to S3"

echo ""
echo "--------------------------------"
echo "STEP 8 - Generating speech using Polly"
echo "--------------------------------"

TEXT="$(tr -d '\r' < "$OUTPUT_DIR/final-response.txt")"

aws polly synthesize-speech \
    --output-format mp3 \
    --voice-id Joanna \
    --text "$TEXT" \
    --region "$REGION" \
    "$OUTPUT_DIR/audio-summary.mp3"

echo "✅ Audio summary generated"

echo ""
echo "--------------------------------"
echo "STEP 9 - Uploading audio to S3"
echo "--------------------------------"

aws s3 cp "$OUTPUT_DIR/audio-summary.mp3" "s3://$BUCKET_NAME/output/audio-summary.mp3" --region "$REGION"

echo "✅ Audio uploaded to S3"

echo ""
echo "=================================================="
echo " PIPELINE COMPLETED SUCCESSFULLY"
echo "=================================================="

echo ""
echo "Generated Outputs:"
echo "--------------------------------"
echo "1. $OUTPUT_DIR/textract-output.json"
echo "2. $OUTPUT_DIR/extracted-text.txt"
echo "3. $OUTPUT_DIR/output.json"
echo "4. $OUTPUT_DIR/final-response.txt"
echo "5. $OUTPUT_DIR/audio-summary.mp3"
echo ""
```
