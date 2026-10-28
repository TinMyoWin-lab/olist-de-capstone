# olist-de-capstone

Capstone project for the Data Engineering Fundamentals course: a batch pipeline on the Olist Brazilian e-commerce dataset, from raw CSVs to a star schema in PostgreSQL, orchestrated with Airflow.

## Layout

| Path | Contents |
|---|---|
| `docs/architecture.md` | Dataset, business question and pipeline output |
| `sql/source/` | DDL and load script for the raw Olist tables |
| `sql/dw/` | Star schema DDL (facts and dimensions) |
| `sql/homework/` | Weekly SQL homework, one file per session (`weekNN_dayN.sql`) |
| `scripts/` | Python load and transform scripts |
| `dags/` | Airflow DAGs |
| `tests/` | Data quality checks |
| `data/raw/` | Olist CSVs (not committed) |

## Data

Download "Brazilian E-Commerce Public Dataset by Olist" from Kaggle and unzip the 9 CSVs into `data/raw/`. Then load them into the `raw` schema of `olist_dw`:

```bash
PGOPTIONS="-c search_path=raw" psql -d olist_dw -f sql/source/00_create_and_load_source_tables.sql
```
