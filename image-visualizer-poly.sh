#!/bin/bash
# This is a image visualizer script
BUCKET_NAME="my-ai-bucket-for-practioner"
REGION="us-east-1"
IMAGE_PATH=$1
IMAGE_NAME=$(basename "$IMAGE_PATH")

# Upload the image to S3   

echo "Uploading $IMAGE_PATH to s3://$BUCKET_NAME/$IMAGE_NAME"
aws s3 cp "$IMAGE_PATH" "s3://$BUCKET_NAME/$IMAGE_NAME" --region "$REGION"


# Detect text in the image
echo "Detecting text in the image..."
TEXT=$(aws rekognition detect-text \
    --image "{\"S3Object\":{\"Bucket\":\"$BUCKET_NAME\",\"Name\":\"$IMAGE_NAME\"}}" \
    --query 'TextDetections[?Type==`LINE`].DetectedText' \
    --output text)

echo "-----------------------------"
echo "Detected Text: $TEXT"
echo "-----------------------------"

# sentiment analysis
echo "Performing sentiment analysis on detected text..."
sentiment=$(aws comprehend detect-sentiment \
    --text "$TEXT" \
    --language-code en \
    --query 'Sentiment' \
    --output text)

echo "-----------------------------"
echo "Sentiment: $sentiment"
echo "-----------------------------"

#generate speech from text
echo "Generating speech from detected text..."
OUTPUT_FILE="${IMAGE_NAME%.*}.mp3"

aws polly synthesize-speech \
    --text "$TEXT" \
    --output-format mp3 \
    --voice-id Joanna \
    --region "$REGION" \
    "$OUTPUT_FILE"

echo "Speech generated and saved as output.mp3"
