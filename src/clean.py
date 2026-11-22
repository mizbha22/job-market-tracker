import re
import pandas as pd

# ============ SETTINGS ============
RAW_FILE = "data/raw/india_job_market_2024_2026.csv"
ENCODING = "utf-8"

df = pd.read_csv(RAW_FILE, encoding=ENCODING, low_memory=False)
df.columns = [c.strip() for c in df.columns]
df = df.drop_duplicates(subset="Job_ID").reset_index(drop=True)
print("Raw rows:", len(df))

# ============ HELPERS ============
CITY_MAP = {
    "bangalore": "Bengaluru", "bengaluru": "Bengaluru",
    "bombay": "Mumbai", "gurgaon": "Gurugram",
    "new delhi": "Delhi", "madras": "Chennai", "calcutta": "Kolkata",
}

def clean_city(v):
    t = str(v).strip().lower()
    if not t or t == "nan":
        return "Unknown"
    return CITY_MAP.get(t, t.title())

def parse_exp(val):
    t = str(val).lower()
    nums = [float(x) for x in re.findall(r"\d+\.?\d*", t)]
    if nums:
        return (nums[0], nums[1] if len(nums) > 1 else nums[0])
    if re.search(r"fresher|entry|intern|trainee", t):
        return (0.0, 1.0)
    return (None, None)

def role_group(title):
    t = str(title).lower()
    if re.search(r"data engineer|etl|big data|analytics engineer|data platform|data architect|dataops", t):
        return "Data Engineer"
    if re.search(r"data scien|machine learning|\bml\b|\bai\b|deep learning|\bnlp\b|computer vision|mlops|research scientist", t):
        return "Data Scientist / ML"
    if re.search(r"analyst|analytics|\bbi\b|business intelligence|reporting", t):
        return "Analyst"
    return "Other Tech"

def is_fresher(level, exp_min):
    t = str(level).lower()
    if re.search(r"fresher|entry|intern|trainee|graduate", t):
        return 1
    return 1 if (pd.notna(exp_min) and exp_min == 0) else 0

# ============ BUILD CLEAN TABLE ============
out = pd.DataFrame()
out["job_id"] = df.index + 1
out["job_code"] = df["Job_ID"].astype(str).str.strip()
out["title"] = df["Job_Title"].astype(str).str.strip()
out["role_group"] = out["title"].apply(role_group)
out["company"] = df["Company"].astype(str).str.strip()
out["company_type"] = df["Company_Type"].astype(str).str.strip()
out["industry"] = df["Industry"].astype(str).str.strip()
out["city"] = df["City"].apply(clean_city)
out["location_tier"] = df["Location_Tier"].astype(str).str.strip()
out["work_mode"] = df["Work_Mode"].astype(str).str.strip()
out["job_type"] = df["Job_Type"].astype(str).str.strip()
out["experience_level"] = df["Experience_Level"].astype(str).str.strip()

exp = df["Experience_Level"].apply(parse_exp)
out["exp_min"] = [e[0] for e in exp]
out["exp_max"] = [e[1] for e in exp]
out["is_fresher"] = [is_fresher(l, m) for l, m in zip(out["experience_level"], out["exp_min"])]

out["education"] = df["Education_Required"].astype(str).str.strip()
out["salary_lpa"] = pd.to_numeric(df["Salary_LPA"], errors="coerce")
out["openings"] = pd.to_numeric(df["Openings"], errors="coerce").round().astype("Int64")
out["applicants"] = pd.to_numeric(df["Applicants"], errors="coerce").round().astype("Int64")
out["company_rating"] = pd.to_numeric(df["Company_Rating"], errors="coerce")
out["posted_date"] = pd.to_datetime(df["Date_Posted"], errors="coerce", dayfirst=True).dt.date

# ============ SKILLS: one row per job-skill pair ============
rows = []
for jid, s in zip(out["job_id"], df["Skills_Required"]):
    seen = set()
    for sk in str(s).split(","):
        sk = sk.strip().lower()
        if sk and sk != "nan" and sk not in seen:
            seen.add(sk)
            rows.append((jid, sk))
skills_df = pd.DataFrame(rows, columns=["job_id", "skill"])

out.to_csv("data/clean/jobs_clean.csv", index=False)
skills_df.to_csv("data/clean/job_skills.csv", index=False)

# ============ SUMMARY ============
print("\n========== CLEANING SUMMARY ==========")
print("Jobs:", len(out), "| Job-skill pairs:", len(skills_df), "| Unique skills:", skills_df["skill"].nunique())
print("\nRole groups:\n", out["role_group"].value_counts().to_string())
for c in ["experience_level", "company_type", "job_type", "work_mode", "location_tier"]:
    print(f"\n{c}:\n", out[c].value_counts().to_string())
print("\nTop cities:\n", out["city"].value_counts().head(8).to_string())
print("\nTop skills:\n", skills_df["skill"].value_counts().head(12).to_string())
print("\nSalary LPA:\n", out["salary_lpa"].describe().round(1).to_string())
print("\nFresher jobs:", out["is_fresher"].sum())
dates = pd.to_datetime(out["posted_date"])
print("Date range:", dates.min().date(), "to", dates.max().date())