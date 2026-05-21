#!/bin/bash
set -e

# Update and install dependencies
yum update -y
yum install -y python3 python3-pip git

# Install Python packages
pip3 install flask boto3

# Create app directory
mkdir -p /opt/nova-lite-app/templates

# Copy app files (populated by launch-ec2.sh via --user-data or SSM)
cat > /opt/nova-lite-app/app.py << 'APPEOF'
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
        return jsonify({"response": invoke_nova_lite(prompt)})
    except ClientError as e:
        code = e.response["Error"]["Code"]
        msg  = e.response["Error"]["Message"]
        return jsonify({"error": f"[{code}] {msg}"}), 500
    except BotoCoreError as e:
        return jsonify({"error": str(e)}), 500
    except KeyError as e:
        return jsonify({"error": f"Unexpected response structure: {e}"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
APPEOF

# Pull the HTML template from S3 or embed inline
# (Embedded here for self-contained deployment)
cat > /opt/nova-lite-app/templates/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Nova Lite AI</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&family=Orbitron:wght@700&display=swap" rel="stylesheet"/>
  <style>
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Inter',sans-serif;background:#0a0a0f;color:#e0e0e0;height:100vh;display:flex;flex-direction:column;overflow:hidden}
    header{text-align:center;padding:18px;background:linear-gradient(90deg,#0d0d1a,#1a0a2e,#0d0d1a);border-bottom:1px solid #2a1a4a}
    header h1{font-family:'Orbitron',sans-serif;font-size:1.6rem;background:linear-gradient(90deg,#a855f7,#38bdf8,#a855f7);background-size:200%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shimmer 3s infinite linear}
    header p{font-size:.78rem;color:#6b7280;margin-top:4px;letter-spacing:.05em}
    @keyframes shimmer{0%{background-position:0%}100%{background-position:200%}}
    .container{display:flex;flex:1;overflow:hidden}
    .panel{flex:1;display:flex;flex-direction:column;padding:24px;gap:14px;overflow:hidden}
    .panel-left{background:#0f0f1a;border-right:1px solid #1e1e3a}
    .panel-right{background:#0a0a14}
    .panel-label{font-size:.7rem;font-weight:600;letter-spacing:.15em;text-transform:uppercase;display:flex;align-items:center;gap:8px}
    .panel-left .panel-label{color:#a855f7}
    .panel-right .panel-label{color:#38bdf8}
    .panel-label::before{content:'';display:inline-block;width:8px;height:8px;border-radius:50%;animation:pulse 1.8s infinite}
    .panel-left .panel-label::before{background:#a855f7;box-shadow:0 0 8px #a855f7}
    .panel-right .panel-label::before{background:#38bdf8;box-shadow:0 0 8px #38bdf8}
    @keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.4;transform:scale(.8)}}
    textarea{flex:1;background:#13131f;border:1px solid #2a1a4a;border-radius:12px;color:#e0e0e0;font-family:'Inter',sans-serif;font-size:.95rem;line-height:1.6;padding:16px;resize:none;outline:none;transition:border-color .3s,box-shadow .3s}
    textarea:focus{border-color:#a855f7;box-shadow:0 0 0 3px rgba(168,85,247,.15)}
    textarea::placeholder{color:#3d3d5c}
    button{padding:13px;border:none;border-radius:12px;font-family:'Orbitron',sans-serif;font-size:.85rem;font-weight:700;letter-spacing:.08em;cursor:pointer;background:linear-gradient(135deg,#7c3aed,#2563eb);color:#fff;transition:opacity .2s,transform .1s,box-shadow .3s;box-shadow:0 4px 20px rgba(124,58,237,.4)}
    button:hover:not(:disabled){opacity:.9;transform:translateY(-1px);box-shadow:0 6px 28px rgba(124,58,237,.6)}
    button:disabled{opacity:.5;cursor:not-allowed}
    .response-box{flex:1;background:#13131f;border:1px solid #1a2a3a;border-radius:12px;padding:16px;overflow-y:auto;font-size:.95rem;line-height:1.7;color:#cbd5e1;white-space:pre-wrap;word-break:break-word;scrollbar-width:thin;scrollbar-color:#2a2a4a transparent}
    .response-box::-webkit-scrollbar{width:6px}
    .response-box::-webkit-scrollbar-thumb{background:#2a2a4a;border-radius:4px}
    .placeholder-text{color:#2a2a4a;font-style:italic;font-size:.9rem}
    .loader{display:none;align-items:center;gap:10px;color:#38bdf8;font-size:.82rem;letter-spacing:.05em}
    .loader.active{display:flex}
    .dots span{display:inline-block;width:7px;height:7px;border-radius:50%;background:#38bdf8;animation:bounce 1.2s infinite ease-in-out}
    .dots span:nth-child(2){animation-delay:.2s}
    .dots span:nth-child(3){animation-delay:.4s}
    @keyframes bounce{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
    .error-text{color:#f87171;font-size:.88rem}
    .divider{width:4px;background:linear-gradient(180deg,#7c3aed,#2563eb,#7c3aed);background-size:100% 200%;animation:flowDown 3s infinite linear;flex-shrink:0}
    @keyframes flowDown{0%{background-position:0% 0%}100%{background-position:0% 200%}}
    @media(max-width:700px){.container{flex-direction:column}.divider{width:100%;height:4px}.panel-left{border-right:none;border-bottom:1px solid #1e1e3a}}
  </style>
</head>
<body>
  <header>
    <h1>⚡ Amazon Nova Lite</h1>
    <p>Powered by Amazon Bedrock · AWS Generative AI</p>
  </header>
  <div class="container">
    <div class="panel panel-left">
      <div class="panel-label">Your Prompt</div>
      <textarea id="prompt" placeholder="Ask Nova Lite anything...&#10;&#10;e.g. Explain quantum computing in simple terms."></textarea>
      <button id="submitBtn" onclick="sendPrompt()">INVOKE NOVA LITE →</button>
    </div>
    <div class="divider"></div>
    <div class="panel panel-right">
      <div class="panel-label">AI Response</div>
      <div class="loader" id="loader"><div class="dots"><span></span><span></span><span></span></div>Generating response...</div>
      <div class="response-box" id="responseBox"><span class="placeholder-text">Your AI response will appear here...</span></div>
    </div>
  </div>
  <script>
    async function sendPrompt(){
      const prompt=document.getElementById("prompt").value.trim();
      const responseBox=document.getElementById("responseBox");
      const loader=document.getElementById("loader");
      const btn=document.getElementById("submitBtn");
      if(!prompt){responseBox.innerHTML='<span class="error-text">⚠ Please enter a prompt before submitting.</span>';return;}
      btn.disabled=true;responseBox.style.display="none";loader.classList.add("active");
      try{
        const res=await fetch("/invoke",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({prompt})});
        const data=await res.json();
        loader.classList.remove("active");responseBox.style.display="block";
        if(data.error){responseBox.innerHTML=`<span class="error-text">⚠ ${data.error}</span>`;}
        else{responseBox.textContent=data.response;}
      }catch(err){
        loader.classList.remove("active");responseBox.style.display="block";
        responseBox.innerHTML='<span class="error-text">⚠ Failed to connect to the server.</span>';
      }finally{btn.disabled=false;}
    }
    document.getElementById("prompt").addEventListener("keydown",(e)=>{if(e.ctrlKey&&e.key==="Enter")sendPrompt();});
  </script>
</body>
</html>
HTMLEOF

# Create systemd service to auto-start on reboot
cat > /etc/systemd/system/nova-lite.service << 'SVCEOF'
[Unit]
Description=Nova Lite Flask App
After=network.target

[Service]
WorkingDirectory=/opt/nova-lite-app
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable nova-lite
systemctl start nova-lite
