import pandas as pd

FILE = "data/raw/india_job_market_2024_2026.csv"
df = pd.read_csv(FILE, encoding="utf-8", on_bad_lines="skip", low_memory=False)

print("SHAPE:", df.shape)
print("\nCOLUMNS:\n", list(df.columns))
print("\nNULL COUNT:\n", df.isnull().sum())
for col in df.columns[:12]:
    print(f"\n{col}:", df[col].dropna().astype(str).head(3).tolist())