#!/usr/bin/env bash
# scripts/run_migrations.sh
# Applies migrations for all service DBs and then seeds CSV data from /seed.
set -euo pipefail

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-adminpass}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

CUSTOMER_DB="${CUSTOMER_DB:-customer_db}"
RESTAURANT_DB="${RESTAURANT_DB:-restaurant_db}"
ORDER_DB="${ORDER_DB:-order_db}"
PAYMENT_DB="${PAYMENT_DB:-payment_db}"
DELIVERY_DB="${DELIVERY_DB:-delivery_db}"

RETRIES="${MIGRATOR_PSQL_CONNECT_RETRIES:-20}"
SLEEP_SECONDS="${MIGRATOR_PSQL_RETRY_INTERVAL:-3}"

MIGRATION_DIR="/migrations"
SEED_DIR="/seed"

echo "Migrator starting: migrations dir = $MIGRATION_DIR, seed dir = $SEED_DIR"
echo "Postgres user = $POSTGRES_USER, port = $POSTGRES_PORT"
echo

# ---------- Helpers ----------
wait_for_db() {
  local host="$1"
  local port="$2"
  local dbname="$3"
  local attempt=0
  until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$host" -U "$POSTGRES_USER" -p "$port" -d "$dbname" -c '\q' >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$RETRIES" ]; then
      echo "ERROR: Could not connect to $host:$port/$dbname after $RETRIES attempts" >&2
      return 1
    fi
    echo "Waiting for $host:$port/$dbname — attempt $attempt/$RETRIES..."
    sleep "$SLEEP_SECONDS"
  done
  echo "$host:$port/$dbname is available"
}

apply_migration() {
  local host="$1"
  local port="$2"
  local dbname="$3"
  local sqlfile="$4"

  if [ ! -f "$sqlfile" ]; then
    echo "WARN: Migration file not found: $sqlfile — skipping $dbname"
    return 0
  fi

  echo "Applying migration $sqlfile → $host:$port/$dbname"
  PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$host" -U "$POSTGRES_USER" -p "$port" -d "$dbname" -f "$sqlfile"
  echo "Migration applied for $dbname"
}

run_psql_cmd() {
  local host="$1"; local port="$2"; local dbname="$3"; local cmd="$4"
  PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$host" -U "$POSTGRES_USER" -p "$port" -d "$dbname" -c "$cmd"
}

# New robust copy helper using a here-doc so psql receives \copy correctly
run_copy_heredoc() {
  local host="$1"; local port="$2"; local dbname="$3"; local copy_cmd="$4"
  echo "Seeding $dbname via psql here-doc: $copy_cmd"
  PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$host" -U "$POSTGRES_USER" -p "$port" -d "$dbname" <<PSQL
$copy_cmd
PSQL
}

# choose seed file helper (handles "customers.csv" or "customers food.csv")
choose_seed() {
  local base="$1"   # e.g. "customers" or "menu_items"
  local ext="$2"    # e.g. "csv"
  # try exact base.ext then base<space>ext (older name)
  if [ -f "${SEED_DIR}/${base}.${ext}" ]; then
    echo "${SEED_DIR}/${base}.${ext}"
    return 0
  fi
  if [ -f "${SEED_DIR}/${base} ${ext}" ]; then
    echo "${SEED_DIR}/${base} ${ext}"
    return 0
  fi
  # also try lowercase variations
  if [ -f "${SEED_DIR}/${base}_$ext" ]; then
    echo "${SEED_DIR}/${base}_$ext"
    return 0
  fi
  return 1
}

# ---------- Map DB names to compose hostnames ----------
declare -A DB_HOSTS
DB_HOSTS["$CUSTOMER_DB"]="customer-db:${POSTGRES_PORT}"
DB_HOSTS["$RESTAURANT_DB"]="restaurant-db:${POSTGRES_PORT}"
DB_HOSTS["$ORDER_DB"]="order-db:${POSTGRES_PORT}"
DB_HOSTS["$PAYMENT_DB"]="payment-db:${POSTGRES_PORT}"
DB_HOSTS["$DELIVERY_DB"]="delivery-db:${POSTGRES_PORT}"

