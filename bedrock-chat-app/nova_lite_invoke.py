import boto3
import json
import sys
from botocore.exceptions import BotoCoreError, ClientError

MODEL_ID = "amazon.nova-lite-v1:0"

def invoke_nova_lite(prompt: str) -> str:
    client = boto3.client("bedrock-runtime", region_name="us-east-1")

    request_body = {
        "messages": [
            {
                "role": "user",
                "content": [{"text": prompt}]
            }
        ],
        "inferenceConfig": {
            "maxTokens": 1024,
            "temperature": 0.7
        }
    }

    response = client.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(request_body)
    )

    response_body = json.loads(response["body"].read())
    return response_body["output"]["message"]["content"][0]["text"]


def main():
    prompt = input("Enter your prompt: ").strip()
    if not prompt:
        print("Error: Prompt cannot be empty.")
        sys.exit(1)

    print("\nInvoking Amazon Nova Lite...\n")

    try:
        response_text = invoke_nova_lite(prompt)
        print("AI Response:\n")
        print(response_text)

    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        error_message = e.response["Error"]["Message"]
        print(f"AWS ClientError [{error_code}]: {error_message}", file=sys.stderr)
        sys.exit(1)

    except BotoCoreError as e:
        print(f"BotoCoreError: {e}", file=sys.stderr)
        sys.exit(1)

    except KeyError as e:
        print(f"Unexpected response structure, missing key: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
