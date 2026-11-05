
import os
import csv
import json
import hashlib
import pyodbc
import pandas as pd

from collections import Counter
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime, date, timedelta


# ============================================================
# 1. CONFIGURATION
# ============================================================

DATA_PATH = r"C:\Users\Legion\Downloads\Olist_DWH\Data"

REPORT_PATH = os.path.join(
    DATA_PATH,
    "Bronze_Quality_Report.xlsx"
)

SERVER = r"OMAR-OSAMA\OMAROSAMASQL22"
DATABASE = "Olist_DWH"

SCHEMA = "bronze"

BATCH_SIZE = 10000
MAX_MISMATCH_SAMPLES = 1000


TABLES = {
    "crm_customers_dataset.csv": "crm_cust_info",
    "crm_geolocation_dataset.csv": "crm_geolocation_info",
    "crm_sellers_dataset.csv": "crm_seller_info",
    "sales_order_items_dataset.csv": "sales_order_items",
    "sales_order_reviews_dataset.csv": "sales_order_reviews",
    "sales_orders_dataset.csv": "sales_orders",
    "payment_order_dataset.csv": "payments_order_info",
    "catalog_products_dataset.csv": "catalog_products",
    "catalog_product_category_name_translation.csv":
        "catalog_category_translation"
}


SHEET_PREFIXES = {
    "crm_cust_info": "customers",
    "crm_geolocation_info": "geo",
    "crm_seller_info": "sellers",
    "sales_order_items": "items",
    "sales_order_reviews": "reviews",
    "sales_orders": "orders",
    "payments_order_info": "payments",
    "catalog_products": "products",
    "catalog_category_translation": "categories"
}


# ============================================================
# 2. SQL CONNECTION
# ============================================================

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
)


# ============================================================
# 3. VALUE NORMALIZATION
# ============================================================

def normalize_datetime(value, sql_type):

    if isinstance(value, datetime):
        dt = value

    elif isinstance(value, date):
        dt = datetime.combine(value, datetime.min.time())

    else:
        value = str(value).strip()

        if value.endswith("Z"):
            value = value[:-1] + "+00:00"

        dt = datetime.fromisoformat(value)

    if dt.tzinfo is not None:
        dt = dt.replace(tzinfo=None)

    # SQL Server DATETIME precision:
    # Approximately 0.000, 0.003, 0.007 seconds.

    if sql_type == "datetime":

        base = dt.replace(microsecond=0)

        ticks = (
            dt.microsecond * 300 + 500000
        ) // 1000000

        if ticks >= 300:
            base += timedelta(seconds=1)
            ticks = 0

        milliseconds = (
            ticks * 1000 + 150
        ) // 300

        if milliseconds >= 1000:
            base += timedelta(seconds=1)
            milliseconds = 0

        dt = base.replace(
            microsecond=milliseconds * 1000
        )

    elif sql_type == "smalldatetime":

        if dt.second >= 30:
            dt = dt.replace(
                second=0,
                microsecond=0
            ) + timedelta(minutes=1)
        else:
            dt = dt.replace(
                second=0,
                microsecond=0
            )

    return dt.strftime("%Y-%m-%d %H:%M:%S.%f")


def normalize_value(value, metadata):

    sql_type = metadata["type"].lower()
    scale = metadata["scale"]

    # Empty CSV values are converted to SQL NULL
    # by the existing Bronze Loader.

    if value is None:
        return None

    if isinstance(value, str) and value == "":
        return None

    # Text columns

    if sql_type in (
        "nvarchar",
        "varchar",
        "nchar",
        "char",
        "text",
        "ntext"
    ):
        return str(value)

    # Integer columns

    if sql_type in (
        "int",
        "bigint",
        "smallint",
        "tinyint"
    ):
        return str(int(Decimal(str(value))))

    # Decimal columns

    if sql_type in (
        "decimal",
        "numeric"
    ):

        number = Decimal(str(value))

        quantizer = Decimal("1").scaleb(-scale)

        number = number.quantize(
            quantizer,
            rounding=ROUND_HALF_UP
        )

        return format(number, "f")

    # Floating-point columns

    if sql_type in ("float", "real"):

        number = Decimal(str(value))

        return format(number.normalize(), "f")

    # Datetime columns

    if sql_type in (
        "datetime",
        "datetime2",
        "smalldatetime"
    ):
        return normalize_datetime(
            value,
            sql_type
        )

    # Date columns

    if sql_type == "date":

        if isinstance(value, datetime):
            return value.date().isoformat()

        if isinstance(value, date):
            return value.isoformat()

        return date.fromisoformat(
            str(value)
        ).isoformat()

    # Bit columns

    if sql_type == "bit":

        if str(value).strip().lower() in (
            "1", "true"
        ):
            return "1"

        return "0"

    return str(value)


# ============================================================
# 4. ROW HASHING
# ============================================================

