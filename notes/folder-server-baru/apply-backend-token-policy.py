#!/usr/bin/env python3
"""
apply-backend-token-policy.py
Secures WSO2 APIM Gateway -> Micro Integrator communication by automatically
injecting the required backend X-API-Key token policy to all APIs and operations,
then deploying a new revision directly to the Gateway.
"""

import os
import sys
import json
import ssl
import urllib.request
import urllib.error
import base64

# Try to parse .env if present in current or script directory
env_candidates = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
    os.path.join(os.getcwd(), ".env")
]
for env_path in env_candidates:
    if os.path.isfile(env_path):
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip("'\"")
                        if k not in os.environ:
                            os.environ[k] = v
        except Exception:
            pass

APIM_HOST = os.environ.get("APIM_HOST", "https://localhost:9443")
APIM_USER = os.environ.get("APIM_USER", os.environ.get("APIM_ADMIN_USERNAME", "admindev"))
APIM_PASS = os.environ.get("APIM_PASS", os.environ.get("APIM_ADMIN_PASSWORD", "4554r3nt*2023"))
DEFAULT_VHOST = os.environ.get("APIM_VHOST", "devmiddleware.assa.id")
BACKEND_TOKEN = os.environ.get("BACKEND_TOKEN", "ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d")

ctx = ssl._create_unverified_context()
auth_header = "Basic " + base64.b64encode(f"{APIM_USER}:{APIM_PASS}".encode()).decode()

def api_request(path, data=None, method="GET"):
    url = f"{APIM_HOST}{path}"
    headers = {
        "Authorization": auth_header,
        "Accept": "application/json"
    }
    encoded_data = None
    if data is not None:
        headers["Content-Type"] = "application/json"
        encoded_data = json.dumps(data).encode("utf-8")
    
    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            content = resp.read().decode("utf-8")
            if content:
                return json.loads(content)
            return {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {e.code}: {body}") from e

def main():
    print("=" * 60)
    print("APPLYING BACKEND TOKEN POLICY TO ALL APIS IN APIM")
    print(f"APIM Host     : {APIM_HOST}")
    print(f"Backend Token : {BACKEND_TOKEN[:6]}...{BACKEND_TOKEN[-6:]}")
    print("=" * 60)

    # 1. Dynamically discover the addHeader policy ID in this APIM instance
    try:
        policies_resp = api_request("/api/am/publisher/v4/operation-policies?limit=100")
        policy_list = policies_resp.get("list", [])
        policy_id = None
        for pol in policy_list:
            if pol.get("name") == "addHeader":
                policy_id = pol.get("id")
                break
        
        if not policy_id:
            print("ERROR: Could not find 'addHeader' policy in APIM operation-policies.", file=sys.stderr)
            sys.exit(1)
        print(f"Discovered 'addHeader' Policy ID: {policy_id}")
    except Exception as e:
        print(f"ERROR querying policies: {e}", file=sys.stderr)
        sys.exit(1)

    # 2. Get all APIs
    try:
        apis_resp = api_request("/api/am/publisher/v4/apis?limit=50")
        apis = apis_resp.get("list", [])
    except Exception as e:
        print(f"ERROR querying APIs: {e}", file=sys.stderr)
        sys.exit(1)

    if not apis:
        print("No APIs found in APIM. Please run ./import-all-apis.sh first.", file=sys.stderr)
        sys.exit(1)

    success_count = 0
    for item in apis:
        api_id = item["id"]
        name = item["name"]

        try:
            # A. Fetch full API details
            api = api_request(f"/api/am/publisher/v4/apis/{api_id}")

            # B. Add 'addHeader' policy to all operations on Request Flow (both Authorization & X-API-Key)
            operations = api.get("operations", [])
            for op in operations:
                op["operationPolicies"] = {
                    "request": [
                        {
                            "policyName": "addHeader",
                            "policyVersion": "v2",
                            "policyId": policy_id,
                            "parameters": {
                                "headerName": "Authorization",
                                "headerValue": f"Bearer {BACKEND_TOKEN}"
                            }
                        },
                        {
                            "policyName": "addHeader",
                            "policyVersion": "v2",
                            "policyId": policy_id,
                            "parameters": {
                                "headerName": "X-API-Key",
                                "headerValue": BACKEND_TOKEN
                            }
                        }
                    ],
                    "response": [],
                    "fault": []
                }

            # C. Update API definition
            api_request(f"/api/am/publisher/v4/apis/{api_id}", data=api, method="PUT")

            # D. Get existing revisions to discover deployed vhost
            revs_list = api_request(f"/api/am/publisher/v4/apis/{api_id}/revisions")
            existing_revs = revs_list.get("list", [])
            target_vhost = DEFAULT_VHOST
            for r in existing_revs:
                for dep in r.get("deploymentInfo", []):
                    if dep.get("vhost"):
                        target_vhost = dep["vhost"]
                        break

            # E. If 5 revisions exist, delete the oldest undeployed revision to free up slot
            if len(existing_revs) >= 5:
                for r in existing_revs:
                    if not r.get("deploymentInfo"):
                        try:
                            api_request(f"/api/am/publisher/v4/apis/{api_id}/revisions/{r['id']}", method="DELETE")
                            break
                        except Exception:
                            pass

            # F. Create a new revision
            rev_resp = api_request(
                f"/api/am/publisher/v4/apis/{api_id}/revisions",
                data={"description": "Backend Dual Auth Token Policy Auto-Injected"},
                method="POST"
            )
            rev_id = rev_resp.get("id")

            # G. Deploy revision to Gateway with active vhost
            deploy_payload = [
                {
                    "name": "Default",
                    "vhost": target_vhost,
                    "displayOnDevportal": True
                }
            ]
            api_request(
                f"/api/am/publisher/v4/apis/{api_id}/deploy-revision?revisionId={rev_id}",
                data=deploy_payload,
                method="POST"
            )

            print(f"[OK] {name:<22} -> Dual auth policy applied & Revision {rev_id[:8]} active on {target_vhost}")
            success_count += 1
        except Exception as e:
            print(f"[FAIL] {name:<22} -> {e}", file=sys.stderr)

    print("=" * 60)
    print(f"Completed! {success_count}/{len(apis)} APIs successfully updated and active in Gateway.")
    print("Now Try Out on Swagger UI in Publisher will return 200 OK!")
    print("=" * 60)

if __name__ == "__main__":
    main()
