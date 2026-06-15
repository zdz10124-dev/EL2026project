from __future__ import annotations

import uuid
from datetime import datetime, timedelta

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from database import get_connection
from schemas import UserLogin, UserRegister
from settings import JWT_ALGORITHM, JWT_EXPIRE_HOURS, JWT_SECRET, LOCAL_TIMEZONE
from utils import now_iso

router = APIRouter(prefix="/v1/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def check_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode(), password_hash.encode())


def create_token(user_id: str, username: str) -> str:
    payload = {
        "user_id": user_id,
        "username": username,
        "exp": datetime.now(LOCAL_TIMEZONE) + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict:
    if credentials is None:
        raise HTTPException(status_code=401, detail="未登录")
    try:
        payload = jwt.decode(
            credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM]
        )
        return {"user_id": payload["user_id"], "username": payload["username"]}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="无效的登录凭证")


@router.post("/register")
def register(payload: UserRegister) -> dict:
    username = payload.username.strip()
    if not username:
        raise HTTPException(status_code=400, detail="用户名不能为空")

    password_hash = hash_password(payload.password)
    user_id = f"user_{uuid.uuid4().hex}"
    now = now_iso()

    with get_connection() as connection:
        existing = connection.execute(
            "SELECT id FROM users WHERE username = ?", (username,)
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="用户名已存在")
        connection.execute(
            "INSERT INTO users(id, username, password_hash, created_at) VALUES(?, ?, ?, ?)",
            (user_id, username, password_hash, now),
        )

    token = create_token(user_id, username)
    return {
        "success": True,
        "message": "注册成功",
        "data": {"user_id": user_id, "username": username, "token": token},
    }


@router.post("/login")
def login(payload: UserLogin) -> dict:
    username = payload.username.strip()
    with get_connection() as connection:
        row = connection.execute(
            "SELECT id, username, password_hash FROM users WHERE username = ?",
            (username,),
        ).fetchone()

    if row is None or not check_password(payload.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    token = create_token(row["id"], row["username"])
    return {
        "success": True,
        "message": "登录成功",
        "data": {
            "user_id": row["id"],
            "username": row["username"],
            "token": token,
        },
    }


@router.get("/me")
def auth_me(user: dict = Depends(get_current_user)) -> dict:
    return {"success": True, "data": user}
