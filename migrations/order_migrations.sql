-- order_migrations.sql
CREATE SCHEMA IF NOT EXISTS order_schema;

CREATE TABLE IF NOT EXISTS order_schema.orders (
  order_id           BIGINT PRIMARY KEY,
  customer_id_ref    BIGINT NOT NULL, -- reference id only (no FK to other DB)
  restaurant_id_ref  BIGINT NOT NULL,
  address_id_ref     BIGINT NOT NULL,
  order_status       VARCHAR(50) NOT NULL, -- CREATED, CONFIRMED, CANCELLED, etc.
  order_total        NUMERIC(12,2) NOT NULL,
  payment_status     VARCHAR(50) NOT NULL, -- PENDING, SUCCESS, FAILED
  delivery_fee       NUMERIC(10,2) DEFAULT 0,
  tax_amount         NUMERIC(10,2) DEFAULT 0,
  created_at         TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_orders_customer_id_ref ON order_schema.orders (customer_id_ref);
CREATE INDEX IF NOT EXISTS ix_orders_restaurant_id_ref ON order_schema.orders (restaurant_id_ref);
CREATE INDEX IF NOT EXISTS ix_orders_status ON order_schema.orders (order_status);
CREATE INDEX IF NOT EXISTS ix_orders_payment_status ON order_schema.orders (payment_status);

CREATE TABLE IF NOT EXISTS order_schema.order_items (
  order_item_id    BIGINT PRIMARY KEY,
  order_id         BIGINT NOT NULL,
  item_id_ref      BIGINT NOT NULL, -- menu item id snapshot reference
  quantity         INTEGER NOT NULL CHECK (quantity > 0),
  price            NUMERIC(10,2) NOT NULL, -- price per unit at order time
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id)
    REFERENCES order_schema.orders (order_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_orderitems_order_id ON order_schema.order_items (order_id);
CREATE INDEX IF NOT EXISTS ix_orderitems_item_id_ref ON order_schema.order_items (item_id_ref);

CREATE TABLE IF NOT EXISTS order_schema.idempotency_keys (
  idempotency_key VARCHAR(255) PRIMARY KEY,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT now(),
  order_id        BIGINT
);

-- Ensure auto-increment for order_id and order_item_id (assignment-required)
CREATE SEQUENCE IF NOT EXISTS order_schema.orders_order_id_seq;
ALTER TABLE order_schema.orders ALTER COLUMN order_id SET DEFAULT nextval('order_schema.orders_order_id_seq');
ALTER SEQUENCE order_schema.orders_order_id_seq OWNED BY order_schema.orders.order_id;

CREATE SEQUENCE IF NOT EXISTS order_schema.order_items_order_item_id_seq;
ALTER TABLE order_schema.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('order_schema.order_items_order_item_id_seq');
ALTER SEQUENCE order_schema.order_items_order_item_id_seq OWNED BY order_schema.order_items.order_item_id;
-- End of order_migrations.sql