from sqlalchemy import text
from db import get_engine

with get_engine().connect() as conn:
    print("Connected!", conn.execute(text("SELECT version()")).scalar())