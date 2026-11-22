import pandas as pd
from sqlalchemy import text
from db import get_engine

engine = get_engine()

# 1. create tables
with open("sql/schema.sql", encoding="utf-8") as f:
    statements = [s.strip() for s in f.read().split(";") if s.strip()]
with engine.begin() as conn:
    for s in statements:
        conn.execute(text(s))
print("Tables created")

jobs = pd.read_csv("data/clean/jobs_clean.csv")
job_skills = pd.read_csv("data/clean/job_skills.csv")
jobs["posted_date"] = pd.to_datetime(jobs["posted_date"], errors="coerce")

# 2. companies
jobs["company_key"] = jobs["company"].str.lower().str.strip()
companies = (jobs.drop_duplicates("company_key")[["company"]]
                 .rename(columns={"company": "name"}))
companies.to_sql("companies", engine, if_exists="append", index=False)

cmap = pd.read_sql("SELECT company_id, name FROM companies", engine)
cmap["company_key"] = cmap["name"].str.lower().str.strip()
jobs = jobs.merge(cmap[["company_id", "company_key"]], on="company_key", how="left")

# 3. jobs
cols = ["job_id", "job_code", "title", "role_group", "company_id", "company_type",
        "industry", "city", "location_tier", "work_mode", "job_type",
        "experience_level", "exp_min", "exp_max", "is_fresher", "education",
        "salary_lpa", "openings", "applicants", "company_rating", "posted_date"]
jobs[cols].to_sql("jobs", engine, if_exists="append", index=False, chunksize=1000)

# 4. skills + job_skills
skills = pd.DataFrame({"skill_name": job_skills["skill"].unique()})
skills.to_sql("skills", engine, if_exists="append", index=False)

smap = pd.read_sql("SELECT skill_id, skill_name FROM skills", engine)
js = job_skills.merge(smap, left_on="skill", right_on="skill_name")[["job_id", "skill_id"]]
js.drop_duplicates().to_sql("job_skills", engine, if_exists="append", index=False, chunksize=1000)

# 5. verify
with engine.connect() as conn:
    for t in ["companies", "jobs", "skills", "job_skills"]:
        print(f"{t:12s}", conn.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar())