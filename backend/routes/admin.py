from fastapi import APIRouter, UploadFile, Form, Depends, HTTPException
from pydantic import BaseModel
from routes.auth import get_current_user
from utils.user_store import get_users_db, get_requests_db
from utils.agent_control import spawn_agent, register_did
from utils.utils import next_free_port
import os
import zipfile
import os
from pathlib import Path

AGENT_DIR = Path(__file__).resolve().parents[2] / "aries-agents" / "docker-approach"

def create_agent_bundle(agent_name: str) -> Path:
    bundle_path = AGENT_DIR / f"{agent_name}_bundle.zip"

    paths = {
        "env": AGENT_DIR / f"agent_envs/{agent_name}.env",
        "did": AGENT_DIR / f"agent_dids/{agent_name}_did.json",
        "wallet": AGENT_DIR / f"agent_wallets/{agent_name}",
        "scripts": [
            "accept_connection.sh",
            "accept_credential_offer.sh",
            "accept_proof_request.sh",
            "accept_proof_request_interactive.sh",
            "request_connection.sh",
            "request_cred_def_endorsement.sh",
            "request_proof.sh",
            "offer_credential.sh",
            "issue_credential.sh",
            "get_proof_credentials.sh"
        ]
    }

    with zipfile.ZipFile(bundle_path, 'w') as zipf:
        # Add env and DID
        zipf.write(paths["env"], arcname=paths["env"].name)
        zipf.write(paths["did"], arcname=paths["did"].name)

        # Add wallet folder
        for file in paths["wallet"].rglob("*"):
            rel_path = file.relative_to(AGENT_DIR)
            zipf.write(file, arcname=rel_path)

        # Add CLI scripts under /cli
        for script in paths["scripts"]:
            full_path = AGENT_DIR / script
            if full_path.exists():
                zipf.write(full_path, arcname=f"cli/{script}")

        # Add launcher script
        run_agent = AGENT_DIR / "run_agent.sh"
        if run_agent.exists():
            zipf.write(run_agent, arcname="run_agent.sh")

    return bundle_path


router = APIRouter()

HTTP_PORT_RANGE = [8000, 8100]
ADMIN_PORT_RANGE = [10000, 10100]

class ApproveRequestInput(BaseModel):
    username: str

@router.get("/requests")
def get_all_requests(user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    requests_db = get_requests_db()
    return requests_db.get_all_requests()

@router.post("/approve-request")
def approve_request(data: ApproveRequestInput, user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    requests_db = get_requests_db()
    request = requests_db.get_request_by_username(data.username)
    
    # print(f"[DEBUG] username: {data.username}")
    # print(f"[DEBUG] request['role']: {request['role']}")
    
    user_db = get_users_db()
    
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    if request["status"] != "pending":
        raise HTTPException(status_code=400, detail="Request already processed.")

    http_port = str(next_free_port(HTTP_PORT_RANGE[0], HTTP_PORT_RANGE[1]))
    admin_port = str(next_free_port(ADMIN_PORT_RANGE[0], ADMIN_PORT_RANGE[1]))

    spawn_agent(data.username, http_port, admin_port)
    register_did(data.username)
    
    requests_db.update_request(data.username, {"status": "approved"})
    user_db.update_user(data.username, {"role": request["role"], "has_requested": "True"})
    
    
    
    return {"message": f"Agent spawned and registered for {data.username}"}