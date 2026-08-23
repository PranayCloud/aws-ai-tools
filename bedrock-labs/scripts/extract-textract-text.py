import json
from pathlib import Path

base_dir = Path(__file__).resolve().parent.parent
output_dir = base_dir / "output"
input_path = output_dir / "textract-output.json"
output_path = output_dir / "extracted-text.txt"

with input_path.open("r", encoding="utf-8") as file:
    data = json.load(file)

lines = [block["Text"] for block in data.get("Blocks", []) if block.get("BlockType") == "LINE"]
full_text = "\n".join(lines)

output_path.write_text(full_text, encoding="utf-8")
print(f"✅ Extracted text saved to {output_path}")