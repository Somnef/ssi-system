from fastapi import APIRouter, UploadFile, Form, Depends, HTTPException
from pydantic import BaseModel
from routes.auth import get_current_user
from utils.user_store import get_users_db, get_requests_db
from utils.agent_control import spawn_agent, register_did
import os


router = APIRouter()

class ApproveRequestInput(BaseModel):
    username: str

@router.post("/request-agent")
def request_agent(role: str = Form(...), file: UploadFile = Form(...), user=Depends(get_current_user)):
    if user["role"] == "admin":
        raise HTTPException(status_code=403, detail="Admins cannot request agents")
    
    username = user["username"]
    
    requests_db = get_requests_db()
    
    if requests_db.get_request_by_username(username):
        raise HTTPException(status_code=400, detail="Already requested")

    # Assuming function in ssi-project/backend/routes/request.py
    os.makedirs("../uploads", exist_ok=True)
    path = f"uploads/{username}_{file.filename.replace(' ', '_')}" # type: ignore
    with open(path, "wb") as f_out:
        f_out.write(file.file.read())
        
    requests_db.create_request({
        "username": username,
        "role": role,
        "filename": path,
        "status": "pending"
    })
    
    users = get_users_db()
    users.update_user(username, {"has_requested": "True"})
    
    return {"message": "Request submitted successfully"}


