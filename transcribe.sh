#!/bin/bash

# ==============================
# CONFIG
# ==============================
BUCKET_NAME="my-ai-bucket-for-practioner"
REGION="us-east-1"
AUDIO_PATH=$1

# ==============================
# VALIDATION
# ==============================
if [ -z "$AUDIO_PATH" ]; then
  echo "❌ Usage: ./transcribe.sh <audio-file>"
  exit 1
fi

if [ ! -f "$AUDIO_PATH" ]; then
  echo "❌ File not found: $AUDIO_PATH"
  exit 1
fi

# ==============================
# UNIQUE JOB NAME
# ==============================
JOB_NAME="transcribe-job-$(date +%s)"

echo "🚀 Job Name: $JOB_NAME"

# ==============================
# UPLOAD AUDIO
# ==============================
echo "📤 Uploading audio..."
aws s3 cp "$AUDIO_PATH" "s3://$BUCKET_NAME/audio/" > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Upload failed"
  exit 1
fi

# ==============================
# START TRANSCRIPTION
# ==============================
echo "🎙️ Starting transcription..."

aws transcribe start-transcription-job \
    --transcription-job-name "$JOB_NAME" \
    --language-code "en-US" \
    --media-format "mp3" \
    --media "MediaFileUri=s3://$BUCKET_NAME/audio/$(basename "$AUDIO_PATH")" \
    --output-bucket-name "$BUCKET_NAME" \
    --region "$REGION" > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Failed to start transcription"
  exit 1
fi

# ==============================
# WAIT FOR COMPLETION
# ==============================
echo -n "⏳ Processing"

while true; do
  STATUS=$(aws transcribe get-transcription-job \
    --transcription-job-name "$JOB_NAME" \
    --region "$REGION" \
    --query "TranscriptionJob.TranscriptionJobStatus" \
    --output text)

  if [ "$STATUS" == "COMPLETED" ]; then
    echo " ✅"
    break
  elif [ "$STATUS" == "FAILED" ]; then
    echo " ❌"
    echo "Transcription failed"
    exit 1
  fi

  echo -n "."
  sleep 3
done

# ==============================
# DOWNLOAD RESULT
# ==============================
echo "📥 Downloading transcript..."

aws s3 cp "s3://$BUCKET_NAME/$JOB_NAME.json" transcription_result.json > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Failed to download transcript"
  exit 1
fi

echo "✅ Transcript downloaded"

# ==============================
# EXTRACT TEXT (PYTHON)
# ==============================
echo "🧠 Extracting transcript..."

TRANSCRIPT=$(python -c "import json; print(json.load(open('transcription_result.json'))['results']['transcripts'][0]['transcript'])")

if [ -z "$TRANSCRIPT" ]; then
  echo "❌ Failed to extract transcript"
  exit 1
fi

echo "----------------------------------"
echo "📄 TRANSCRIPT:"
echo "$TRANSCRIPT"
echo "----------------------------------"

# ==============================
# SENTIMENT ANALYSIS
# ==============================
echo "🔍 Running sentiment analysis..."

SENTIMENT=$(aws comprehend detect-sentiment \
  --text "$TRANSCRIPT" \
  --language-code en \
  --region "$REGION" \
  --query "Sentiment" \
  --output text)

echo "🧠 Sentiment: $SENTIMENT"

# ==============================
# DECISION LOGIC
# ==============================
if [ "$SENTIMENT" == "NEGATIVE" ]; then
  MESSAGE="Customer is unhappy. Escalating to support team."
elif [ "$SENTIMENT" == "POSITIVE" ]; then
  MESSAGE="Customer is satisfied. Sending thank you message."
else
  MESSAGE="Customer sentiment is neutral. No action required."
fi

echo "💬 Decision: $MESSAGE"

echo "🔊 Converting decision to speech..."

aws polly synthesize-speech \
  --text "$MESSAGE" \
  --output-format mp3 \
  --voice-id Joanna \
  decision.mp3 \
  --region "$REGION" > /dev/null 2>&1