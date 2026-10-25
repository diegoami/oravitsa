"""One Tripo H3.1 reconstruction through fal's prepaid API.

Default: offline plan. --submit: one paid request, then poll/download.
--resume: poll the saved request; never create another generation.
"""
import argparse
import base64
import hashlib
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from tripo_trial import api_key,save

ROOT=Path(__file__).resolve().parents[1]
ENDPOINT="https://queue.fal.run/tripo3d/h3.1/image-to-3d"


class Fal:
    def __init__(self,key): self.key=key
    def request(self,url,payload=None):
        if urllib.parse.urlsplit(url).hostname!="queue.fal.run":
            raise RuntimeError("Refusing to send fal credentials to an unexpected host.")
        request=urllib.request.Request(url,data=json.dumps(payload).encode() if payload is not None else None,headers={"Authorization":"Key "+self.key,"Content-Type":"application/json"})
        try:
            with urllib.request.urlopen(request,timeout=120) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"fal HTTP {error.code}. The request was not retried.") from None


def make_plan(source):
    if not source.is_file(): raise RuntimeError("Prepare source.png with art/prepare_tripo_reference.gd first.")
    return {"provider":"fal.ai","model":"tripo3d/h3.1/image-to-3d","estimated_usd":0.30,"stage":"One static likeness candidate only","source":str(source),"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"request":{"image_url":"<data URI of source.png>","texture":True,"pbr":False,"texture_quality":"standard","geometry_quality":"standard","texture_alignment":"original_image","orientation":"align_image","model_seed":2401024,"texture_seed":2401024}}


def submit_payload_once(client,endpoint,payload,output,fingerprint):
    state_path=output/"submission.json"
    if state_path.exists():
        state=json.loads(state_path.read_text(encoding="utf-8"))
        if state.get("source_sha256")!=fingerprint:
            raise RuntimeError("Reference differs from the saved request; do not reuse this trial directory.")
        if state.get("request_id"):
            print("Resuming the saved fal request; no new generation.")
            return state
        raise RuntimeError("A submission intent exists without a request ID. Reconcile fal request history before another paid call.")
    with state_path.open("x",encoding="utf-8") as file:
        json.dump({"status":"submitting","source_sha256":fingerprint,"created_at_unix":time.time()},file)
    result=client.request(endpoint,payload)
    if not result.get("request_id") or not result.get("status_url") or not result.get("response_url"):
        raise RuntimeError("Unexpected fal submission response; the intent remains saved to prevent duplicate charging.")
    state={**result,"source_sha256":fingerprint}
    save(state_path,state)
    print("One fal request accepted: "+state["request_id"],flush=True)
    return state


def submit_once(client,source,output,plan):
    payload={**plan["request"],"image_url":"data:image/png;base64,"+base64.b64encode(source.read_bytes()).decode()}
    return submit_payload_once(client,ENDPOINT,payload,output,plan["source_sha256"])


def collect(client,state,output,wait_seconds=1200):
    deadline=time.monotonic()+wait_seconds
    previous=None
    while True:
        result=client.request(state["status_url"])
        save(output/"status.json",result)
        status=result.get("status")
        if status!=previous:
            print("fal status: "+str(status),flush=True);previous=status
        if status=="COMPLETED": break
        if status in ("FAILED","CANCELLED"):
            raise RuntimeError("fal request "+status+"; no new request was submitted.")
        if time.monotonic()>=deadline:
            raise RuntimeError("Polling deadline reached. Continue with --resume, which creates no new generation.")
        time.sleep(3)
    result=client.request(state["response_url"])
    save(output/"result.json",result)
    if os.name=="nt":
        # Use the native Windows trust store for CDN downloads, keeping TLS
        # verification enabled. Credentials are never passed to this process.
        subprocess.run(["powershell.exe","-NoProfile","-NonInteractive","-File",str(ROOT/"art/Download-FalCandidate.ps1"),"-Output",str(output)],check=True,creationflags=subprocess.CREATE_NO_WINDOW)
        print("Saved reconstruction: "+str(output/"candidate.glb"),flush=True)
        return
    models=result.get("model_urls",{})
    model=models.get("glb") or result.get("model_mesh")
    if not isinstance(model,dict) or not str(model.get("url","")).startswith("https://"):
        raise RuntimeError("No downloadable model returned; inspect result.json.")
    target=output/"candidate.glb"
    with urllib.request.urlopen(model["url"],timeout=180) as response,target.open("wb") as file:
        while chunk:=response.read(1024*1024): file.write(chunk)
    with target.open("rb") as file: magic=file.read(4)
    if magic!=b"glTF": raise RuntimeError("Downloaded model is not GLB; retain it for inspection.")
    print("Saved reconstruction: "+str(target),flush=True)
    preview=result.get("rendered_image")
    if isinstance(preview,dict) and str(preview.get("url","")).startswith("https://"):
        with urllib.request.urlopen(preview["url"],timeout=90) as response:
            (output/"provider-preview.png").write_bytes(response.read())


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    action=parser.add_mutually_exclusive_group()
    action.add_argument("--submit",action="store_true")
    action.add_argument("--resume",action="store_true")
    parser.add_argument("--output",type=Path,default=ROOT/"build/fal-tripo-trial")
    parser.add_argument("--source",type=Path,default=ROOT/"build/tripo-trial/source.png")
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    if args.resume:
        state=json.loads((output/"submission.json").read_text(encoding="utf-8"))
        collect(Fal(api_key("FAL_KEY","Set-FalApiKey.ps1")),state,output);return
    plan=make_plan(args.source.resolve());save(output/"plan.json",plan)
    if not args.submit:
        print(json.dumps(plan,indent=2));return
    client=Fal(api_key("FAL_KEY","Set-FalApiKey.ps1"))
    state=submit_once(client,args.source,output,plan)
    collect(client,state,output)


if __name__=="__main__":
    try: main()
    except (RuntimeError,OSError,KeyError) as error:
        raise SystemExit(str(error)) from None
