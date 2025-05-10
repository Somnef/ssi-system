import os
import pytest
from backend.utils.agent_control import load_env

@pytest.fixture
def env_dir(tmp_path):
    """Create a temporary mock agent_envs folder"""
    envs_path = tmp_path / "aries-agents" / "docker-approach" / "agent_envs"
    envs_path.mkdir(parents=True)
    return envs_path

def test_load_env_success(env_dir, monkeypatch):
    agent_name = "test-agent"
    env_file = env_dir / f"{agent_name}.env"

    # Write a mock .env file
    env_file.write_text("AGENT_HTTP_PORT=8081\nAGENT_ADMIN_PORT=8082")

    # Patch __file__ path to simulate real project layout
    fake_utils_path = env_dir.parent.parent / "backend" / "utils"
    fake_utils_path.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr("backend.utils.agent_control.__file__", str(fake_utils_path / "agent_control.py"))

    result = load_env(agent_name)
    assert result["http_port"] == "8081"
    assert result["admin_port"] == "8082"

def test_load_env_missing_file(monkeypatch):
    monkeypatch.setattr("backend.utils.agent_control.__file__", "/tmp/backend/utils/agent_control.py")
    with pytest.raises(FileNotFoundError):
        load_env("nonexistent-agent")

def test_load_env_missing_keys(env_dir, monkeypatch):
    agent_name = "test-agent"
    
    env_file = env_dir / f"{agent_name}.env"
    env_file.write_text("AGENT_HTTP_PORT=8020\n")  # Missing ADMIN port

    # Patch __file__ path to simulate real project layout
    fake_utils_path = env_dir.parent.parent / "backend" / "utils"
    fake_utils_path.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr("backend.utils.agent_control.__file__", str(fake_utils_path / "agent_control.py"))

    with pytest.raises(ValueError):
        load_env(agent_name)
