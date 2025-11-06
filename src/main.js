import express from "express";
import pkg from "pg";
import dotenv from "dotenv";
const app = express();
app.use(express.json());
dotenv.config();
const { Pool } = pkg;

// === PostgreSQL connection pool ===
const pool = new Pool({
  user: process.env.POSTGRES_USER || "postgres",
  password: process.env.POSTGRES_PASSWORD || "2491",
  host: process.env.POSTGRES_HOST || "localhost",
  port: process.env.POSTGRES_PORT || 5432,
  database: process.env.CUSTOMER_DB || "customer_db",
  max: 10,
});

async function waitForDb(retries = 10, delayMs = 2000) {
  for (let i = 0; i < retries; i++) {
    try {
      const client = await pool.connect();
      client.release();
      console.log("Database reachable");
      return;
    } catch (err) {
      console.log(
        `DB connect attempt ${
          i + 1
        }/${retries} failed — retrying in ${delayMs}ms`
      );
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw new Error("Unable to connect to DB after multiple attempts");
}

// --- Utility ---
async function runQuery(sql, params = []) {
  const client = await pool.connect();
  try {
    const res = await client.query(sql, params);
    return res.rows;
  } finally {
    client.release();
  }
}

// === Routes ===

// Health check
app.get("/healthz", (req, res) => res.json({ status: "ok" }));

// List all customers
app.get("/v1/customers", async (req, res) => {
  try {
    const rows = await runQuery(
      "SELECT customer_id, name, email, phone, created_at FROM customer_schema.customers ORDER BY customer_id;"
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch customers" });
  }
});

// Get customer by ID
app.get("/v1/customers/:id", async (req, res) => {
  try {
    const rows = await runQuery(
      "SELECT * FROM customer_schema.customers WHERE customer_id = $1",
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "Not found" });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch customer" });
  }
});

// Create customer
app.post("/v1/customers", async (req, res) => {
  const { name, email, phone } = req.body;
  try {
    const rows = await runQuery(
      "INSERT INTO customer_schema.customers (name, email, phone) VALUES ($1, $2, $3) RETURNING *",
      [name, email, phone]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Insert failed" });
  }
});

// === Address endpoints ===

// List addresses for a customer
app.get("/v1/customers/:id/addresses", async (req, res) => {
  try {
    const rows = await runQuery(
      "SELECT * FROM customer_schema.addresses WHERE customer_id = $1",
      [req.params.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch addresses" });
  }
});

// Add new address
app.post("/v1/customers/:id/addresses", async (req, res) => {
  const { line1, area, city, pincode } = req.body;
  try {
    const rows = await runQuery(
      `INSERT INTO customer_schema.addresses (customer_id, line1, area, city, pincode)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [req.params.id, line1, area, city, pincode]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Insert failed" });
  }
});

// start server only after DB ready
(async () => {
  try {
    await waitForDb(15, 2000); // 15 attempts, 2s interval

    // (insert your existing route definitions here, using runQuery)

    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () =>
      console.log(`Customer service running on port ${PORT}`)
    );
  } catch (err) {
    console.error("Failed to start server:", err);
    process.exit(1);
  }
})();
