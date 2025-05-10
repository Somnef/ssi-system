from fastapi import APIRouter, HTTPException
import requests
from utils.agent_control import load_env

router = APIRouter()

@router.post("/send-invitation-to/{student_username}")
def send_invitation(student_username: str):
    pass
