import csv
import time
import pyodbc

from pathlib import Path
from datetime import datetime


# ============================================================
# 1. CONFIGURATION
# ============================================================

SERVER = r"OMAR-OSAMA\OMAROSAMASQL22"
DATABASE = "Olist_DWH"

DATA_PATH = Path(
    r"C:\Users\Legion\Downloads\Olist_DWH\Data"
)

BATCH_SIZE = 10_000
PROGRESS_EVERY = 10

DRIVER = "ODBC Driver 17 for SQL Server"


# ============================================================
# 2. TABLE CONFIGURATION
# ============================================================

TABLES = [

    {
        "file": "crm_customers_dataset.csv",
        "schema": "bronze",
        "table": "crm_cust_info"
    },

    {
        "file": "crm_geolocation_dataset.csv",
        "schema": "bronze",
        "table": "crm_geolocation_info"
    },

    {
        "file": "crm_sellers_dataset.csv",
        "schema": "bronze",
        "table": "crm_seller_info"
    },

    {
        "file": "sales_order_items_dataset.csv",
        "schema": "bronze",
        "table": "sales_order_items"
    },

    {
        "file": "sales_order_reviews_dataset.csv",
        "schema": "bronze",
        "table": "sales_order_reviews"
    },

    {
        "file": "sales_orders_dataset.csv",
        "schema": "bronze",
        "table": "sales_orders"
    },

    {
        "file": "payment_order_dataset.csv",
        "schema": "bronze",
        "table": "payments_order_info"
    },

    {
        "file": "catalog_products_dataset.csv",
        "schema": "bronze",
        "table": "catalog_products"
    },

    {
        "file": "catalog_product_category_name_translation.csv",
        "schema": "bronze",
        "table": "catalog_category_translation"
    }

]


# ============================================================
# 3. DATABASE CONNECTION
# ============================================================

def get_connection():

    connection_string = (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
    )

    return pyodbc.connect(
        connection_string,
        autocommit=False
    )


# ============================================================
# 4. GET TARGET TABLE METADATA
# ============================================================

def get_table_columns(cursor, schema, table):

    query = """
        SELECT
            c.name AS column_name,
            t.name AS data_type,
            c.max_length,
            c.precision,
            c.scale

        FROM sys.columns c

        INNER JOIN sys.tables tb
            ON c.object_id = tb.object_id

        INNER JOIN sys.schemas s
            ON tb.schema_id = s.schema_id

        INNER JOIN sys.types t
            ON c.user_type_id = t.user_type_id

        WHERE
            s.name = ?
            AND tb.name = ?
            AND c.is_identity = 0
            AND c.is_computed = 0

        ORDER BY
            c.column_id;
    """

    cursor.execute(
        query,
        (schema, table)
    )

    columns = cursor.fetchall()

    if not columns:

        raise ValueError(
            f"Target table not found: {schema}.{table}"
        )

    return columns


# ============================================================
# 5. VALIDATE CSV HEADERS
# ============================================================

def validate_headers(
    source_headers,
    target_columns,
    schema,
    table
):

    source_map = {
        name.strip().lower(): index
        for index, name in enumerate(source_headers)
    }

    target_names = [
        column.column_name
        for column in target_columns
    ]

    target_map = {
        name.lower(): name
        for name in target_names
    }

    source_set = set(source_map.keys())
    target_set = set(target_map.keys())

    missing_columns = target_set - source_set
    extra_columns = source_set - target_set

    if missing_columns or extra_columns:

        raise ValueError(
            f"\nColumn mismatch in {schema}.{table}"
            f"\nMissing in CSV: {sorted(missing_columns)}"
            f"\nExtra in CSV: {sorted(extra_columns)}"
        )

    # Match CSV columns to target column order.

    source_indices = [
        source_map[column.lower()]
        for column in target_names
    ]

    return target_names, source_indices


# ============================================================
# 6. INSERT BATCH
# ============================================================

def insert_batch(
    connection,
    schema,
    table,
    columns,
    rows
):

    if not rows:
        return

    column_names = ", ".join(
        f"[{column.replace(']', ']]')}]"
        for column in columns
    )

    placeholders = ", ".join(
        ["?"] * len(columns)
    )

    query = f"""
        INSERT INTO [{schema}].[{table}]
        ({column_names})
        VALUES ({placeholders});
    """

    # Calculate maximum parameter length per column.

    input_sizes = []

    for col_index in range(len(columns)):

        max_length = max(
            (
                len(value)
                for row in rows
                if (value := row[col_index]) is not None
            ),
            default=1
        )

        input_sizes.append(
            (
                pyodbc.SQL_WVARCHAR,
                max(1, max_length),
                0
            )
        )

    # Dedicated cursor:
    # Prevent parameter settings from affecting metadata queries.

    insert_cursor = connection.cursor()

    try:

        insert_cursor.fast_executemany = True

        insert_cursor.setinputsizes(
            input_sizes
        )

        insert_cursor.executemany(
            query,
            rows
        )

    finally:

        insert_cursor.close()


# ============================================================
# 7. LOAD SINGLE TABLE
# ============================================================

