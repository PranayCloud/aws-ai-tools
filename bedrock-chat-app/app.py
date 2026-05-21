from flask import Flask, render_template, request, jsonify
import boto3
import json
from botocore.exceptions import BotoCoreError, ClientError

app = Flask(__name__)

MODEL_ID = "amazon.nova-lite-v1:0"
client = boto3.client("bedrock-runtime", region_name="us-east-1")


def invoke_nova_lite(prompt: str) -> str:
    request_body = {
        "messages": [{"role": "user", "content": [{"text": prompt}]}],
        "inferenceConfig": {"maxTokens": 1024, "temperature": 0.7}
    }
    response = client.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(request_body)
    )
    response_body = json.loads(response["body"].read())
    return response_body["output"]["message"]["content"][0]["text"]


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/invoke", methods=["POST"])
def invoke():
    data = request.get_json()
    prompt = data.get("prompt", "").strip()

    if not prompt:
        return jsonify({"error": "Prompt cannot be empty."}), 400

    try:
        response_text = invoke_nova_lite(prompt)
        return jsonify({"response": response_text})

    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        error_message = e.response["Error"]["Message"]
        return jsonify({"error": f"[{error_code}] {error_message}"}), 500

    except BotoCoreError as e:
        return jsonify({"error": str(e)}), 500

    except KeyError as e:
        return jsonify({"error": f"Unexpected response structure: {e}"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
