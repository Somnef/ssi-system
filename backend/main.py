from fastapi import FastAPI, Depends, HTTPException, Response, Request, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from jose import jwt, JWTError
from passlib.context import CryptContext
from pydantic import BaseModel
from datetime import datetime, timedelta
import uvicorn
import os
import subprocess

app = FastAPI()

uploads_path = os.path.join(os.path.dirname(__file__), "uploads")
app.mount("/uploads", StaticFiles(directory=uploads_path), name="uploads")

origins = ["http://localhost:8080"]  # Vue dev server
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,  # 💡 Needed for cookie auth!
    allow_methods=["*"],
    allow_headers=["*"],
)

SECRET_KEY = "super-secret-key"
ALGORITHM = "HS256"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Dummy in-memory storage for requests
agent_requests = []

# Dummy database
fake_users = {
    "somnef": {
        "username": "somnef",
        "password": pwd_context.hash("test123"),  # Hashed password
        "role": "",
        "has_requested": False,
    },
    
    "admin": {
        "username": "admin",
        "password": pwd_context.hash("admin123"),  # Hashed password
        "role": "admin",
        "has_requested": False,
    },
}


class LoginForm(BaseModel):
    username: str
    password: str


@app.post("/login")
def login(data: LoginForm, response: Response):
    user = fake_users.get(data.username)
    if not user or not pwd_context.verify(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token_data = {
        "sub": user["username"],
        "role": user["role"],
        "exp": datetime.utcnow() + timedelta(days=7)
    }

    token = jwt.encode(token_data, SECRET_KEY, algorithm=ALGORITHM)
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        secure=False,  # Set to True in production (HTTPS only)
        samesite="strict",
        max_age=7 * 24 * 60 * 60,
    )

    return {"message": "Logged in successfully"}

def get_current_user(request: Request):
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        return {
            "username": payload.get("sub"),
            "role": payload.get("role"),
            "has_requested": fake_users.get(payload.get("sub"), {}).get("has_requested", False)
        }
        
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


@app.get("/me")
def me(user=Depends(get_current_user)):
    return user

@app.post("/logout")
def logout(response: Response):
    response.delete_cookie(key="access_token")
    return {"message": "Logged out successfully"}

# === /request-agent ===
@app.post("/request-agent")
def request_agent(
    role: str = Form(...),
    file: UploadFile = Form(...),
    user=Depends(get_current_user)
):
    username = user["username"]

    # Check if this user already submitted
    for r in agent_requests:
        if r["username"] == username:
            raise HTTPException(status_code=400, detail="Already requested")

    # Save the file
    os.makedirs("uploads", exist_ok=True)
    path = f"uploads/{username}_{file.filename.replace(' ', '_')}"
    with open(path, "wb") as f_out:
        f_out.write(file.file.read())

    # Save the request
    agent_requests.append({
        "username": username,
        "role": role,
        "filename": path,
        "status": "pending"
    })
    
    user["has_requested"] = True
    fake_users[username]['has_requested'] = True
    return {"message": "Request submitted successfully"}


@app.get("/admin/requests")
def get_all_requests(user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    return agent_requests


class ApproveRequestInput(BaseModel):
    username: str
    
@app.post("/admin/approve-request")
def approve_request(data: ApproveRequestInput, user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Access denied")

    # Find the pending request
    request_obj = next((r for r in agent_requests if r["username"] == data.username), None)
    if not request_obj:
        raise HTTPException(status_code=404, detail="Request not found")

    if request_obj["status"] != "pending":
        raise HTTPException(status_code=400, detail="Request already processed")

    # Assign ports (optional: you can automate this better later)
    http_port = "8020"
    admin_port = "8021"
    agent_name = data.username

    # Call spawn script (make sure it's executable!)
    try:
        subprocess.run(
            ["../aries-agents/docker-approach/spawn_agent.sh", agent_name, http_port, admin_port],
            check=True
        )
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Agent spawn failed: {e}")
    
    try:
        subprocess.run(
            ["../aries-agents/docker-approach/admin_register_did.sh", agent_name],
            check=True
        )
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Agent registration failed: {e}")

    # Update request status
    request_obj["status"] = "approved"
    
    fake_users[data.username]['role'] = request_obj["role"]
    return {"message": f"Request for {data.username} approved. Agent spawned and registered."}


