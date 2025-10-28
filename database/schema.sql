-- == SKEMA DATABASE GUDANG (WAREHOUSE) ==
--  PostgreSQL

-- --- Tipe Data Kustom (ENUMs) ---
CREATE TYPE movement_type_enum AS ENUM (
  'IN', 
  'OUT', 
  'TRANSFER', 
  'ADJUSTMENT', 
  'RETURN'
);

CREATE TYPE reference_type_enum AS ENUM (
  'PO', 
  'SO', 
  'TRANSFER', 
  'MANUAL'
);

CREATE TYPE order_status_enum AS ENUM (
  'PENDING', 
  'PROCESSING', 
  'SHIPPED', 
  'COMPLETED', 
  'CANCELLED'
);


-- --- 1. Tabel Master Data (Dimensi) ---

-- Tabel untuk nyimpen data gudang
CREATE TABLE warehouses (
  warehouse_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  location TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE warehouses IS 'Menyimpan daftar semua lokasi gudang';

-- Tabel untuk nyimpen data kategori
CREATE TABLE categories (
  category_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  parent_category_id INT REFERENCES categories(category_id), -- Untuk sub-kategori
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE categories IS 'Kategori produk (misal: Elektronik, Pakaian)';

-- Tabel untuk nyimpen data supplier
CREATE TABLE suppliers (
  supplier_id SERIAL PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  contact_info TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE suppliers IS 'Data pemasok barang';

-- Tabel untuk nyimpen data produk
CREATE TABLE products (
  product_id SERIAL PRIMARY KEY,
  sku VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  category_id INT REFERENCES categories(category_id),
  cost_price DECIMAL(10, 2) NOT NULL CHECK (cost_price >= 0),
  sale_price DECIMAL(10, 2) NOT NULL CHECK (sale_price >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE products IS 'Master data semua produk yang dijual';


-- --- 2. Tabel Inti Stok (Fakta) ---

-- Tabel untuk nyimpen STOK SAAT INI
CREATE TABLE stock (
  stock_id SERIAL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES products(product_id),
  warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id),
  quantity_on_hand INT NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  reorder_point INT DEFAULT 10,
  safety_stock INT DEFAULT 5,
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Pastikan 1 produk cuma ada 1 baris per gudang
  UNIQUE (product_id, warehouse_id)
);
COMMENT ON TABLE stock IS 'Snapshot stok saat ini per produk per gudang';

-- Tabel untuk nyimpen SEMUA PERGERAKAN
CREATE TABLE stock_movements (
  movement_id BIGSERIAL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES products(product_id),
  warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id),
  movement_type movement_type_enum NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0), -- Kuantitas selalu positif, tipe yg menentukan +/-
  movement_date TIMESTAMPTZ DEFAULT NOW(),
  reference_type reference_type_enum,
  reference_id INT,
  notes TEXT
);
COMMENT ON TABLE stock_movements IS 'Log audit semua pergerakan. Source of Truth.';


-- --- 3. Tabel Transaksi (Order) ---

CREATE TABLE purchase_orders (
  po_id SERIAL PRIMARY KEY,
  supplier_id INT NOT NULL REFERENCES suppliers(supplier_id),
  order_date DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_delivery_date DATE,
  status order_status_enum NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE purchase_orders IS 'Order pembelian ke supplier';

CREATE TABLE purchase_order_details (
  po_detail_id SERIAL PRIMARY KEY,
  po_id INT NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
  product_id INT NOT NULL REFERENCES products(product_id),
  quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
  unit_cost DECIMAL(10, 2) NOT NULL CHECK (unit_cost >= 0)
);
COMMENT ON TABLE purchase_order_details IS 'Detail barang per PO';

CREATE TABLE sales_orders (
  so_id SERIAL PRIMARY KEY,
  customer_name VARCHAR(150), -- Disederhanakan
  order_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status order_status_enum NOT NULL DEFAULT 'PENDING',
  shipping_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE sales_orders IS 'Order penjualan dari customer';

CREATE TABLE sales_order_details (
  so_detail_id SERIAL PRIMARY KEY,
  so_id INT NOT NULL REFERENCES sales_orders(so_id) ON DELETE CASCADE,
  product_id INT NOT NULL REFERENCES products(product_id),
  quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
  unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0)
);
COMMENT ON TABLE sales_order_details IS 'Detail barang per SO';


-- --- 4. Indexes untuk Performa Query ---
CREATE INDEX idx_products_category_id ON products (category_id);
CREATE INDEX idx_stock_product_warehouse ON stock (product_id, warehouse_id);
CREATE INDEX idx_movements_product_id ON stock_movements (product_id);
CREATE INDEX idx_movements_warehouse_id ON stock_movements (warehouse_id);
CREATE INDEX idx_movements_movement_date ON stock_movements (movement_date);
CREATE INDEX idx_movements_reference ON stock_movements (reference_type, reference_id);
CREATE INDEX idx_pod_po_id ON purchase_order_details (po_id);
CREATE INDEX idx_sod_so_id ON sales_order_details (so_id);
