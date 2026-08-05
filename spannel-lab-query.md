# Google Cloud Spanner – Defining Schemas and Understanding Query Plans

## Objective

This lab demonstrates how to:

- Load data into existing Cloud Spanner tables
- Use the Python client library to insert data
- Modify the database schema using DDL
- Update existing records after a schema change
- Query data to verify changes

---

# Environment

| Resource | Value |
|----------|-------|
| Instance | `banking-ops-instance` |
| Database | `banking-ops-db` |
| Tables | `Portfolio`, `Category`, `Product`, `Campaigns` |

---

# Task 1 – Load Data into Existing Tables

The database contained empty tables. Data was inserted into the following tables:

- Portfolio
- Category
- Product

## Insert Portfolio Data

```sql
INSERT INTO Portfolio (PortfolioId, Name, ShortName, PortfolioInfo)
VALUES
  (1, 'Banking', 'Bnkg', 'All Banking Business'),
  (2, 'Asset Growth', 'AsstGrwth', 'All Asset Focused Products'),
  (3, 'Insurance', 'Ins', 'All Insurance Focused Products');
```

---

## Insert Category Data

```sql
INSERT INTO Category (CategoryId, PortfolioId, CategoryName)
VALUES
  (1, 1, 'Cash'),
  (2, 2, 'Investments - Short Return'),
  (3, 2, 'Annuities'),
  (4, 3, 'Life Insurance');
```

---

## Insert Product Data

```sql
INSERT INTO Product
(ProductId, CategoryId, PortfolioId, ProductName, ProductAssetCode, ProductClass)
VALUES
(1,1,1,'Checking Account','ChkAcct','Banking LOB'),
(2,2,2,'Mutual Fund Consumer Goods','MFundCG','Investment LOB'),
(3,3,2,'Annuity Early Retirement','AnnuFixed','Investment LOB'),
(4,4,3,'Term Life Insurance','TermLife','Insurance LOB'),
(5,1,1,'Savings Account','SavAcct','Banking LOB'),
(6,1,1,'Personal Loan','PersLn','Banking LOB'),
(7,1,1,'Auto Loan','AutLn','Banking LOB'),
(8,4,3,'Permanent Life Insurance','PermLife','Insurance LOB'),
(9,2,2,'US Savings Bonds','USSavBond','Investment LOB');
```

---

# Task 2 – Prepare Python Environment

Create a working directory.

```bash
mkdir -p python-helper
cd python-helper
```

Download the required files.

```bash
wget https://storage.googleapis.com/cloud-training/OCBL373/requirements.txt
wget https://storage.googleapis.com/cloud-training/OCBL373/snippets.py
```

Install Python dependencies.

```bash
pip3 install -r requirements.txt
pip3 install setuptools
```

---

# Task 3 – Load Campaign Data Using Python Client

Populate the `Campaigns` table.

```bash
python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    insert_data
```

Verify data.

```bash
gcloud spanner databases execute-sql banking-ops-db \
    --instance=banking-ops-instance \
    --sql="SELECT * FROM Campaigns;"
```

---

# Task 4 – Update Database Schema

A new column was added to the `Category` table.

```sql
ALTER TABLE Category
ADD COLUMN MarketingBudget INT64;
```

Equivalent gcloud CLI command:

```bash
gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl="ALTER TABLE Category ADD COLUMN MarketingBudget INT64"
```

Verify schema.

```bash
gcloud spanner databases ddl describe banking-ops-db \
    --instance=banking-ops-instance
```

The updated schema included:

```text
MarketingBudget INT64
```

---

# Task 5 – Update Data in New Column

Update MarketingBudget values using the Python client.

```bash
python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    update_data
```

Expected output:

```text
Updated data.
```

---

# Task 6 – Query Updated Data

Retrieve the updated records.

```bash
python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    query_data_with_new_column
```

Expected output:

```text
CategoryId: 1, PortfolioId: 1, MarketingBudget: 100000
CategoryId: 2, PortfolioId: 2, MarketingBudget: None
CategoryId: 3, PortfolioId: 2, MarketingBudget: 500000
CategoryId: 4, PortfolioId: 3, MarketingBudget: None
```

Equivalent SQL verification:

```sql
SELECT
    CategoryId,
    PortfolioId,
    MarketingBudget
FROM Category
ORDER BY PortfolioId, CategoryId;
```

---

# CLI Commands Used

```bash
mkdir -p python-helper
cd python-helper

wget https://storage.googleapis.com/cloud-training/OCBL373/requirements.txt
wget https://storage.googleapis.com/cloud-training/OCBL373/snippets.py

pip3 install -r requirements.txt
pip3 install setuptools

python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    insert_data

gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl="ALTER TABLE Category ADD COLUMN MarketingBudget INT64"

gcloud spanner databases ddl describe banking-ops-db \
    --instance=banking-ops-instance

python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    update_data

python3 snippets.py banking-ops-instance \
    --database-id banking-ops-db \
    query_data_with_new_column

gcloud spanner databases execute-sql banking-ops-db \
    --instance=banking-ops-instance \
    --sql="SELECT CategoryId, PortfolioId, MarketingBudget FROM Category;"
```

---

# Outcome

Successfully completed the following:

- Loaded initial sample data into Cloud Spanner tables.
- Configured the Python Spanner client environment.
- Populated the `Campaigns` table using the Python client library.
- Modified the database schema by adding a new column.
- Updated existing records with marketing budget information.
- Queried the database to validate schema changes and updated data.
- Verified all operations using both the Python client and the `gcloud` CLI.
