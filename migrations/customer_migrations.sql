-- customer_migrations.sql
CREATE SCHEMA IF NOT EXISTS customer_schema;

-- customers table
CREATE TABLE IF NOT EXISTS customer_schema.customers (
  customer_id    BIGINT PRIMARY KEY,
  name           VARCHAR(255)          NOT NULL,
  email          VARCHAR(255),
  phone          VARCHAR(50),
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_email ON customer_schema.customers (email) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_phone ON customer_schema.customers (phone) WHERE phone IS NOT NULL;

-- addresses table (separate table)
CREATE TABLE IF NOT EXISTS customer_schema.addresses (
  address_id     BIGINT PRIMARY KEY,
  customer_id    BIGINT NOT NULL,
  line1          VARCHAR(512),
  area           VARCHAR(255),
  city           VARCHAR(128),
  pincode        VARCHAR(20),
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT fk_address_customer
    FOREIGN KEY (customer_id)
    REFERENCES customer_schema.customers (customer_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_addresses_customer_id ON customer_schema.addresses (customer_id);
CREATE INDEX IF NOT EXISTS ix_addresses_city ON customer_schema.addresses (city);
