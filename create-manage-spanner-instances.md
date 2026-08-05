i# Google Cloud Skills Boost Lab Documentation

## Cloud Spanner: Create and Manage Databases

### Task 1 -- Create a Cloud Spanner Instance

``` bash
gcloud spanner instances create banking-ops-instance     --config=regional-us-east4     --description="banking-ops-instance"     --nodes=1
```

Creates a Cloud Spanner instance with one node in the `us-east4` region.

``` bash
gcloud spanner instances list
```

Lists all Cloud Spanner instances in the current project.

------------------------------------------------------------------------

### Task 2 -- Create a Database

``` bash
gcloud spanner databases create banking-ops-db     --instance=banking-ops-instance
```

Creates a new Cloud Spanner database.

``` bash
gcloud spanner cli banking-ops-db --instance=banking-ops-instance
```

Opens the interactive Spanner SQL CLI.

------------------------------------------------------------------------

### Task 3 -- Create Tables

Executed SQL `CREATE TABLE` statements for: - Portfolio - Category -
Product - Customer

Creates the required database schema.

------------------------------------------------------------------------

### Task 4 -- Load Sample Data

Executed SQL `INSERT INTO` statements for: - Portfolio - Category -
Product

Loads the initial sample records into the tables.

------------------------------------------------------------------------

### Task 5 -- Import Customer Dataset

``` bash
gsutil cp gs://spls/gsp381/Customer_List_500.csv .
```

Downloads the customer CSV file.

``` bash
gsutil mb -l us-east4 gs://$PROJECT_ID-spanner-import
```

Creates a Cloud Storage bucket for the import.

``` bash
gsutil cp Customer_List_500.csv gs://$PROJECT_ID-spanner-import/
```

Uploads the CSV file to Cloud Storage.

Created `manifest.json`.

Defines the table, CSV location, and column mapping for the import.

``` bash
gsutil cp manifest.json gs://$PROJECT_ID-spanner-import/
```

Uploads the manifest file.

``` bash
gcloud services disable dataflow.googleapis.com --force
gcloud services enable dataflow.googleapis.com
```

Resets the Dataflow API.

``` bash
gcloud iam service-accounts add-iam-policy-binding ...
```

Grants the Dataflow service agent permission to use the Compute Engine
service account.

``` bash
gcloud dataflow jobs run customer-import-2 ...
```

Starts the Dataflow job to import all 500 customer records.

``` bash
gcloud dataflow jobs list --region=us-east4
```

Checks the Dataflow job status.

``` sql
SELECT COUNT(*) FROM Customer;
```

Verifies that all 500 records were imported.

------------------------------------------------------------------------

### Task 6 -- Add a New Column

``` bash
gcloud spanner databases ddl update banking-ops-db     --instance=banking-ops-instance     --ddl='ALTER TABLE Category ADD COLUMN MarketingBudget INT64;'
```

Adds the `MarketingBudget` column to the `Category` table.

``` bash
gcloud spanner databases ddl describe banking-ops-db     --instance=banking-ops-instance
```

Displays the current database schema for verification.

------------------------------------------------------------------------

## Lab Outcome

-   Created a Cloud Spanner instance.
-   Created a Cloud Spanner database.
-   Created four tables.
-   Loaded sample data.
-   Imported 500 customer records using Dataflow.
-   Added a new column using DDL.
-   Verified all tasks successfully.
