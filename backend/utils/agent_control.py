import os
import subprocess
from dotenv import dotenv_values
from fastapi import HTTPException

def spawn_agent(agent_name, http_port, admin_port):
    try:
        subprocess.run(
            ["../aries-agents/docker-approach/spawn_agent.sh", agent_name, http_port, admin_port],
            check=True
        )
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Agent spawn failed: {e}")

def register_did(agent_name):
    try:
        subprocess.run(
            ["../aries-agents/docker-approach/admin_register_did.sh", agent_name],
            check=True
        )
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Agent registration failed: {e}")

def load_env(agent_name):
    """
    Load environment variables from agent_envs/<agent_name>.env.

    Returns:
        dict: A dictionary of the loaded environment variables
    """
    
    # Assuming function is in ssi-project/backend/utils/agent_control.py
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))

    env_path = os.path.join(
        project_root,
        "aries-agents", "docker-approach", "agent_envs", f"{agent_name}.env"
    )

    if not os.path.isfile(env_path):
        raise FileNotFoundError(f"Env file not found for agent '{agent_name}' at {env_path}")

    config = dotenv_values(env_path)

    if "AGENT_HTTP_PORT" not in config or "AGENT_ADMIN_PORT" not in config:
        raise ValueError("Missing AGENT_HTTP_PORT or AGENT_ADMIN_PORT in env file")

    return {
        "http_port": config["AGENT_HTTP_PORT"],
        "admin_port": config["AGENT_ADMIN_PORT"]
    }
