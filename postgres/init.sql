-- E-commerce source schema for the Airbyte -> BigQuery -> Dataform pipeline

CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    city        VARCHAR(60),
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    category    VARCHAR(60),
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    id           SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(id),
    status       VARCHAR(20) NOT NULL,
    ordered_at   TIMESTAMP NOT NULL,
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INT NOT NULL REFERENCES orders(id),
    product_id  INT NOT NULL REFERENCES products(id),
    quantity    INT NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10, 2) NOT NULL,
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Keep updated_at current so Airbyte incremental sync picks up changes
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers   BEFORE UPDATE ON customers   FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_products    BEFORE UPDATE ON products    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_orders      BEFORE UPDATE ON orders      FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_order_items BEFORE UPDATE ON order_items FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- Sample data
INSERT INTO customers (full_name, email, city) VALUES
    ('Omar Hassan',   'omar@example.com',   'Cairo'),
    ('Mona Adel',     'mona@example.com',   'Alexandria'),
    ('Youssef Samir', 'youssef@example.com','Giza'),
    ('Sara Nabil',    'sara@example.com',   'Mansoura'),
    ('Karim Fathy',   'karim@example.com',  'Tanta');

INSERT INTO products (name, category, price) VALUES
    ('Wireless Mouse',      'Electronics', 350.00),
    ('Mechanical Keyboard', 'Electronics', 1800.00),
    ('Office Chair',        'Furniture',   4200.00),
    ('Water Bottle',        'Home',        150.00),
    ('Backpack',            'Fashion',     900.00);

-- 200 random orders over the last 90 days
INSERT INTO orders (customer_id, status, ordered_at)
SELECT
    1 + floor(random() * 5)::int,
    (ARRAY['completed','completed','completed','shipped','cancelled'])[1 + floor(random() * 5)::int],
    NOW() - (random() * INTERVAL '90 days')
FROM generate_series(1, 200);

-- 1-3 items per order
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.id, p.id, 1 + floor(random() * 3)::int, p.price
FROM orders o
CROSS JOIN LATERAL (
    SELECT id, price FROM products ORDER BY random() LIMIT 1 + floor(random() * 3)::int
) p;