# ---------- Apply migrations ----------
echo "Starting migrations..."
for dbname in "${!DB_HOSTS[@]}"; do
  hostport="${DB_HOSTS[$dbname]}"
  host="${hostport%%:*}"
  port="${hostport##*:}"

  echo
  echo "=== Processing DB: $dbname at $host:$port ==="
  wait_for_db "$host" "$port" "$dbname" || { echo "Failed to connect to $dbname"; exit 1; }

  case "$dbname" in
    "$CUSTOMER_DB") migration_file="$MIGRATION_DIR/customer_migrations.sql" ;;
    "$RESTAURANT_DB") migration_file="$MIGRATION_DIR/restaurant_migrations.sql" ;;
    "$ORDER_DB") migration_file="$MIGRATION_DIR/order_migrations.sql" ;;
    "$PAYMENT_DB") migration_file="$MIGRATION_DIR/payment_migrations.sql" ;;
    "$DELIVERY_DB") migration_file="$MIGRATION_DIR/delivery_migrations.sql" ;;
    *) echo "No migration mapping for $dbname"; exit 2 ;;
  esac

  apply_migration "$host" "$port" "$dbname" "$migration_file"
done

echo
echo "All migrations completed successfully."
echo

# ---------- Seed data (truncate then \copy via heredoc) ----------
echo "Starting seeding CSV data..."

# ---- customer_db: customers + addresses ----
hostport="${DB_HOSTS[$CUSTOMER_DB]}"
host="${hostport%%:*}"; port="${hostport##*:}"
echo
echo "Seeding $CUSTOMER_DB on $host:$port"

# Truncate in safe order
run_psql_cmd "$host" "$port" "$CUSTOMER_DB" "TRUNCATE TABLE customer_schema.addresses RESTART IDENTITY CASCADE;"
run_psql_cmd "$host" "$port" "$CUSTOMER_DB" "TRUNCATE TABLE customer_schema.customers RESTART IDENTITY CASCADE;"

# pick the correct customers file
cust_file=$(choose_seed "customers" "csv") || { echo "ERROR: customers CSV not found in $SEED_DIR"; exit 1; }
addr_file=$(choose_seed "addresses" "csv") || { echo "ERROR: addresses CSV not found in $SEED_DIR"; exit 1; }

run_copy_heredoc "$host" "$port" "$CUSTOMER_DB" "\\copy customer_schema.customers(customer_id,name,email,phone,created_at) FROM '${cust_file}' CSV HEADER"
run_copy_heredoc "$host" "$port" "$CUSTOMER_DB" "\\copy customer_schema.addresses(address_id,customer_id,line1,area,city,pincode,created_at) FROM '${addr_file}' CSV HEADER"

# ---- restaurant_db: restaurants + menu_items ----
hostport="${DB_HOSTS[$RESTAURANT_DB]}"
host="${hostport%%:*}"; port="${hostport##*:}"
echo
echo "Seeding $RESTAURANT_DB on $host:$port"

run_psql_cmd "$host" "$port" "$RESTAURANT_DB" "TRUNCATE TABLE restaurant_schema.menu_items RESTART IDENTITY CASCADE;"
run_psql_cmd "$host" "$port" "$RESTAURANT_DB" "TRUNCATE TABLE restaurant_schema.restaurants RESTART IDENTITY CASCADE;"

rest_file=$(choose_seed "restaurants" "csv") || { echo "ERROR: restaurants CSV not found in $SEED_DIR"; exit 1; }
menu_file=$(choose_seed "menu_items" "csv") || { echo "ERROR: menu_items CSV not found in $SEED_DIR"; exit 1; }

# restaurants.csv has created_at in your seed -> copy including created_at
run_copy_heredoc "$host" "$port" "$RESTAURANT_DB" "\\copy restaurant_schema.restaurants(restaurant_id,name,cuisine,city,rating,is_open,created_at) FROM '${rest_file}' CSV HEADER"