def load_table(connection, metadata_cursor, config):

    file_name = config["file"]
    schema = config["schema"]
    table = config["table"]

    file_path = DATA_PATH / file_name

    print("\n" + "=" * 65)
    print(f"LOADING {schema}.{table}".center(65))
    print("=" * 65)

    print(f"Source file : {file_name}")
    print(f"Target table: {schema}.{table}")

    if not file_path.exists():

        raise FileNotFoundError(
            f"Source file not found: {file_path}"
        )

    start_time = time.time()

    # --------------------------------------------------------
    # 7.1 GET TARGET METADATA
    # --------------------------------------------------------

    target_columns = get_table_columns(
        metadata_cursor,
        schema,
        table
    )

    # --------------------------------------------------------
    # 7.2 READ CSV
    # --------------------------------------------------------

    loaded_rows = 0
    batch = []
    batch_number = 0

    with open(
        file_path,
        mode="r",
        encoding="utf-8-sig",
        newline=""
    ) as file:

        reader = csv.reader(
            file,
            delimiter=",",
            quotechar='"',
            doublequote=True,
            strict=True
        )

        source_headers = next(reader)

        target_columns_names, source_indices = (
            validate_headers(
                source_headers,
                target_columns,
                schema,
                table
            )
        )

        print(
            f"Columns     : {len(target_columns_names)}"
        )

        # ----------------------------------------------------
        # 7.3 PROCESS ROWS
        # ----------------------------------------------------

        for row in reader:

            if len(row) != len(source_headers):

                raise ValueError(
                    f"Invalid CSV row structure in "
                    f"{file_name}, line {reader.line_num}. "
                    f"Expected {len(source_headers)} fields, "
                    f"received {len(row)}."
                )

            values = []

            for index in source_indices:

                value = row[index]

                # Match the ingestion rule:
                # Empty CSV values become SQL NULL.

                if value == "":
                    value = None

                values.append(value)

            batch.append(tuple(values))

            # ------------------------------------------------
            # 7.4 INSERT FULL BATCH
            # ------------------------------------------------

            if len(batch) >= BATCH_SIZE:

                insert_batch(
                    connection,
                    schema,
                    table,
                    target_columns_names,
                    batch
                )

                loaded_rows += len(batch)

                batch.clear()

                batch_number += 1

                if batch_number % PROGRESS_EVERY == 0:

                    print(
                        f"Inserted rows: {loaded_rows:,}"
                    )

        # ----------------------------------------------------
        # 7.5 INSERT REMAINING ROWS
        # ----------------------------------------------------

        if batch:

            insert_batch(
                connection,
                schema,
                table,
                target_columns_names,
                batch
            )

            loaded_rows += len(batch)

            batch.clear()

    duration = time.time() - start_time

    print(f"Loaded rows : {loaded_rows:,}")
    print(f"Duration    : {duration:.2f} seconds")
    print("Status      : SUCCESS")

    return {
        "table": f"{schema}.{table}",
        "rows": loaded_rows,
        "duration": duration,
        "status": "SUCCESS"
    }


# ============================================================
# 8. TRUNCATE BRONZE TABLES
# ============================================================

def truncate_bronze_tables(cursor):

    print("\n" + "=" * 65)
    print("TRUNCATING BRONZE TABLES".center(65))
    print("=" * 65)

    for config in TABLES:

        schema = config["schema"]
        table = config["table"]

        print(
            f"Truncating {schema}.{table}"
        )

        cursor.execute(
            f"TRUNCATE TABLE [{schema}].[{table}];"
        )

    print("\nAll Bronze tables truncated.")


# ============================================================
# 9. MAIN EXECUTION
# ============================================================

def main():

    start_time = datetime.now()

    results = []

    print("\n" + "=" * 65)
    print("BRONZE LAYER INGESTION".center(65))
    print("=" * 65)

    print(f"Database    : {DATABASE}")
    print(f"Server      : {SERVER}")
    print(f"Source      : {DATA_PATH}")
    print(f"Batch size  : {BATCH_SIZE:,}")
    print(f"Start time  : {start_time}")

    connection = None
    metadata_cursor = None

    try:

        # ----------------------------------------------------
        # 9.1 CONNECT
        # ----------------------------------------------------

        print("\nConnecting to SQL Server...")

        connection = get_connection()

        metadata_cursor = connection.cursor()

        print("Connection established successfully.")

        # ----------------------------------------------------
        # 9.2 TRUNCATE
        # ----------------------------------------------------

        truncate_bronze_tables(
            metadata_cursor
        )

        # ----------------------------------------------------
        # 9.3 LOAD ALL TABLES
        # ----------------------------------------------------

        for config in TABLES:

            result = load_table(
                connection,
                metadata_cursor,
                config
            )

            results.append(result)

        # ----------------------------------------------------
        # 9.4 COMMIT
        # ----------------------------------------------------

        print("\n" + "=" * 65)
        print("COMMITTING TRANSACTION".center(65))
        print("=" * 65)

        connection.commit()

        print("Transaction committed successfully.")

        # ----------------------------------------------------
        # 9.5 FINAL SUMMARY
        # ----------------------------------------------------

        total_rows = sum(
            result["rows"]
            for result in results
        )

        total_duration = sum(
            result["duration"]
            for result in results
        )

        print("\n" + "=" * 65)
        print("BRONZE INGESTION SUMMARY".center(65))
        print("=" * 65)

        for result in results:

            print(
                f"{result['table']:<40}"
                f"{result['rows']:>15,} rows"
            )

        print("-" * 65)

        print(
            f"{'TOTAL ROWS':<40}"
            f"{total_rows:>15,}"
        )

        print(
            f"Total loading duration: "
            f"{total_duration:.2f} seconds"
        )

        print(
            f"Start time: {start_time}"
        )

        print(
            f"End time  : {datetime.now()}"
        )

        print("\nSTATUS: SUCCESS")

    except Exception as error:

        print("\n" + "=" * 65)
        print("BRONZE LOAD FAILED".center(65))
        print("=" * 65)

        print(f"Error: {error}")

        if connection is not None:

            connection.rollback()

            print(
                "\nAll changes were rolled back. "
                "Bronze tables restored to their previous state."
            )

        raise

    finally:

        if metadata_cursor is not None:
            metadata_cursor.close()

        if connection is not None:
            connection.close()


# ============================================================
# 10. EXECUTION
# ============================================================

if __name__ == "__main__":

    main()
