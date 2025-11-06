-- delivery_migrations.sql
CREATE SCHEMA IF NOT EXISTS delivery_schema;

CREATE TABLE IF NOT EXISTS delivery_schema.drivers (
  driver_id     BIGINT PRIMARY KEY,
  name          VARCHAR(255) NOT NULL,
  phone         VARCHAR(50),
  vehicle_type  VARCHAR(50),
  is_active     BOOLEAN DEFAULT true,
  city          VARCHAR(128), -- useful to match deliveries to driver city
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_drivers_city ON delivery_schema.drivers (city);
CREATE INDEX IF NOT EXISTS ix_drivers_active ON delivery_schema.drivers (is_active);

CREATE TABLE IF NOT EXISTS delivery_schema.deliveries (
  delivery_id    BIGINT PRIMARY KEY,
  order_id       BIGINT NOT NULL,
  driver_id      BIGINT,
  status         VARCHAR(50) NOT NULL, -- ASSIGNED / PICKED / DELIVERED / CANCELLED
  assigned_at    TIMESTAMP WITH TIME ZONE,
  picked_at      TIMESTAMP WITH TIME ZONE,
  delivered_at   TIMESTAMP WITH TIME ZONE,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_deliveries_order_id ON delivery_schema.deliveries (order_id);
CREATE INDEX IF NOT EXISTS ix_deliveries_driver_id ON delivery_schema.deliveries (driver_id);
CREATE INDEX IF NOT EXISTS ix_deliveries_status ON delivery_schema.deliveries (status);
