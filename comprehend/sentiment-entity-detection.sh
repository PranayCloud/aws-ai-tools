#!/bin/bash

TEXT=$1

aws comprehend detect-entities \
    --text "$TEXT" \
    --language-code en \
    --query 'Entities[*].{Text:Text,Type:Type}' \
    --output table

aws comprehend detect-sentiment \
  --text "$TEXT" \
  --language-code en \
  --query '{Sentiment:Sentiment,Positive:SentimentScore.Positive,Neutral:SentimentScore.Neutral,Negative:SentimentScore.Negative,Mixed:SentimentScore.Mixed}' \
  --output table