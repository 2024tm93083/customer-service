-- payment_migrations.sql
CREATE SCHEMA IF NOT EXISTS payment_schema;

CREATE TABLE IF NOT EXISTS payment_schema.payments (
  payment_id     BIGINT PRIMARY KEY,
  order_id       BIGINT NOT NULL, -- order reference
  amount         NUMERIC(12,2) NOT NULL,
  method         VARCHAR(50) NOT NULL, -- COD / CARD / UPI / WALLET
  status         VARCHAR(50) NOT NULL, -- PENDING / SUCCESS / FAILED / REFUNDED
  reference      VARCHAR(255),
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_payments_order_id ON payment_schema.payments (order_id);
CREATE INDEX IF NOT EXISTS ix_payments_status ON payment_schema.payments (status);
CREATE INDEX IF NOT EXISTS ix_payments_method ON payment_schema.payments (method);

-- idempotency key store for write endpoints
CREATE TABLE IF NOT EXISTS payment_schema.idempotency_keys (
  idempotency_key  VARCHAR(255) PRIMARY KEY,
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT now(),
  response_snapshot JSONB
);

CREATE INDEX IF NOT EXISTS ix_idempotency_created_at ON payment_schema.idempotency_keys (created_at);
