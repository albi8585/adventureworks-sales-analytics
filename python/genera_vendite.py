import pyodbc
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import uuid
import sys
import os

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Configurazione connessione SQL Server
SERVER = os.getenv("SQL_SERVER", "localhost")
DATABASE = os.getenv("SQL_DATABASE", "AdventureWorks2022")

# Stringa di connessione - prova prima senza specificare il database (autenticazione Windows)
connection_string_test = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};Trusted_Connection=yes;Encrypt=no;TrustServerCertificate=yes'
connection_string = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;Encrypt=no;TrustServerCertificate=yes'


def fetch_scalar(conn, sql):
    return conn.cursor().execute(sql).fetchval()


def validate_history_primary_keys(conn):
    duplicate_header_ids = fetch_scalar(conn, """
SELECT COUNT(*)
FROM (
    SELECT SalesOrderID
    FROM project.salesorderheader_prj
    GROUP BY SalesOrderID
    HAVING COUNT(*) > 1
) AS duplicates
""")
    duplicate_detail_ids = fetch_scalar(conn, """
SELECT COUNT(*)
FROM (
    SELECT SalesOrderDetailID
    FROM project.salesorderdetail_prj
    GROUP BY SalesOrderDetailID
    HAVING COUNT(*) > 1
) AS duplicates
""")
    if duplicate_header_ids:
        raise ValueError(f"project.salesorderheader_prj contiene {duplicate_header_ids} SalesOrderID duplicati.")
    if duplicate_detail_ids:
        raise ValueError(f"project.salesorderdetail_prj contiene {duplicate_detail_ids} SalesOrderDetailID duplicati.")
    print("✓ Nessun duplicato nelle chiavi storiche SalesOrderID/SalesOrderDetailID.")


def validate_generated_detail_ids(conn, df_daily_temp):
    if df_daily_temp.empty:
        raise ValueError("Nessuna riga generata per project.daily_orderdetails_temp.")
    if df_daily_temp['SalesOrderDetailID'].isna().any():
        raise ValueError("Sono stati generati SalesOrderDetailID NULL.")
    if df_daily_temp['SalesOrderDetailID'].duplicated().any():
        raise ValueError("Sono stati generati SalesOrderDetailID duplicati.")

    detail_ids = [(int(value),) for value in df_daily_temp['SalesOrderDetailID'].unique()]
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE #generated_detail_ids (SalesOrderDetailID int NOT NULL PRIMARY KEY)")
    cursor.executemany("INSERT INTO #generated_detail_ids (SalesOrderDetailID) VALUES (?)", detail_ids)
    overlaps = cursor.execute("""
SELECT COUNT(*)
FROM #generated_detail_ids AS generated
JOIN project.salesorderdetail_prj AS historical
    ON historical.SalesOrderDetailID = generated.SalesOrderDetailID
""").fetchval()
    cursor.execute("DROP TABLE #generated_detail_ids")
    if overlaps:
        raise ValueError(f"{overlaps} SalesOrderDetailID generati esistono gia in project.salesorderdetail_prj.")
    print("✓ Nessun duplicato SalesOrderDetailID rispetto allo storico.")


def validate_generated_orders(conn, df_orders_temp, expected_order_date, min_allowed_sales_order_id):
    if df_orders_temp.empty:
        raise ValueError("Nessuna riga generata per project.orders_temp.")
    if df_orders_temp[['OrderDate', 'DueDate', 'ShipDate']].isna().any().any():
        raise ValueError("Le date generate non possono essere NULL.")
    if df_orders_temp['SalesOrderID'].isna().any():
        raise ValueError("Sono stati generati SalesOrderID NULL.")
    if df_orders_temp['SalesOrderID'].duplicated().any():
        raise ValueError("Sono stati generati SalesOrderID duplicati.")

    order_dates = pd.to_datetime(df_orders_temp['OrderDate'], errors='coerce').dt.date
    if order_dates.isna().any():
        raise ValueError("OrderDate contiene valori non validi.")
    expected_order_date = pd.Timestamp(expected_order_date).date()
    if order_dates.min() != expected_order_date or order_dates.max() != expected_order_date:
        raise ValueError(
            f"OrderDate generata non coerente: atteso {expected_order_date}, "
            f"trovato range {order_dates.min()} - {order_dates.max()}."
        )

    min_generated_sales_order_id = int(df_orders_temp['SalesOrderID'].min())
    if min_generated_sales_order_id <= int(min_allowed_sales_order_id):
        raise ValueError(
            "SalesOrderID generati non partono dopo il massimo SalesOrderID consentito "
            f"({min_allowed_sales_order_id})."
        )

    order_ids = [(int(value),) for value in df_orders_temp['SalesOrderID'].unique()]
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE #generated_order_ids (SalesOrderID int NOT NULL PRIMARY KEY)")
    cursor.executemany("INSERT INTO #generated_order_ids (SalesOrderID) VALUES (?)", order_ids)
    overlaps = cursor.execute("""
SELECT COUNT(*)
FROM #generated_order_ids AS generated
JOIN project.salesorderheader_prj AS historical
    ON historical.SalesOrderID = generated.SalesOrderID
""").fetchval()
    cursor.execute("DROP TABLE #generated_order_ids")
    if overlaps:
        raise ValueError(f"{overlaps} SalesOrderID generati esistono gia in project.salesorderheader_prj.")
    print("✓ Nessun duplicato SalesOrderID rispetto allo storico e OrderDate coerente.")

