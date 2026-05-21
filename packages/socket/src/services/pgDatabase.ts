import { Pool } from "pg"

// Create a connection pool to the edu_llm PostgreSQL database
export const pgPool = new Pool({
  host: process.env.PG_HOST || "localhost",
  port: Number(process.env.PG_PORT) || 5432,
  user: process.env.PG_USER || "admin",
  password: process.env.PG_PASSWORD || "admin", 
  database: process.env.PG_DATABASE || "edullm",
  max: 4, 
})

export async function initPg() {
  try {
    const client = await pgPool.connect()
    console.log("PostgreSQL connected successfully to edullm!")
    // eslint-disable-next-line semi
    client.release();
  } catch (err) {
    console.error("Failed to connect to PostgreSQL:", err)
  }
}
