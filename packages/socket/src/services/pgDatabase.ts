import { Pool } from "pg";

// Create a connection pool to the edu_llm PostgreSQL database
export const pgPool = new Pool({
  host: process.env.PG_HOST || "localhost",
  port: Number(process.env.PG_PORT) || 5432,
  user: process.env.PG_USER || "admin",
  password: process.env.PG_PASSWORD || "admin", // Asumimos las credenciales que se ven en el SQL: "admin"
  database: process.env.PG_DATABASE || "edu_llm",
});

export async function initPg() {
  try {
    const client = await pgPool.connect();
    console.log("PostgreSQL connected successfully to edu_llm!");
    client.release();
  } catch (err) {
    console.error("Failed to connect to PostgreSQL:", err);
  }
}
