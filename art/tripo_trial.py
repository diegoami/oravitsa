"""One prepaid Tripo reconstruction; default is an offline plan, not a charge.

python art/tripo_trial.py             # inspect plan, no network/key required
python art/tripo_trial.py --balance   # read available API credits
python art/tripo_trial.py --submit    # one generation, then poll/download
python art/tripo_trial.py --resume    # poll saved task; never create another
"""
import argparse
import hashlib
import json
import os
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
API="https://openapi.tripo3d.ai/v3"
MODEL="v3.1-20260211"
EXPECTED_CREDITS=30


def api_key(name="TRIPO_API_KEY",setup="Set-TripoApiKey.ps1"):
    key=os.environ.get(name, "").strip()
    if not key and os.name=="nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,"Environment") as registry:
                key=winreg.QueryValueEx(registry,name)[0].strip()
        except FileNotFoundError:
            pass
    if not key:
        raise RuntimeError(f"No {name} configured. Run art/{setup} locally; do not paste the key into chat.")
    return key


def save(path, value):
    path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")


class Client:
    def __init__(self,key): self.key=key

    def request(self,path,payload=None,content_type="application/json"):
        body=json.dumps(payload).encode() if isinstance(payload,dict) else payload
        request=urllib.request.Request(API+path,data=body,headers={"Authorization":"Bearer "+self.key,"Content-Type":content_type})
        # In particular, never automatically retry a paid POST after a timeout.
        try:
            with urllib.request.urlopen(request,timeout=90) as response:
                result=json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"Tripo HTTP {error.code}; request was not retried.") from None
        if result.get("code")!=0:
            raise RuntimeError(f"Tripo API error {result.get('code')}: {result.get('message','request failed')}")
        return result["data"]

    def upload(self,path):
        boundary="tripo-"+uuid.uuid4().hex
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="source.png"\r\nContent-Type: image/png\r\n\r\n'.encode()+path.read_bytes()+f"\r\n--{boundary}--\r\n".encode())
        return self.request("/files",data,"multipart/form-data; boundary="+boundary)["file_token"]


def plan(source):
    if not source.is_file():
        raise RuntimeError("Prepare the current sprite with: godot --headless --path . --script art/prepare_tripo_reference.gd")
    if source.stat().st_size>20*1024*1024:
        raise RuntimeError("Reference exceeds the documented 20 MB upload limit.")
    return {"source":str(source),"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"expected_credits":EXPECTED_CREDITS,"estimated_usd":.30,"stage":"Static likeness trial only; no rigging, retargeting or variations","endpoint":API+"/generation/image-to-model","request":{"input":"<file_token from source.png upload>","model":MODEL,"texture":True,"pbr":False,"texture_quality":"standard","geometry_quality":"standard","texture_alignment":"original_image","orientation":"align_image","enable_image_autofix":False,"model_seed":2401024,"texture_seed":2401024}}


def submit_once(client,source,output,proposal):
    state_path=output/"submission.json"
    if state_path.exists():
        state=json.loads(state_path.read_text(encoding="utf-8"))
        if state.get("source_sha256")!=proposal["source_sha256"]:
            raise RuntimeError("The reference differs from the saved submission. Use its original reference or a separate trial directory.")
        if state.get("task_id"):
            print("Existing task found; resuming without another generation.")
            return state["task_id"]
        raise RuntimeError("A submission intent already exists without a task ID. Reconcile Tripo task history before another submission; automatic resubmission is blocked.")
    balance=client.request("/account/balance")
    if float(balance["balance"])<EXPECTED_CREDITS:
        raise RuntimeError(f"Need {EXPECTED_CREDITS} API credits; available: {balance['balance']}. No reference was uploaded and no task was created.")
    token=client.upload(source)
    payload={**proposal["request"],"input":token}
    # Exclusive creation is also a cross-process guard against double submission.
    with state_path.open("x",encoding="utf-8") as file:
        json.dump({"status":"submitting","source_sha256":proposal["source_sha256"],"created_at_unix":time.time()},file)
    result=client.request("/generation/image-to-model",payload)
    state={"task_id":result["task_id"],"source_sha256":proposal["source_sha256"],"status":"submitted"}
    save(state_path,state)
    print("Created one Tripo reconstruction task: "+state["task_id"])
    return state["task_id"]


def collect(client,task_id,output,wait_seconds=900):
    deadline=time.monotonic()+wait_seconds
    previous=None
    while True:
        result=client.request("/tasks/"+task_id)
        save(output/"task-result.json",result)
        status=result.get("status")
        marker=(status,result.get("progress"))
        if marker!=previous:
            print(f"Tripo: {status}, progress {result.get('progress','?')}%",flush=True)
            previous=marker
        if status=="success": break
        if status in ("failed","cancelled"):
            raise RuntimeError(f"Task {status}: {result.get('error_message','see task-result.json')}. No new task will be submitted.")
        if time.monotonic()>=deadline:
            raise RuntimeError("Polling deadline reached. Use --resume; do not submit another generation.")
        time.sleep(3)
    url=result.get("output",{}).get("model_url")
    if not isinstance(url,str) or not url.startswith("https://"):
        raise RuntimeError("No HTTPS model_url returned; inspect task-result.json. The existing task is saved.")
    # Download without forwarding the Tripo authorization header to the CDN.
    target=output/"candidate.glb"
    with urllib.request.urlopen(url,timeout=180) as response, target.open("wb") as file:
        while chunk:=response.read(1024*1024): file.write(chunk)
    if target.read_bytes()[:4]!=b"glTF":
        raise RuntimeError("Downloaded output is not GLB; inspect the response before importing it.")
    print(f"Saved {target}; consumed credits: {result.get('credits_consumed','not returned')}")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    action=parser.add_mutually_exclusive_group()
    action.add_argument("--balance",action="store_true")
    action.add_argument("--submit",action="store_true")
    action.add_argument("--resume",action="store_true")
    parser.add_argument("--output",type=Path,default=ROOT/"build/tripo-trial")
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    if args.balance:
        print(json.dumps(Client(api_key()).request("/account/balance"),indent=2));return
    if args.resume:
        state=json.loads((output/"submission.json").read_text(encoding="utf-8"))
        collect(Client(api_key()),state["task_id"],output);return
    proposal=plan(output/"source.png")
    save(output/"plan.json",proposal)
    if not args.submit:
        print(json.dumps(proposal,indent=2));return
    client=Client(api_key())
    task_id=submit_once(client,output/"source.png",output,proposal)
    collect(client,task_id,output)


if __name__=="__main__":
    try: main()
    except (RuntimeError,OSError,KeyError) as error:
        raise SystemExit(str(error)) from None
