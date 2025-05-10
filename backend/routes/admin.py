from fastapi import APIRouter, UploadFile, Form, Depends, HTTPException
from pydantic import BaseModel
from routes.auth import get_current_user
from utils.user_store import get_users_db, get_requests_db
from utils.agent_control import spawn_agent, register_did
from utils.utils import next_free_port
import os

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