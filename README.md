# README.md

# Online Food Delivery — Docker Compose (Run APIs)

This repository contains the microservices for the Online Food Delivery assignment (Customer, Restaurant, Order, Payment), one Postgres database per service, and a migrator that applies schema migrations and seeds CSV data.

This README gives the minimal, **exact** steps to run the stack locally with Docker Compose and verify the APIs. Share this file with your group — following it will start the APIs and seed the DBs.

---

## Prerequisites

* Docker (desktop) installed and running
* Docker Compose v2 (the `docker compose` command)
* Git (to clone repo)
* (Optional) `curl` for testing endpoints, or Postman

> NOTE (Windows): commands below work in PowerShell or CMD. Some examples include both Unix and PowerShell variants where necessary.

---

## Repo layout (important files)

```
.
├─ docker-compose.yml
├─ .env                # must exist (example below)
├─ migrations/         # SQL migration files (includes order_migrations.sql)
├─ seed/               # CSV seed files
├─ scripts/run_migrations.sh
├─ customer-service/
├─ restaurant-service/
├─ order-service/
├─ payment-service/
```

---

## .env (example)

Create a `.env` file in repo root (DO NOT commit secrets publicly). Example contents used in development:

```
# Postgres credentials
POSTGRES_USER=postgres
POSTGRES_PASSWORD=2491
POSTGRES_PORT=5432

# Database names (used by compose & services)
CUSTOMER_DB=customer_db
RESTAURANT_DB=restaurant_db
ORDER_DB=order_db
PAYMENT_DB=payment_db
DELIVERY_DB=delivery_db

# Migrator retry settings
MIGRATOR_PSQL_CONNECT_RETRIES=20
MIGRATOR_PSQL_RETRY_INTERVAL=3
```

---

## Start everything (recommended, single command)

From repo root:

```bash
# Build images and start all DBs, migrator, and services
docker compose up --build
```

* The `migrator` runs migrations and seeds CSVs, then exits.
* Databases (customer-db, restaurant-db, order-db, payment-db, delivery-db) stay up.
* Services start and expose ports on the host as configured below.

To run in detached mode:

```bash
docker compose up --build -d
```

---

## Run migrator only (apply migrations & seed CSVs)

If DBs are already running and you want to re-run migrations:

```bash
docker compose run --rm migrator
```

This will apply migrations (safe `IF NOT EXISTS` SQL used) and seed CSVs from `./seed`.

---

## Exposed service ports (host -> container)

* Customer service: `http://localhost:3000`
* Restaurant service: `http://localhost:4000`
* Order service: `http://localhost:5000`
* Payment service (stub): `http://localhost:6000`
* Postgres DBs exposed (optional): 5433..5437 on host

---

## Quick tests (health + example)

Health checks:

```bash
curl http://localhost:3000/healthz
curl http://localhost:4000/healthz
curl http://localhost:5000/healthz
curl http://localhost:6000/healthz
```

Example: list restaurants

```bash
curl "http://localhost:4000/v1/restaurants?limit=5"
```

Example: validate menu items

```bash
curl -X POST http://localhost:4000/v1/menu/validate -H "Content-Type: application/json" -d '{"item_ids":[1,2,3]}'
```

Example: place an order (replace Idempotency-Key with a unique string):

```bash
curl -X POST http://localhost:5000/v1/orders \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: my-unique-key-1" \
  -d '{"customer_id_ref":1,"restaurant_id_ref":1,"address_id_ref":1,"items":[{"item_id":1,"quantity":1}],"delivery_fee":20}'
```

Example: charge via payment-service (direct test)

```bash
curl -X POST http://localhost:6000/v1/payments/charge \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: pay-test-1" \
  -d '{"order_id":999,"amount":100,"method":"CARD"}'
```

---

## Useful Docker Compose commands

```bash
# show running containers
docker compose ps

# stream logs for a service
docker compose logs -f order-service

# rebuild a single service
docker compose build --no-cache order-service

# restart a single service
docker compose up -d --no-deps order-service
```

> Windows note: Use PowerShell or CMD; avoid Bash-specific quoting when running `docker compose exec ... psql -c "..."` commands.

---

## Troubleshooting (common issues & resolution)

1. **Service can't connect to DB (ECONNREFUSED to 127.0.0.1)**

   * Ensure `.env` and `docker-compose.yml` use service host names (e.g. `customer-db`, `restaurant-db`) — do **not** use `localhost` inside container.
   * Rebuild service images after `.env` changes.

2. **Migrator seeding fails: missing `created_at` column**

   * Ensure seed CSV headers match the COPY columns. The repository includes the correct CSV files. If you modified them, restore original headers.

3. **`relation ... does not exist` errors in logs**

   * Run `docker compose run --rm migrator` to reapply migrations.
   * Confirm `migrations/` contains the expected SQL files.

4. **Idempotency responses show `{ "idempotent": true, "items": [] }`**

   * This indicates an idempotency key exists but order/items were not committed. Use a new unique `Idempotency-Key` or delete the broken key from DB:

     ```bash
     docker compose exec order-db psql -U postgres -d order_db -c "DELETE FROM order_schema.idempotency_keys WHERE idempotency_key = 'THE_KEY';"
     ```

5. **Sequence / auto-increment issues**

   * If inserts return `null value in column ...` run the sequence wiring SQL (already applied in migrations). Example commands (Windows-friendly):

     ```bash
     docker compose exec order-db psql -U postgres -d order_db -c "CREATE SEQUENCE IF NOT EXISTS order_schema.orders_order_id_seq;"
     docker compose exec order-db psql -U postgres -d order_db -c "ALTER TABLE order_schema.orders ALTER COLUMN order_id SET DEFAULT nextval('order_schema.orders_order_id_seq');"
     ```

---

## Reproducibility notes (for the group / graders)

* All schema changes necessary for assignment (including idempotency tables and required sequences) are in `migrations/` and applied by the `migrator`.
* Seed CSVs used by the assignment are in `seed/` and mounted into the migrator so data is loaded automatically.
* If you clone the repo and run `docker compose up --build` on a clean machine it will create DBs, apply migrations, seed data, and start services.

---

## Minimal dev workflow (typical)

1. make code change (service/src/...)
2. rebuild that service:

   ```bash
   docker compose build --no-cache order-service
   docker compose up -d --no-deps order-service
   docker compose logs -f order-service
   ```
3. run test curl commands

---

## Contact / Notes for teammates

* If you hit any problems, share `docker compose ps` and `docker compose logs --tail=200 <service>` output — that’s the fastest way to diagnose.
* We kept the implementation strictly to the assignment requirements: no extra services or features beyond the required microservices, DB-per-service, idempotency, migrations and seeding.