# menu_items.csv does NOT include created_at in your data -> copy without it
run_copy_heredoc "$host" "$port" "$RESTAURANT_DB" "\\copy restaurant_schema.menu_items(item_id,restaurant_id,name,category,price,is_available) FROM '${menu_file}' CSV HEADER"

# ---- order_db: orders + order_items ----
hostport="${DB_HOSTS[$ORDER_DB]}"
host="${hostport%%:*}"; port="${hostport##*:}"
echo
echo "Seeding $ORDER_DB on $host:$port"

run_psql_cmd "$host" "$port" "$ORDER_DB" "TRUNCATE TABLE order_schema.order_items RESTART IDENTITY CASCADE;"
run_psql_cmd "$host" "$port" "$ORDER_DB" "TRUNCATE TABLE order_schema.orders RESTART IDENTITY CASCADE;"

orders_file=$(choose_seed "orders" "csv") || { echo "ERROR: orders CSV not found in $SEED_DIR"; exit 1; }
order_items_file=$(choose_seed "order_items" "csv") || { echo "ERROR: order_items CSV not found in $SEED_DIR"; exit 1; }

# If your orders.csv does not have delivery_fee/tax_amount columns, you may need to preprocess or alter the copy columns.
run_copy_heredoc "$host" "$port" "$ORDER_DB" "\\copy order_schema.orders(order_id,customer_id_ref,restaurant_id_ref,address_id_ref,order_status,order_total,payment_status,delivery_fee,tax_amount,created_at) FROM '${orders_file}' CSV HEADER"
run_copy_heredoc "$host" "$port" "$ORDER_DB" "\\copy order_schema.order_items(order_item_id,order_id,item_id_ref,quantity,price,created_at) FROM '${order_items_file}' CSV HEADER"

# ---- payment_db: payments ----
hostport="${DB_HOSTS[$PAYMENT_DB]}"
host="${hostport%%:*}"; port="${hostport##*:}"
echo
echo "Seeding $PAYMENT_DB on $host:$port"

run_psql_cmd "$host" "$port" "$PAYMENT_DB" "TRUNCATE TABLE payment_schema.payments RESTART IDENTITY CASCADE;"
payments_file=$(choose_seed "payments" "csv") || { echo "ERROR: payments CSV not found in $SEED_DIR"; exit 1; }
run_copy_heredoc "$host" "$port" "$PAYMENT_DB" "\\copy payment_schema.payments(payment_id,order_id,amount,method,status,reference,created_at) FROM '${payments_file}' CSV HEADER"

# ---- delivery_db: drivers + deliveries ----
hostport="${DB_HOSTS[$DELIVERY_DB]}"
host="${hostport%%:*}"; port="${hostport##*:}"
echo
echo "Seeding $DELIVERY_DB on $host:$port"

run_psql_cmd "$host" "$port" "$DELIVERY_DB" "TRUNCATE TABLE delivery_schema.deliveries RESTART IDENTITY CASCADE;"
run_psql_cmd "$host" "$port" "$DELIVERY_DB" "TRUNCATE TABLE delivery_schema.drivers RESTART IDENTITY CASCADE;"

drivers_file=$(choose_seed "drivers" "csv") || { echo "ERROR: drivers CSV not found in $SEED_DIR"; exit 1; }
deliveries_file=$(choose_seed "deliveries" "csv") || { echo "ERROR: deliveries CSV not found in $SEED_DIR"; exit 1; }

run_copy_heredoc "$host" "$port" "$DELIVERY_DB" "\\copy delivery_schema.drivers(driver_id,name,phone,vehicle_type,is_active,city,created_at) FROM '${drivers_file}' CSV HEADER"
run_copy_heredoc "$host" "$port" "$DELIVERY_DB" "\\copy delivery_schema.deliveries(delivery_id,order_id,driver_id,status,assigned_at,picked_at,delivered_at,created_at) FROM '${deliveries_file}' CSV HEADER"

echo
echo "All seed data imported successfully."
echo "Migrator finished."

exit 0
