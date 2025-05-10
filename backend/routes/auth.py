from fastapi import APIRouter, HTTPException, Response, Depends, Request
from jose import jwt, JWTError
from datetime import datetime, timedelta
from pydantic import BaseModel
from utils.user_store import get_users_db, pwd_context
from config import SECRET_KEY, ALGORITHM

router = APIRouter()
users = get_users_db()

class LoginForm(BaseModel):
    username: str
    password: str

@router.post("/login")
def login(data: LoginForm, response: Response):
    user = users.get_user_by_username(data.username)
    if not user or not pwd_context.verify(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = jwt.encode({
        "sub": user["username"],
        "role": user["role"],
        "exp": datetime.utcnow() + timedelta(days=7)
    }, SECRET_KEY, algorithm=ALGORITHM)

    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        secure=False,
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
        user = users.get_user_by_username(payload["sub"])
        if not user:
            raise HTTPException(status_code=401, detail="Invalid user")
        
        user.pop("_id", None)
        return {**user, "username": payload["sub"]}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

@router.get("/me")
def me(user=Depends(get_current_user)):
    return user

@router.post("/logout")
def logout(response: Response):
    response.delete_cookie(key="access_token")
    return {"message": "Logged out successfully"}
