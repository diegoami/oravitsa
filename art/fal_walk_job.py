"""One fal Meshy rigging request on the approved Tripo mesh, with basic walk."""
import argparse
import base64
import hashlib
import json
import subprocess
import time
from pathlib import Path
from fal_tripo_trial import Fal,submit_payload_once
from tripo_trial import api_key,save

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"build/fal-walk"
ENDPOINT="https://queue.fal.run/fal-ai/meshy/rigging"


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    action=parser.add_mutually_exclusive_group()
    action.add_argument("--submit",action="store_true")
    action.add_argument("--resume",action="store_true")
    args=parser.parse_args()
    source=OUTPUT/"rig-input.glb"
    params={"height_meters":1.5,"enable_animation":False,"enable_safety_checker":True}
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    fingerprint=hashlib.sha256((source_hash+json.dumps(params,sort_keys=True)+ENDPOINT).encode()).hexdigest()
    plan={"endpoint":ENDPOINT,"input":"rig-input.glb: approved Tripo reconstruction, texture-preserving decimation","input_sha256":source_hash,"estimated_usd":.20,"animation":"Basic walking clip included by the rigging endpoint; no extra animation preset requested","params":params}
    save(OUTPUT/"plan.json",plan)
    if not args.submit and not args.resume:
        print(json.dumps(plan,indent=2));return
    client=Fal(api_key("FAL_KEY","Set-FalApiKey.ps1"))
    if args.resume:
        state=json.loads((OUTPUT/"submission.json").read_text(encoding="utf-8"))
    else:
        payload={**params,"model_url":"data:model/gltf-binary;base64,"+base64.b64encode(source.read_bytes()).decode()}
        state=submit_payload_once(client,ENDPOINT,payload,OUTPUT,fingerprint)
    deadline=time.monotonic()+1800
    previous=None
    while True:
        result=client.request(state["status_url"])
        save(OUTPUT/"status.json",result)
        status=result.get("status")
        if status!=previous:
            print("Rigging status: "+str(status),flush=True);previous=status
        if status=="COMPLETED":break
        if status in ("FAILED","CANCELLED"):raise RuntimeError("Rigging failed; no automatic resubmission.")
        if time.monotonic()>deadline:raise RuntimeError("Rigging still pending; use --resume, not a new paid request.")
        time.sleep(4)
    result=client.request(state["response_url"])
    save(OUTPUT/"result.json",result)
    subprocess.run(["powershell.exe","-NoProfile","-NonInteractive","-File",str(ROOT/"art/Download-FalWalk.ps1")],check=True,creationflags=subprocess.CREATE_NO_WINDOW)


if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,KeyError) as error:raise SystemExit(str(error)) from None