def create_row_hash(row, metadata):

    normalized_row = tuple(
        normalize_value(value, column_metadata)
        for value, column_metadata in zip(row, metadata)
    )

    serialized = json.dumps(
        normalized_row,
        ensure_ascii=False,
        separators=(",", ":")
    )

    return hashlib.sha256(
        serialized.encode("utf-8")
    ).hexdigest()


# ============================================================
# 5. SQL TABLE METADATA
# ============================================================

def get_table_metadata(cursor, table_name):

    query = """
        SELECT
            c.name,
            t.name AS data_type,
            c.scale,
            c.precision,
            c.column_id

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

        ORDER BY c.column_id;
    """

    cursor.execute(
        query,
        SCHEMA,
        table_name
    )

    columns = cursor.fetchall()

    metadata = []

    for column in columns:

        metadata.append({
            "name": column.name,
            "type": column.data_type,
            "scale": column.scale,
            "precision": column.precision
        })

    return metadata


# ============================================================
# 6. READ SOURCE CSV
# ============================================================

def read_source_csv(file_path, metadata):

    source_counts = Counter()

    source_rows = 0

    with open(
        file_path,
        "r",
        encoding="utf-8-sig",
        newline=""
    ) as file:

        reader = csv.reader(file)

        headers = next(reader)

        expected_columns = [
            column["name"]
            for column in metadata
        ]

        if (
            len(headers) != len(expected_columns)
            or set(headers) != set(expected_columns)
        ):

            raise ValueError(
                "CSV columns do not match SQL table columns."
            )

        # Align SQL metadata with CSV column order.

        metadata_map = {
            column["name"]: column
            for column in metadata
        }

        ordered_metadata = [
            metadata_map[column]
            for column in headers
        ]

        for row_number, row in enumerate(
            reader,
            start=2
        ):

            if len(row) != len(headers):

                raise ValueError(
                    f"Invalid column count at CSV row {row_number}"
                )

            row_hash = create_row_hash(
                row,
                ordered_metadata
            )

            source_counts[row_hash] += 1
            source_rows += 1

    return (
        source_counts,
        source_rows,
        headers,
        ordered_metadata
    )


# ============================================================
# 7. READ BRONZE TABLE
# ============================================================

def read_bronze_table(
    connection,
    table_name,
    metadata,
    headers
):

    bronze_counts = Counter()

    bronze_rows = 0

    columns_sql = ", ".join(
        f"[{column}]"
        for column in headers
    )

    query = f"""
        SELECT {columns_sql}
        FROM [{SCHEMA}].[{table_name}];
    """

    cursor = connection.cursor()

    cursor.execute(query)

    while True:

        rows = cursor.fetchmany(BATCH_SIZE)

        if not rows:
            break

        for row in rows:

            row_hash = create_row_hash(
                row,
                metadata
            )

            bronze_counts[row_hash] += 1
            bronze_rows += 1

    return bronze_counts, bronze_rows


# ============================================================
# 8. GET MISMATCH SAMPLES
# ============================================================

def get_source_mismatch_samples(
    file_path,
    metadata,
    headers,
    remaining_counts
):

    samples = []

    if not remaining_counts:
        return samples

    with open(
        file_path,
        "r",
        encoding="utf-8-sig",
        newline=""
    ) as file:

        reader = csv.reader(file)

        next(reader)

        for row in reader:

            if len(samples) >= MAX_MISMATCH_SAMPLES:
                break

            row_hash = create_row_hash(
                row,
                metadata
            )

            if remaining_counts[row_hash] > 0:

                samples.append(dict(zip(headers, row)))

                remaining_counts[row_hash] -= 1

    return samples


def get_bronze_mismatch_samples(
    connection,
    table_name,
    metadata,
    headers,
    remaining_counts
):

    samples = []

    if not remaining_counts:
        return samples

    columns_sql = ", ".join(
        f"[{column}]"
        for column in headers
    )

    query = f"""
        SELECT {columns_sql}
        FROM [{SCHEMA}].[{table_name}];
    """

    cursor = connection.cursor()

    cursor.execute(query)

    while True:

        rows = cursor.fetchmany(BATCH_SIZE)

        if not rows:
            break

        for row in rows:

            if len(samples) >= MAX_MISMATCH_SAMPLES:
                return samples

            row_hash = create_row_hash(
                row,
                metadata
            )

            if remaining_counts[row_hash] > 0:

                samples.append(
                    dict(zip(headers, row))
                )

                remaining_counts[row_hash] -= 1

    return samples


# ============================================================
# 9. VALIDATE ALL TABLES
# ============================================================

