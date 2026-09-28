"""
Modular Data Extraction Script
Connects to PostgreSQL (Neon DB) using credentials from .env,
executes the SQL cohort query, and saves the raw dataset to data/raw_customer_churn.csv.
"""

import os
import psycopg2
import pandas as pd
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = BASE_DIR / ".env"
SQL_PATH = BASE_DIR / "sql" / "extract_customer_churn_cohort.sql"
OUTPUT_PATH = BASE_DIR / "data" / "raw_customer_churn.csv"


def load_env(env_path):
    """Load key-value pairs from .env file into os.environ."""
    if not env_path.exists():
        raise FileNotFoundError(f".env file not found at {env_path}")
    with open(env_path, "r", encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ[key.strip()] = val.strip()


def extract_data():
    """Extract cohort from PostgreSQL and save as CSV."""
    print("Loading database configuration from .env...")
    load_env(ENV_PATH)

    conn_url = os.environ.get("DATABASE_URL")
    if not conn_url:
        host = os.environ.get("DB_HOST")
        port = os.environ.get("DB_PORT", "5432")
        dbname = os.environ.get("DB_NAME", "neondb")
        user = os.environ.get("DB_USER")
        password = os.environ.get("DB_PASSWORD")
        conn_url = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"

    if "sslmode" not in conn_url:
        conn_url += "?sslmode=require"

    print("Connecting to PostgreSQL database...")
    conn = psycopg2.connect(conn_url)

    print(f"Reading query from {SQL_PATH}...")
    with open(SQL_PATH, "r", encoding="utf-8-sig") as f:
        query = f.read()

    print("Executing query and extracting cohort...")
    cur = conn.cursor()
    cur.execute(query)
    columns = [desc[0] for desc in cur.description]
    data = cur.fetchall()
    df = pd.DataFrame(data, columns=columns)

    cur.close()
    conn.close()

    print(f"Extracted {len(df)} records across {len(df.columns)} columns.")

    # Save to data directory
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False)
    print(f"Dataset saved successfully to: {OUTPUT_PATH}")

    # Summary
    print("\n--- Cohort Summary ---")
    print("Class Balance:")
    print(df["churn"].value_counts(dropna=False))
    print("\nProportions:")
    print(df["churn"].value_counts(normalize=True))

    return df


if __name__ == "__main__":
    extract_data()
