-- restaurant_migrations.sql
CREATE SCHEMA IF NOT EXISTS restaurant_schema;

CREATE TABLE IF NOT EXISTS restaurant_schema.restaurants (
  restaurant_id  BIGINT PRIMARY KEY,
  name           VARCHAR(255) NOT NULL,
  cuisine        VARCHAR(128),
  city           VARCHAR(128),
  rating         NUMERIC(3,2),
  is_open        BOOLEAN DEFAULT true,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_restaurants_city ON restaurant_schema.restaurants (city);
CREATE INDEX IF NOT EXISTS ix_restaurants_cuisine ON restaurant_schema.restaurants (cuisine);

CREATE TABLE IF NOT EXISTS restaurant_schema.menu_items (
  item_id        BIGINT PRIMARY KEY,
  restaurant_id  BIGINT NOT NULL,
  name           VARCHAR(512) NOT NULL,
  category       VARCHAR(128),
  price          NUMERIC(10,2) NOT NULL,
  is_available   BOOLEAN DEFAULT true,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT fk_menu_restaurant
    FOREIGN KEY (restaurant_id)
    REFERENCES restaurant_schema.restaurants (restaurant_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_menu_restaurant_id ON restaurant_schema.menu_items (restaurant_id);
CREATE INDEX IF NOT EXISTS ix_menu_category ON restaurant_schema.menu_items (category);
CREATE INDEX IF NOT EXISTS ix_menu_price ON restaurant_schema.menu_items (price);
