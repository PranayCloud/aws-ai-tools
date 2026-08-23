import json
from pathlib import Path

base_dir = Path(__file__).resolve().parent.parent
output_dir = base_dir / "output"
input_dir = base_dir / "input"

with (output_dir / "extracted-text.txt").open("r", encoding="utf-8") as file:
    extracted_text = file.read()

payload = {
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "text": f"""
Summarize this invoice in simple language.

Please provide:
- Vendor name
- Invoice number
- Invoice date
- Total amount
- Important details

Also compare the individual item totals with the subtotal and verify whether they match correctly (have a look around Unit price & the chartged amount, if there is a diffrenct between unit price with qunatity and the amount, then highlight it.).

Invoice Text:
{extracted_text}
"""
                }
            ]
        }
    ],
    "inferenceConfig": {
        "max_new_tokens": 500,
        "temperature": 0.9
    }
}

input_dir.mkdir(parents=True, exist_ok=True)
request_path = input_dir / "bedrock-request.json"
with request_path.open("w", encoding="utf-8") as file:
    json.dump(payload, file, indent=2)

print(f"✅ Bedrock request JSON created at {request_path}")