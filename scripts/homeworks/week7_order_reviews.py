import os
import pandas as pd
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[2]  #scripts/homeworks > root
load_dotenv(BASE_DIR / ".env")

data_dir = os.getenv("DATA_DIR")
output_dir = os.getenv("OUTPUT_DIR")
if not data_dir or not output_dir:
    raise RuntimeError("DATA_DIR and OUTPUT_DIR must be set in the .env file in the project root.")

DATA_DIR = BASE_DIR / data_dir
OUTPUT_DIR = BASE_DIR / output_dir / "raw_parquet"
if not OUTPUT_DIR.exists():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
TARGET = OUTPUT_DIR / "olist_order_reviews_dataset.parquet"

df = pd.read_csv(DATA_DIR / "olist_order_reviews_dataset.csv",
                      encoding="utf-8",
                      dtype={"review_id": "string","order_id": "string"},
                      parse_dates=["review_creation_date", "review_answer_timestamp"])

df.to_parquet(TARGET,compression="zstd", index=False)  # Write Parquet
results = pd.read_parquet(TARGET)
print(df.shape)
print(results)

