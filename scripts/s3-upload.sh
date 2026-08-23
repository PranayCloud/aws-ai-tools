#!/bin/bash

# Usage: ./s3-upload.sh <file_path> <bucket_name> [s3_key]

FILE_PATH=$1
BUCKET_NAME=$2
S3_KEY=${3:-$(basename "$FILE_PATH")}

if [[ -z "$FILE_PATH" || -z "$BUCKET_NAME" ]]; then
  echo "Usage: $0 <file_path> <bucket_name> [s3_key]"
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File '$FILE_PATH' not found."
  exit 1
fi

aws s3 cp "$FILE_PATH" "s3://$BUCKET_NAME/$S3_KEY"
