while IFS= read -r line
do
  echo "Review: $line"

  aws comprehend detect-sentiment \
    --text "$line" \
    --language-code en \
    --query 'Sentiment' \
    --output text

  echo "-----------------------------"
done < "./comprehend/reviews.txt"