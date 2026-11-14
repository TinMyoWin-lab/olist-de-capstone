import os
import pandas as pd
from pathlib import Path
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parents[2]  #scripts/homeworks > root
load_dotenv(BASE_DIR / ".env")

output_dir = os.getenv("OUTPUT_DIR")
data_dir = os.getenv("DATA_DIR")
if not data_dir or not output_dir:
    raise RuntimeError("DATA_DIR and OUTPUT_DIR must be set in the .env file in the project root.")

DATA_DIR = BASE_DIR / data_dir
OUTPUT_DIR = BASE_DIR / output_dir

TARGET = OUTPUT_DIR / "sales_by_state"

if not TARGET.exists():
    TARGET.mkdir(parents=True, exist_ok=True)

orders = pd.read_csv(DATA_DIR / "olist_orders_dataset.csv",
                      encoding="utf-8",
                      dtype={"order_id": "string","customer_id": "string"},
                      parse_dates=[
                                "order_purchase_timestamp",
                                "order_approved_at",
                                "order_delivered_carrier_date",
                                "order_delivered_customer_date",
                                "order_estimated_delivery_date"
                                ]
                      )
customers = pd.read_csv(DATA_DIR / "olist_customers_dataset.csv",
                        encoding="utf-8",
                        dtype={"customer_id": "string",
                               "customer_unique_id": "string",
                               "customer_zip_code_prefix":"string"
                               },
                )

df = customers.merge(orders, on="customer_id", how='inner', validate='one_to_many')  # join them into one table

df.to_parquet(TARGET,partition_cols=["customer_state"], compression="zstd", index=False)  # Write Parquet

sp_orders = pd.read_parquet(TARGET, filters=[("customer_state", "==", "SP")])  # Read back one state

print("Folder Count: ", len(list(TARGET.iterdir())))
print("SP Rows: ",len(sp_orders))


    