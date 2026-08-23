REGION="us-east-1"

aws bedrock-runtime invoke-model \
    --model-id amazon.nova-lite-v1:0 \
    --body file://output/textract-output.json \
    --region "$REGION" \
    --cli-binary-format raw-in-base64-out \
    output/output.json

echo "✅ Inference complete. Output saved to output/output.json"
echo "Extracting generated text..."
echo "--------------------------------"
python3 scripts/extract.py
echo "--------------------------------"