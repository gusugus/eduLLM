
import { pgPool } from "../packages/socket/src/services/pgDatabase.js";

async function checkTable() {
  try {
    const res = await pgPool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'comun' AND table_name = 'info_partida'
      ORDER BY ordinal_position;
    `);
    console.log("Columns of INFO_PARTIDA:");
    console.table(res.rows);
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

checkTable();