def validate_all_tables():

    connection = pyodbc.connect(
        CONNECTION_STRING
    )

    summary = []
    mismatch_sheets = {}

    try:

        cursor = connection.cursor()

        total_tables = len(TABLES)

        for index, (csv_file, table_name) in enumerate(
            TABLES.items(),
            start=1
        ):

            print("\n" + "=" * 65)

            print(
                f"[{index}/{total_tables}] Validating: {table_name}"
            )

            print("=" * 65)

            file_path = os.path.join(
                DATA_PATH,
                csv_file
            )

            try:

                if not os.path.exists(file_path):

                    raise FileNotFoundError(
                        f"CSV file not found: {file_path}"
                    )

                # Get SQL metadata

                print("Step 1: Reading SQL metadata...")

                metadata = get_table_metadata(
                    cursor,
                    table_name
                )

                if not metadata:

                    raise ValueError(
                        "SQL table does not exist or has no columns."
                    )

                # Read source CSV

                print("Step 2: Reading source CSV...")

                (
                    source_counts,
                    source_rows,
                    headers,
                    ordered_metadata
                ) = read_source_csv(
                    file_path,
                    metadata
                )

                print(
                    f"Source rows: {source_rows:,}"
                )

                # Read Bronze table

                print("Step 3: Reading Bronze table...")

                (
                    bronze_counts,
                    bronze_rows
                ) = read_bronze_table(
                    connection,
                    table_name,
                    ordered_metadata,
                    headers
                )

                print(
                    f"Bronze rows: {bronze_rows:,}"
                )

                # Multiset comparison:
                # Preserves duplicate row occurrences.

                matching_rows = sum(
                    (source_counts & bronze_counts).values()
                )

                source_only_counts = (
                    source_counts - bronze_counts
                )

                bronze_only_counts = (
                    bronze_counts - source_counts
                )

                source_only = sum(
                    source_only_counts.values()
                )

                bronze_only = sum(
                    bronze_only_counts.values()
                )

                total_mismatches = (
                    source_only + bronze_only
                )

                status = (
                    "PASS"
                    if source_only == 0 and bronze_only == 0
                    else "FAIL"
                )

                print("\nValidation Results:")

                print(
                    f"Matching rows: {matching_rows:,}"
                )

                print(
                    f"Source-only rows: {source_only:,}"
                )

                print(
                    f"Bronze-only rows: {bronze_only:,}"
                )

                print(
                    f"Status: {status}"
                )

                summary.append({

                    "Table": table_name,

                    "Source Rows": source_rows,

                    "Bronze Rows": bronze_rows,

                    "Matching Rows": matching_rows,

                    "Source Only": source_only,

                    "Bronze Only": bronze_only,

                    "Total Mismatches": total_mismatches,

                    "Status": status,

                    "Error": ""

                })

                # Generate mismatch samples only when needed.

                if status == "FAIL":

                    print(
                        "Step 4: Collecting mismatch samples..."
                    )

                    prefix = SHEET_PREFIXES.get(
                        table_name,
                        table_name[:10]
                    )

                    source_samples = (
                        get_source_mismatch_samples(
                            file_path,
                            ordered_metadata,
                            headers,
                            source_only_counts.copy()
                        )
                    )

                    bronze_samples = (
                        get_bronze_mismatch_samples(
                            connection,
                            table_name,
                            ordered_metadata,
                            headers,
                            bronze_only_counts.copy()
                        )
                    )

                    if source_samples:

                        mismatch_sheets[
                            f"{prefix}_SRC"
                        ] = source_samples

                    if bronze_samples:

                        mismatch_sheets[
                            f"{prefix}_BRONZE"
                        ] = bronze_samples

            except Exception as error:

                print(f"ERROR: {error}")

                summary.append({

                    "Table": table_name,

                    "Source Rows": None,

                    "Bronze Rows": None,

                    "Matching Rows": None,

                    "Source Only": None,

                    "Bronze Only": None,

                    "Total Mismatches": None,

                    "Status": "ERROR",

                    "Error": str(error)

                })

    finally:

        connection.close()

    # ========================================================
    # 10. EXPORT EXCEL REPORT
    # ========================================================

    print("\n" + "=" * 65)
    print("Generating Excel Report...")
    print("=" * 65)

    summary_df = pd.DataFrame(summary)

    with pd.ExcelWriter(
        REPORT_PATH,
        engine="openpyxl"
    ) as writer:

        summary_df.to_excel(
            writer,
            sheet_name="Validation_Summary",
            index=False
        )

        for sheet_name, rows in mismatch_sheets.items():

            pd.DataFrame(rows).to_excel(
                writer,
                sheet_name=sheet_name[:31],
                index=False
            )

    print("\nValidation Completed.")

    print(
        f"Report saved to: {REPORT_PATH}"
    )

    print("\nFinal Summary:")

    print(
        summary_df[
            ["Table", "Matching Rows", "Total Mismatches", "Status"]
        ].to_string(index=False)
    )


    failed_tables = [
        row for row in summary
        if row.get("Status") != "PASS"
    ]

    if failed_tables:
        print("\nVALIDATION FAILED!")
        raise SystemExit(1)

    print("\nVALIDATION PASSED!")
    raise SystemExit(0)

# ============================================================
# 11. EXECUTION
# ============================================================

if __name__ == "__main__":

    validate_all_tables()

