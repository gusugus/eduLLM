import { pgPool } from "../services/pgDatabase.js";

export interface Materia {
  id: number;
  nombre: string;
}

export class MateriaRepository {
  async listByProfessor(idUsuario: number): Promise<Materia[]> {
    console.log(`[MateriaRepo] Listando materias para usuario ID: ${idUsuario}`);
    try {
      const res = await pgPool.query("SELECT * FROM profesor.materias_por_usuario($1)", [idUsuario]);
      
      console.log(`[MateriaRepo] Filas recuperadas: ${res.rowCount}`);

      const materias = res.rows.map(row => ({
        id: row.id_materia,
        nombre: row.nombre || "Sin nombre"
      }));
      
      console.log("[MateriaRepo] Materias procesadas:", materias);
      return materias;
    } catch (e) {
      console.error("[MateriaRepo] ERROR crítico listando materias:", e);
      return []; 
    }
  }
}

export const materiaRepository = new MateriaRepository();
