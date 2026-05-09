import { pgPool } from "../services/pgDatabase.js";
import { Quizz, QuizzWithId } from "@mindbuzz/common/types/game";

export class QuizzRepository {
  /**
   * Lista los quizzes de un profesor desde Postgres
   */
  async listByProfessor(idProfesor: number): Promise<QuizzWithId[]> {
    const client = await pgPool.connect();
    try {
      const query = `
        SELECT 
          id_prueba as id,
          titulo as subject,
          descripcion,
          configuracion as settings
        FROM comun.INFO_PRUEBA
        WHERE id_profesor = $1 AND id_estado = (SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ACT')
      `;
      const res = await client.query(query, [idProfesor]);
      
      const quizzes: QuizzWithId[] = [];
      
      for (const row of res.rows) {
        const questionsRes = await client.query(
          `SELECT texto as text, opciones as options, respuesta_correcta as "correctAnswer", 
                  puntaje as points, tiempo_limite as duration
           FROM comun.INFO_PREGUNTA 
           WHERE id_prueba = $1`,
          [row.id]
        );
        
        quizzes.push({
          id: row.id.toString(),
          subject: row.subject,
          questions: questionsRes.rows.map(q => ({
            ...q,
            options: typeof q.options === 'string' ? JSON.parse(q.options) : q.options
          }))
        });
      }
      
      return quizzes;
    } finally {
      client.release();
    }
  }

  /**
   * Crea un nuevo Quizz en la base de datos
   */
  async create(quizz: Quizz, idProfesor: number): Promise<string> {
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");

      // Usamos CALL para procedimientos con parámetros INOUT/OUT
      // Nota: En PostgreSQL 11+, CALL devuelve los parámetros OUT como una fila de resultados
      const pruebaRes = await client.query(
        "CALL profesor.pruebas_crear($1, $2, $3, $4, $5, NULL, NULL)",
        [quizz.subject, "Creado desde panel", idProfesor, null, JSON.stringify({})]
      );
      
      const idPrueba = pruebaRes.rows[0].pn_id_prueba;
      const error = pruebaRes.rows[0].pv_error;

      if (error) throw new Error(error);

      // Agregar las preguntas
      for (const q of quizz.questions) {
        await client.query(
          "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, NULL)",
          [idPrueba, q.text, JSON.stringify(q.options), q.correctAnswer, q.points || 10, q.duration || 20]
        );
      }

      await client.query("COMMIT");
      return idPrueba.toString();
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  /**
   * Actualiza un Quizz existente
   */
  async update(idQuizz: string, quizz: Quizz): Promise<void> {
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");

      await client.query(
        "UPDATE comun.INFO_PRUEBA SET titulo = $1, configuracion = $2 WHERE id_prueba = $3",
        [quizz.subject, JSON.stringify({}), parseInt(idQuizz)]
      );

      await client.query("DELETE FROM comun.INFO_PREGUNTA WHERE id_prueba = $1", [parseInt(idQuizz)]);

      for (const q of quizz.questions) {
        await client.query(
          "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, NULL)",
          [parseInt(idQuizz), q.text, JSON.stringify(q.options), q.correctAnswer, q.points || 10, q.duration || 20]
        );
      }

      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  /**
   * Elimina un Quizz
   */
  async delete(idQuizz: string): Promise<void> {
    await pgPool.query(
      "UPDATE comun.INFO_PRUEBA SET id_estado = (SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ELI') WHERE id_prueba = $1",
      [parseInt(idQuizz)]
    );
  }
}

export const quizzRepository = new QuizzRepository();
