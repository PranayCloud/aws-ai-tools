aws rekognition detect-labels \
  --image '{"S3Object":{"Bucket":"ai-practioner-labs-data-bucket","Name":"public-place.jfif"}}' \
  --max-labels 10 \
  --region us-east-1 \
  --output text


aws rekognition detect-text \
  --image '{"S3Object":{"Bucket":"ai-practioner-labs-data-bucket","Name":"images.jfif"}}' \
  --query 'TextDetections[?Type==`LINE`].DetectedText' \
  --output text \
  --region us-east-1