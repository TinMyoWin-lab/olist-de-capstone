import os
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[2]  # scripts/week7 -> project root
load_dotenv(BASE_DIR / ".env")  

data_dir = os.getenv("DATA_DIR")
output_dir = os.getenv("OUTPUT_DIR")
if not data_dir or not output_dir:
    raise RuntimeError("DATA_DIR and OUTPUT_DIR must be set in the .env file in the project root.")

DATA_DIR = BASE_DIR / data_dir
OUT_DIR = BASE_DIR / output_dir
TARGET = OUT_DIR / "sales_by_month"
 
orders = pd.read_csv(DATA_DIR / "olist_orders_dataset.csv",usecols=["order_id","customer_id","order_purchase_timestamp"],parse_dates=["order_purchase_timestamp"])
items = pd.read_csv(DATA_DIR / "olist_order_items_dataset.csv",usecols=["order_id","order_item_id","product_id","seller_id","price","freight_value"])
customers = pd.read_csv(DATA_DIR / "olist_customers_dataset.csv",usecols=["customer_id","customer_unique_id","customer_city","customer_state"])
 
df = orders.merge(items, on="order_id",how='inner',validate='one_to_many').merge(customers, on="customer_id",how='left',validate='many_to_one') #join them into one table
df["purchase_month"] = (pd.to_datetime(df["order_purchase_timestamp"]).dt.strftime("%Y-%m")) #create partition column

if not TARGET.exists():
    TARGET.mkdir(exist_ok=True)          # create the output folder if it doesn't exist

df.to_parquet(TARGET,partition_cols=["purchase_month"],compression="zstd", index=False) #Write partitioned Parquet

result=pd.read_parquet(TARGET,filters=[("purchase_month", "==", "2018-03")]) #Read back one month

 
print(df.shape)                       # about 112,000 rows
print(df["purchase_month"].head(3))   # values look like 2017-10
print(result)