try:
    # Test connessione iniziale
    print("Test connessione a SQL Server...")
    print(f"Server: {SERVER}")
    print(f"Database: {DATABASE}")
    print(f"Autenticazione: Windows (Trusted Connection)")
    print()
    
    try:
        conn_test = pyodbc.connect(connection_string_test, autocommit=True)
        print(f"✓ Connessione al server {SERVER} riuscita!")
        conn_test.close()
    except Exception as e:
        print(f"⚠ Impossibile connettersi al server: {e}")
        print("Possibili cause:")
        print("- SQL Server non è in esecuzione")
        print("- Credenziali non corrette")
        print("- Server non raggiungibile in rete")
        raise
    
    # Connessione a SQL Server con database
    print(f"\nConnessione al database {DATABASE}...")
    conn = pyodbc.connect(connection_string, autocommit=True)
    validate_history_primary_keys(conn)
    print(f"✓ Connessione a {DATABASE} su {SERVER} riuscita!")
    
    # Estrazione tabella project.SalesOrderDetail_prj
    query = "SELECT * FROM project.SalesOrderDetail_prj ORDER BY SalesOrderID DESC"
    df_original = pd.read_sql(query, conn)
    if 'SalesorderdetailID' in df_original.columns and 'SalesOrderDetailID' not in df_original.columns:
        df_original = df_original.rename(columns={'SalesorderdetailID': 'SalesOrderDetailID'})
    
    print(f"\n✓ Estratti {len(df_original)} record da project.SalesOrderDetail_prj")
    print(f"\nColonne: {list(df_original.columns)}")
    print(f"\nPrime righe:\n{df_original.head()}")
    print(f"\nInfo dati:\n{df_original.info()}")
    
    # Salva i dati originali
    df_original.to_csv('sales_order_details_backup.csv', index=False, encoding='utf-8')
    print(f"\n✓ Dati originali salvati in 'sales_order_details_backup.csv'")

    # Estrazione tabella Production.Product per ProductID non venduti
    query_products = """
SELECT p.ProductID, p.ListPrice
FROM Production.Product AS p
INNER JOIN (
    SELECT DISTINCT ProductID
    FROM project.productcosthistory_prj
) AS pch
    ON pch.ProductID = p.ProductID
"""
    df_products = pd.read_sql(query_products, conn)
    if df_products.empty:
        raise ValueError("project.productcosthistory_prj non contiene ProductID utilizzabili.")

    allowed_product_ids = set(df_products['ProductID'].unique())
    original_row_count = len(df_original)
    df_original = df_original[df_original['ProductID'].isin(allowed_product_ids)].copy()
    if df_original.empty:
        raise ValueError("Nessuna riga storica di vendita ha ProductID presente in project.productcosthistory_prj.")
    print(
        f"\n✓ Filtrate {len(df_original)} righe storiche su {original_row_count}: "
        "ProductID presenti in project.productcosthistory_prj"
    )
    
    sold_product_ids = set(df_original['ProductID'].unique())
    all_product_ids = set(df_products['ProductID'].unique())
    unsold_product_ids = sorted(list(all_product_ids - sold_product_ids))
    
    print(f"\n✓ Trovati {len(unsold_product_ids)} ProductID in Production.Product non presenti in Sales.SalesOrderDetail")
    
    product_price_map = dict(zip(df_products['ProductID'], df_products['ListPrice']))
    product_qty_samples = df_original.groupby('ProductID')['OrderQty'].apply(lambda x: x.tolist()).to_dict()
    product_qty_caps = {
        pid: max(1, int(np.percentile(qtys, 95)))
        for pid, qtys in product_qty_samples.items()
    }
    order_qty_values, order_qty_probs = np.unique(df_original['OrderQty'], return_counts=True)
    order_qty_probs = order_qty_probs / order_qty_probs.sum()
    overall_qty_cap = int(np.percentile(df_original['OrderQty'], 95)) if len(df_original) > 0 else 20
    overall_qty_cap = max(overall_qty_cap, 10)
    nonzero_list_prices = df_products.loc[df_products['ListPrice'] > 0, 'ListPrice'].tolist()
    nonzero_list_price_mean = float(np.mean(nonzero_list_prices)) if len(nonzero_list_prices) > 0 else 100.0
    nonzero_list_price_std = float(np.std(nonzero_list_prices, ddof=0)) if len(nonzero_list_prices) > 0 else 50.0

    def sample_list_price():
        if len(nonzero_list_prices) == 0:
            return float(np.round(np.random.uniform(10, 300), 2))
        base = float(np.random.choice(nonzero_list_prices))
        noise = np.random.normal(0, max(1.0, nonzero_list_price_std * 0.1))
        return round(max(1.0, base + noise), 2)

    query_daily_totals = """
SELECT
    CAST(soh.OrderDate AS date) AS OrderDate,
    sod.SalesOrderID,
    sod.OrderQty,
    sod.ProductID
FROM project.salesorderheader_prj AS soh
JOIN project.SalesOrderDetail_prj AS sod
    ON soh.SalesOrderID = sod.SalesOrderID
WHERE soh.OrderDate IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM project.productcosthistory_prj AS pch
      WHERE pch.ProductID = sod.ProductID
  )
"""
    df_daily_totals = pd.read_sql(query_daily_totals, conn)
    if df_daily_totals.empty:
        raise ValueError(
            "Nessuna vendita storica trovata per il campionamento giornaliero "
            "senza limitazione di date."
        )
    daily_totals = df_daily_totals.groupby('OrderDate')['OrderQty'].sum()
    daily_orders = df_daily_totals.groupby('OrderDate')['SalesOrderID'].nunique()
    mean_daily_total = daily_totals.mean()
    std_daily_total = daily_totals.std(ddof=0)
    mean_daily_orders = daily_orders.mean()
    std_daily_orders = daily_orders.std(ddof=0)
    mean_orderqty_line = df_original['OrderQty'].mean()
    std_orderqty_line = df_original['OrderQty'].std(ddof=0)

    print(f"\n✓ Media giornaliera storica di OrderQty: {mean_daily_total:.2f} (std {std_daily_total:.2f})")
    print(f"✓ Media storica ordini al giorno: {mean_daily_orders:.2f} (std {std_daily_orders:.2f})")
    print(f"✓ Media storica OrderQty per riga: {mean_orderqty_line:.2f} (std {std_orderqty_line:.2f})")

    # ============================================================================
    # GENERAZIONE NUOVE RIGHE DI VENDITA PER daily_orderdetails_temp
    # ============================================================================
    
    order_line_counts = df_original.groupby('SalesOrderID').size()
    order_qty_per_order = df_original.groupby('SalesOrderID')['OrderQty'].sum()
    mean_order_qty_per_order = order_qty_per_order.mean()
    std_order_qty_per_order = order_qty_per_order.std(ddof=0)
    order_total_values, order_total_probs = np.unique(order_qty_per_order, return_counts=True)
    order_total_probs = order_total_probs / order_total_probs.sum()
    line_count_values, line_count_probs = np.unique(order_line_counts, return_counts=True)
    line_count_probs = line_count_probs / line_count_probs.sum()
    
    product_qty_stats = df_original.groupby('ProductID')['OrderQty'].agg(['mean', 'std']).to_dict('index')
    quantity_mean = max(1, df_original['OrderQty'].mean())
    quantity_std = max(1.0, df_original['OrderQty'].std(ddof=0))
    product_qty_mean_avg = np.mean([max(1.0, stats['mean']) for stats in product_qty_stats.values()])
    product_qty_std_avg = np.mean([max(1.0, stats['std'] if not np.isnan(stats['std']) else 1.0) for stats in product_qty_stats.values()])

    max_header_sales_order_id = pd.read_sql(
        "SELECT MAX(SalesOrderID) AS MaxSalesOrderID FROM project.salesorderheader_prj",
        conn
    )['MaxSalesOrderID'].iloc[0]
    max_header_sales_order_id = int(max_header_sales_order_id) if not pd.isna(max_header_sales_order_id) else 0
    print(f"\nSalesOrderID massimo in project.salesorderheader_prj: {max_header_sales_order_id}")

    max_orders_temp_sales_order_id = fetch_scalar(conn, """
DECLARE @max_sales_order_id int = NULL;
IF OBJECT_ID('project.orders_temp', 'U') IS NOT NULL
BEGIN
    EXEC sp_executesql
        N'SELECT @result = MAX(SalesOrderID) FROM project.orders_temp',
        N'@result int OUTPUT',
        @result = @max_sales_order_id OUTPUT;
END;
SELECT @max_sales_order_id;
""")
    max_orders_temp_sales_order_id = (
        int(max_orders_temp_sales_order_id)
        if max_orders_temp_sales_order_id is not None and not pd.isna(max_orders_temp_sales_order_id)
        else 0
    )
    sales_order_id_base = (
        max_orders_temp_sales_order_id
        if max_orders_temp_sales_order_id > 0
        else max_header_sales_order_id
    )
    print(f"SalesOrderID massimo in project.orders_temp: {max_orders_temp_sales_order_id}")
    print(f"Nuovi SalesOrderID generati da: {sales_order_id_base + 1}")

    max_historical_sales_order_detail_id = pd.read_sql(
        "SELECT MAX(SalesOrderDetailID) AS MaxSalesOrderDetailID FROM project.salesorderdetail_prj",
        conn
    )['MaxSalesOrderDetailID'].iloc[0]
    max_historical_sales_order_detail_id = (
        int(max_historical_sales_order_detail_id)
        if not pd.isna(max_historical_sales_order_detail_id)
        else 0
    )
    print(f"SalesOrderDetailID massimo in project.salesorderdetail_prj: {max_historical_sales_order_detail_id}")
    print(f"Nuovi SalesOrderDetailID generati da: {max_historical_sales_order_detail_id + 1}")

    def genera_vendite_daily_temp(
        df_original,
        df_products,
        mean_daily_total,
        std_daily_total,
        mean_daily_orders,
        std_daily_orders,
        start_from_sales_order_id=None,
        start_from_sales_order_detail_id=None,
        unsold_fraction=0.25,
    ):
        sold_df = df_original.copy()
        sold_product_ids = sold_df['ProductID'].unique()
        unsold_ids = sorted(list(set(df_products['ProductID']) - set(sold_product_ids)))
        product_price_map = dict(zip(df_products['ProductID'], df_products['ListPrice']))

        discount_values, discount_counts = np.unique(sold_df['UnitPriceDiscount'], return_counts=True)
        discount_probs = discount_counts / discount_counts.sum()
        special_offer_values, special_offer_counts = np.unique(sold_df['SpecialOfferID'], return_counts=True)
        special_offer_probs = special_offer_counts / special_offer_counts.sum()
        product_freq = sold_df['ProductID'].value_counts(normalize=True)
        existing_product_ids = product_freq.index.to_numpy()
        existing_product_probs = product_freq.to_numpy()

        historical_daily_totals = daily_totals.to_numpy()
        min_daily_total = np.percentile(historical_daily_totals, 15)
        sample_pool = historical_daily_totals[historical_daily_totals >= min_daily_total]
        sampled_daily_total = int(np.random.choice(sample_pool))
        volatility_multiplier = float(np.random.normal(1.0, 0.08))
        volatility_multiplier = float(np.clip(volatility_multiplier, 0.85, 1.15))
        target_total = int(round(sampled_daily_total * volatility_multiplier))
        target_total = int(np.clip(
            target_total,
            historical_daily_totals.min(),
            historical_daily_totals.max(),
        ))
        target_total = max(1, target_total)
        target_orders = int(np.random.normal(mean_daily_orders, max(1.0, std_daily_orders * 0.2)))
        target_orders = max(5, int(np.clip(target_orders, mean_daily_orders * 0.7, mean_daily_orders * 1.3)))

        max_sales_order_id = int(start_from_sales_order_id) if start_from_sales_order_id is not None else int(sold_df['SalesOrderID'].max())
        max_sales_order_detail_id = (
            int(start_from_sales_order_detail_id)
            if start_from_sales_order_detail_id is not None
            else int(sold_df['SalesOrderDetailID'].max())
        )
        new_rows = []
        current_total = 0
        order_id = max_sales_order_id + 1
        detail_id = max_sales_order_detail_id + 1

        def sample_line_qty(product_id, max_qty):
            qty = None
            if product_id in product_qty_samples and len(product_qty_samples[product_id]) > 3:
                historical_qtys = np.array(product_qty_samples[product_id])
                qty = int(np.random.choice(historical_qtys))
                if qty > overall_qty_cap or np.random.rand() < 0.15:
                    qty = int(np.round(np.random.normal(np.mean(historical_qtys), max(1.0, np.std(historical_qtys, ddof=0)))))
            else:
                qty = int(np.random.choice(order_qty_values, p=order_qty_probs))
            if qty is None or qty <= 0:
                qty = int(np.round(np.random.normal(quantity_mean, quantity_std)))
            qty = max(1, qty)
            qty = min(qty, max_qty, product_qty_caps.get(product_id, overall_qty_cap), overall_qty_cap)
            return qty

        def get_unit_price(product_id):
            list_price = float(product_price_map.get(product_id, 0.0))
            return list_price if list_price > 0 else sample_list_price()

        for order_index in range(target_orders):
            if current_total >= target_total:
                break

            n_lines = int(np.random.choice(line_count_values, p=line_count_probs))
            n_lines = max(1, n_lines)
            if np.random.rand() < 0.75:
                order_target = int(np.random.choice(order_total_values, p=order_total_probs))
            else:
                order_target = int(np.random.normal(mean_order_qty_per_order, max(1.0, std_order_qty_per_order * 0.25)))
            order_target = max(n_lines, order_target)
            remaining_total = target_total - current_total
            if order_target > remaining_total:
                order_target = remaining_total

            order_qty_sum = 0
            order_rows = []

            for line_index in range(n_lines):
                remaining_lines = n_lines - line_index
                max_qty = max(1, (order_target - order_qty_sum) - (remaining_lines - 1))
                if np.random.rand() < 0.25 and len(unsold_ids) > 0:
                    product_id = int(np.random.choice(unsold_ids))
                else:
                    product_id = int(np.random.choice(existing_product_ids, p=existing_product_probs))

                if line_index == n_lines - 1:
                    order_qty = min(max_qty, product_qty_caps.get(product_id, overall_qty_cap), overall_qty_cap)
                else:
                    order_qty = sample_line_qty(product_id, max_qty)

                unit_price = get_unit_price(product_id)
                unit_price = max(1.0, float(unit_price))
                unit_price_discount = 0.0 if np.random.rand() < 0.75 else float(np.random.choice(discount_values, p=discount_probs))
                special_offer_id = int(np.random.choice(special_offer_values, p=special_offer_probs))
                row = {
                    'SalesOrderID': int(order_id),
                    'SalesOrderDetailID': int(detail_id),
                    'OrderQty': int(order_qty),
                    'ProductID': product_id,
                    'SpecialOfferID': special_offer_id,
                    'UnitPrice': round(unit_price, 2),
                    'UnitPriceDiscount': round(unit_price_discount, 4),
                    'LineTotal': round(order_qty * unit_price * (1 - unit_price_discount), 2)
                }
                order_rows.append(row)
                order_qty_sum += order_qty
                detail_id += 1

            if order_qty_sum > 0:
                new_rows.extend(order_rows)
                current_total += order_qty_sum
                order_id += 1

        if current_total < target_total:
            while current_total < target_total:
                product_id = int(np.random.choice(existing_product_ids, p=existing_product_probs))
                unit_price = get_unit_price(product_id)
                unit_price = max(1.0, float(unit_price))
                unit_price_discount = 0.0 if np.random.rand() < 0.75 else float(np.random.choice(discount_values, p=discount_probs))
                special_offer_id = int(np.random.choice(special_offer_values, p=special_offer_probs))
                remaining_total = target_total - current_total
                order_qty = min(
                    max(1, int(np.round(np.random.normal(quantity_mean, quantity_std)))),
                    remaining_total,
                    overall_qty_cap,
                    product_qty_caps.get(product_id, overall_qty_cap)
                )
                row = {
                    'SalesOrderID': int(order_id),
                    'SalesOrderDetailID': int(detail_id),
                    'OrderQty': order_qty,
                    'ProductID': product_id,
                    'SpecialOfferID': special_offer_id,
                    'UnitPrice': round(unit_price, 2),
                    'UnitPriceDiscount': round(unit_price_discount, 4),
                    'LineTotal': round(order_qty * unit_price * (1 - unit_price_discount), 2)
                }
                new_rows.append(row)
                current_total += order_qty
                order_id += 1
                detail_id += 1

        df_new = pd.DataFrame(new_rows)
        return df_new

    print("\n" + "="*70)
    print("GENERAZIONE SIMULAZIONE PER daily_orderdetails_temp")
    print("="*70)
    
    df_daily_temp = genera_vendite_daily_temp(
        df_original,
        df_products,
        mean_daily_total,
        std_daily_total,
        mean_daily_orders,
        std_daily_orders,
        start_from_sales_order_id=sales_order_id_base,
        start_from_sales_order_detail_id=max_historical_sales_order_detail_id,
        unsold_fraction=0.25
    )
    
    actual_total = int(df_daily_temp['OrderQty'].sum())
    total_orders = df_daily_temp['SalesOrderID'].nunique()
    generated_product_ids = set(df_daily_temp['ProductID'].unique())
    invalid_product_ids = sorted(generated_product_ids - allowed_product_ids)
    if invalid_product_ids:
        raise ValueError(
            "ProductID generati non presenti in project.productcosthistory_prj: "
            f"{invalid_product_ids[:10]}"
        )
    print(f"\n✓ Generate {len(df_daily_temp)} righe simulate per daily_orderdetails_temp")
    print(f"✓ Totale ordini unici in daily_orderdetails_temp: {total_orders}")
    print(f"✓ Totale OrderQty generato: {actual_total}")
    print(f"\nAnteprima:\n{df_daily_temp.head(10)}")
    print(f"\nProductID non venduti usati: {len(set(df_daily_temp.loc[df_daily_temp['ProductID'].isin(unsold_product_ids), 'ProductID']))}")
    
    # Statistiche della simulazione
    print("\n" + "="*70)
    print("STATISTICHE SIMULAZIONE")
    print("="*70)
    print(f"\nOrderQty - nuove righe: {df_daily_temp['OrderQty'].describe().to_dict()}")
    print(f"\nUnitPrice - nuove righe: {df_daily_temp['UnitPrice'].describe().to_dict()}")
    print(f"\nUnitPriceDiscount - nuove righe: {df_daily_temp['UnitPriceDiscount'].describe().to_dict()}")
    print(f"\nTotale OrderQty giornaliero generato: {actual_total}")
    
    # Script SQL per inserimento nella tabella daily_orderdetails_temp
    print("\n" + "="*70)
    print("SCRIPT SQL PER daily_orderdetails_temp")
    print("="*70)
    
    sql_insert_daily_script = """
-- Script per inserire le righe simulate in Adventureworks2022.project.daily_orderdetails_temp
-- Assicurati che la tabella daily_orderdetails_temp abbia le stesse colonne di Sales.SalesOrderDetail

INSERT INTO project.daily_orderdetails_temp 
(SalesOrderID, SalesOrderDetailID, OrderQty, ProductID, 
 SpecialOfferID, UnitPrice, UnitPriceDiscount, LineTotal, modified_date)
VALUES
"""
    
    for idx, row in df_daily_temp.iterrows():
        values = f"({row['SalesOrderID']}, {row['SalesOrderDetailID']}, {row['OrderQty']}, {row['ProductID']}, {row['SpecialOfferID']}, {row['UnitPrice']}, {row['UnitPriceDiscount']}, {row['LineTotal']}, GETDATE())"
        if idx < len(df_daily_temp) - 1:
            sql_insert_daily_script += f"\n{values},"
        else:
            sql_insert_daily_script += f"\n{values};"
    
    with open('insert_daily_orderdetails_temp.sql', 'w', encoding='utf-8') as f:
        f.write(sql_insert_daily_script)
    print(f"\n✓ Script SQL salvato in 'insert_daily_orderdetails_temp.sql'")

    create_schema_script = """
-- Creazione schema project se non esiste
IF SCHEMA_ID('project') IS NULL
BEGIN
    EXEC('CREATE SCHEMA project');
END
"""
    with open('create_project_schema.sql', 'w', encoding='utf-8') as f:
        f.write(create_schema_script)
    print(f"\n✓ Script creazione schema salvato in 'create_project_schema.sql'")
    conn.execute(create_schema_script)
    print("✓ Schema project creato o già esistente su DB")

    create_daily_orderdetails_script = """
-- Creazione tabella project.daily_orderdetails_temp se non esiste
IF SCHEMA_ID('project') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'daily_orderdetails_temp' AND schema_id = SCHEMA_ID('project'))
    BEGIN
        CREATE TABLE project.daily_orderdetails_temp (
            SalesOrderID int NOT NULL,
            SalesOrderDetailID int NOT NULL,
            OrderQty smallint NOT NULL,
            ProductID int NOT NULL,
            SpecialOfferID int NOT NULL,
            UnitPrice money NOT NULL,
            UnitPriceDiscount money NOT NULL,
            LineTotal money NOT NULL,
            modified_date datetime2(0) NOT NULL CONSTRAINT DF_daily_orderdetails_temp_modified_date DEFAULT (GETDATE())
        );
    END
END

IF OBJECT_ID('project.daily_orderdetails_temp', 'U') IS NOT NULL
    AND COL_LENGTH('project.daily_orderdetails_temp', 'modified_date') IS NULL
BEGIN
    ALTER TABLE project.daily_orderdetails_temp
    ADD modified_date datetime2(0) NOT NULL
        CONSTRAINT DF_daily_orderdetails_temp_modified_date DEFAULT (GETDATE()) WITH VALUES;
END
"""
    with open('create_dailyorderdetails_temp.sql', 'w', encoding='utf-8') as f:
        f.write(create_daily_orderdetails_script)
    print(f"\n✓ Script creazione tabella salvato in 'create_dailyorderdetails_temp.sql'")
    conn.execute(create_daily_orderdetails_script)
    print("✓ Tabella project.daily_orderdetails_temp creata o già esistente su DB")

    validate_generated_detail_ids(conn, df_daily_temp)

    delete_daily_sql = "DELETE FROM project.daily_orderdetails_temp;"
    conn.execute(delete_daily_sql)
    print("✓ Righe esistenti eliminate da project.daily_orderdetails_temp")
    conn.execute(sql_insert_daily_script)
    print("✓ Dati daily_orderdetails_temp inseriti direttamente nel database Adventureworks2022")

    # ============================================================================
    # GENERAZIONE ORDINI SIMULATI PER orders_temp
    # ============================================================================
    
    print("\n" + "="*70)
    print("GENERAZIONE ORDINI PER orders_temp")
    print("="*70)

    query_header = "SELECT SalesOrderID, OrderDate, DueDate, ShipDate, OnlineOrderFlag, CustomerID, SalesPersonID, TerritoryID FROM project.salesorderheader_prj"
    df_header = pd.read_sql(query_header, conn)
    latest_order_date = pd.to_datetime(df_header['OrderDate'], errors='coerce').max()
    if pd.isna(latest_order_date):
        raise ValueError("project.salesorderheader_prj non contiene una OrderDate valida.")
    
    query_customers = "SELECT CustomerID FROM project.customer_prj"
    df_customers = pd.read_sql(query_customers, conn)
    
    header_customer_freq = df_header['CustomerID'].value_counts(normalize=True)
    historical_customer_ids = header_customer_freq.index.to_numpy()
    historical_customer_probs = header_customer_freq.to_numpy()
    all_customer_ids = df_customers['CustomerID'].unique()
    never_bought_customer_ids = np.array(sorted(list(set(all_customer_ids) - set(df_header['CustomerID'].unique()))), dtype=int)
    
    header_salesperson_freq = df_header['SalesPersonID'].dropna().astype(int).value_counts(normalize=True)
    salesperson_ids = header_salesperson_freq.index.to_numpy() if len(header_salesperson_freq) > 0 else np.array([], dtype=int)
    salesperson_probs = header_salesperson_freq.to_numpy() if len(header_salesperson_freq) > 0 else np.array([], dtype=float)
    salesperson_territory = df_header.dropna(subset=['SalesPersonID']).drop_duplicates(subset=['SalesPersonID'])[['SalesPersonID', 'TerritoryID']]
    salesperson_territory_map = dict(zip(salesperson_territory['SalesPersonID'].astype(int), salesperson_territory['TerritoryID'].astype('Int64')))
    territory_ids = df_header['TerritoryID'].dropna().astype(int).unique()
    
    unique_orders = sorted(df_daily_temp['SalesOrderID'].unique())
    historical_order_ids = df_header['SalesOrderID'].dropna().astype(int).unique()
    current_date = latest_order_date.normalize() + timedelta(days=1)
    orders_rows = []
    duplicate_order_count = 0
    null_date_count = 0

    for order_id in unique_orders:
        output_order_id = int(order_id)

        if len(historical_customer_ids) > 0 and np.random.rand() < 0.75:
            customer_id = int(np.random.choice(historical_customer_ids, p=historical_customer_probs))
        elif len(never_bought_customer_ids) > 0:
            customer_id = int(np.random.choice(never_bought_customer_ids))
        else:
            customer_id = int(np.random.choice(historical_customer_ids, p=historical_customer_probs))

        online_flag = bool(np.random.rand() < 0.45)
        due_days = int(np.random.choice([2, 3, 4, 5, 7, 10], p=[0.2, 0.2, 0.15, 0.15, 0.2, 0.1]))
        ship_delay = int(np.random.choice([0, 0, 1, 1, 2, 3, 4], p=[0.15, 0.15, 0.2, 0.2, 0.15, 0.1, 0.05]))

        order_date = current_date
        due_date = order_date + timedelta(days=due_days)
        ship_date = due_date + timedelta(days=ship_delay)
        if np.random.rand() < 0.2:
            ship_date = due_date

        if online_flag:
            sales_person_id = None
            territory_id = int(territory_ids[np.random.randint(len(territory_ids))]) if len(territory_ids) > 0 else None
        elif len(salesperson_ids) > 0 and np.random.rand() < 0.9:
            sales_person_id = int(np.random.choice(salesperson_ids, p=salesperson_probs))
            territory_id = int(salesperson_territory_map.get(sales_person_id, territory_ids[np.random.randint(len(territory_ids))] if len(territory_ids) > 0 else None))
        else:
            sales_person_id = None
            territory_id = int(territory_ids[np.random.randint(len(territory_ids))]) if len(territory_ids) > 0 else None

        orders_rows.append({
            'SalesOrderID': output_order_id,
            'OrderDate': order_date,
            'DueDate': due_date,
            'ShipDate': ship_date,
            'OnlineOrderFlag': int(online_flag),
            'CustomerID': int(customer_id),
            'SalesPersonID': int(sales_person_id) if sales_person_id is not None else None,
            'TerritoryID': int(territory_id) if territory_id is not None else None
        })

    df_orders_temp = pd.DataFrame(orders_rows)
    if df_orders_temp[['OrderDate', 'DueDate', 'ShipDate']].isna().any().any():
        raise ValueError("Le date generate non possono essere NULL.")
    if df_orders_temp['SalesOrderID'].duplicated().any():
        raise ValueError("Sono stati generati SalesOrderID duplicati.")
    df_orders_temp.to_csv('orders_temp_simulated.csv', index=False, encoding='utf-8')
    print(f"\n✓ orders_temp salvato in 'orders_temp_simulated.csv'")
    print(f"✓ Generati {len(df_orders_temp)} ordini in orders_temp")

    print(f"SalesOrderID duplicati dallo storico inseriti: {duplicate_order_count}")
    print(f"Righe con una data NULL inserite: {null_date_count}")

    create_orders_temp_script = """
-- Creazione tabella project.orders_temp se non esiste
IF SCHEMA_ID('project') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'orders_temp' AND schema_id = SCHEMA_ID('project'))
    BEGIN
        CREATE TABLE project.orders_temp (
            SalesOrderID int NOT NULL,
            OrderDate date NOT NULL,
            DueDate date NOT NULL,
            ShipDate date NOT NULL,
            OnlineOrderFlag bit NOT NULL,
            CustomerID int NOT NULL,
            SalesPersonID int NULL,
            TerritoryID int NULL,
            processed bit NOT NULL DEFAULT (0),
            modified_date datetime2(0) NOT NULL CONSTRAINT DF_orders_temp_modified_date DEFAULT (GETDATE()),
            CONSTRAINT CK_orders_temp_online_salesperson CHECK (
                (OnlineOrderFlag = 1 AND SalesPersonID IS NULL) OR
                (OnlineOrderFlag = 0)
            )
        );
    END
END

IF OBJECT_ID('project.orders_temp', 'U') IS NOT NULL
BEGIN
    ALTER TABLE project.orders_temp ALTER COLUMN OrderDate date NOT NULL;
    ALTER TABLE project.orders_temp ALTER COLUMN DueDate date NOT NULL;
    ALTER TABLE project.orders_temp ALTER COLUMN ShipDate date NOT NULL;
END

IF OBJECT_ID('project.orders_temp', 'U') IS NOT NULL
    AND COL_LENGTH('project.orders_temp', 'modified_date') IS NULL
BEGIN
    ALTER TABLE project.orders_temp
    ADD modified_date datetime2(0) NOT NULL
        CONSTRAINT DF_orders_temp_modified_date DEFAULT (GETDATE()) WITH VALUES;
END
"""
    with open('create_orders_temp.sql', 'w', encoding='utf-8') as f:
        f.write(create_orders_temp_script)
    print(f"\n✓ Script di creazione tabella salvato in 'create_orders_temp.sql'")
    conn.execute(create_orders_temp_script)
    print("✓ Tabella project.orders_temp creata o già esistente su DB")

    validate_generated_orders(conn, df_orders_temp, current_date, sales_order_id_base)

    delete_orders_sql = "DELETE FROM project.orders_temp;"
    conn.execute(delete_orders_sql)
    print("✓ Righe esistenti eliminate da project.orders_temp")

    insert_orders_temp_script = """
-- Script per inserire i dati in project.orders_temp
INSERT INTO project.orders_temp 
(SalesOrderID, OrderDate, DueDate, ShipDate, OnlineOrderFlag, CustomerID, SalesPersonID, TerritoryID, processed, modified_date)
VALUES
"""
    for idx, row in df_orders_temp.iterrows():
        sales_person_val = 'NULL' if pd.isna(row['SalesPersonID']) else int(row['SalesPersonID'])
        territory_val = 'NULL' if pd.isna(row['TerritoryID']) else int(row['TerritoryID'])
        order_date_sql = 'NULL' if pd.isna(row['OrderDate']) else f"'{row['OrderDate'].strftime('%Y-%m-%d') if isinstance(row['OrderDate'], datetime) else row['OrderDate']}'"
        due_date_sql = 'NULL' if pd.isna(row['DueDate']) else f"'{row['DueDate'].strftime('%Y-%m-%d') if isinstance(row['DueDate'], datetime) else row['DueDate']}'"
        ship_date_sql = 'NULL' if pd.isna(row['ShipDate']) else f"'{row['ShipDate'].strftime('%Y-%m-%d') if isinstance(row['ShipDate'], datetime) else row['ShipDate']}'"
        values = f"({row['SalesOrderID']}, {order_date_sql}, {due_date_sql}, {ship_date_sql}, {int(row['OnlineOrderFlag'])}, {row['CustomerID']}, {sales_person_val}, {territory_val}, 0, GETDATE())"
        if idx < len(df_orders_temp) - 1:
            insert_orders_temp_script += f"\n{values},"
        else:
            insert_orders_temp_script += f"\n{values};"
    with open('insert_orders_temp.sql', 'w', encoding='utf-8') as f:
        f.write(insert_orders_temp_script)
    print(f"\n✓ Script SQL salvato in 'insert_orders_temp.sql'")

    conn.execute(insert_orders_temp_script)
    print("✓ Dati orders_temp inseriti direttamente nel database Adventureworks2022")

    conn.close()
    print(f"\n✓ Connessione chiusa")

except pyodbc.Error as e:
    print(f"✗ Errore di connessione SQL Server: {e}")
    print("\nVerifica:")
    print("- Server: valore configurato in SQL_SERVER")
    print("- Database: Adventureworks2022")
    print("- Driver ODBC: Assicurati che sia installato 'ODBC Driver 17 for SQL Server'")
    
except Exception as e:
    print(f"✗ Errore: {e}")
