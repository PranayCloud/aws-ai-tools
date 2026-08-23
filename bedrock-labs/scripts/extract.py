import json
from pathlib import Path

base_dir = Path(__file__).resolve().parent.parent
output_dir = base_dir / "output"
output_path = output_dir / "output.json"
final_path = output_dir / "final-response.txt"

with output_path.open("r", encoding="utf-8") as file:
    data = json.load(file)

text = data["output"]["message"]["content"][0]["text"]
print(text)

final_path.write_text(text, encoding="utf-8")
print(f"\n✅ Final response saved to {final_path}")