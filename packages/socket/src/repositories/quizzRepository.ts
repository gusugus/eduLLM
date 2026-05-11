import { pgPool } from "../services/pgDatabase.js";
import { Quizz, QuizzWithId } from "@mindbuzz/common/types/game";

export class QuizzRepository {
  /**
   * Lista los quizzes de un profesor usando profesor.pruebas_listar y profesor.preguntas_listar
   */
  async listByProfessor(idUsuario: number): Promise<QuizzWithId[]> {
    const client = await pgPool.connect();
    try {
      // Usa la función profesor.pruebas_listar
      const res = await client.query(
        "SELECT * FROM profesor.pruebas_listar($1)",
        [idUsuario]
      );

      const quizzes: QuizzWithId[] = [];

      for (const row of res.rows) {
        // Usa la función profesor.preguntas_listar
        const questionsRes = await client.query(
          "SELECT * FROM profesor.preguntas_listar($1)",
          [row.id_prueba]
        );

        quizzes.push({
          id: row.id_prueba.toString(),
          subject: row.nombre_materia || "Sin materia",
          title: row.titulo,
          questions: questionsRes.rows.map(q => ({
            question: q.texto || "",
            answers: typeof q.opciones === "string"
              ? JSON.parse(q.opciones)
              : (q.opciones || []),
            solutions: [parseInt(q.respuesta_correcta) || 0],
            points: q.puntaje || 10,
            time: q.tiempo_limite || 20,
            cooldown: 5,
          }))
        });
      }

      return quizzes;
    } finally {
      client.release();
    }
  }

  /**
   * Crea un nuevo Quizz usando profesor.pruebas_crear y profesor.preguntas_agregar
   */
  async create(quizz: Quizz, idUsuario: number): Promise<string> {
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");

      // Crear la cabecera del quiz
      const pruebaRes = await client.query(
        "CALL profesor.pruebas_crear($1, $2, $3, $4, $5, NULL, NULL)",
        [quizz.subject, quizz.title, idUsuario, quizz.materiaId || null, JSON.stringify({})]
      );

      const idPrueba = pruebaRes.rows[0]?.pn_id_prueba;
      const errorPrueba = pruebaRes.rows[0]?.pv_error;
      if (errorPrueba) throw new Error(errorPrueba);

      // Agregar las preguntas usando profesor.preguntas_agregar
      for (const q of quizz.questions) {
        const resPregunta = await client.query(
          "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, NULL, NULL)",
          [
            idPrueba,
            q.question || "",
            JSON.stringify(q.answers || []),
            q.solutions?.[0] || 0,
            q.points || 10,
            q.time || 20,
          ]
        );

        const errorPregunta = resPregunta.rows[0]?.pv_error;
        if (errorPregunta) throw new Error(errorPregunta);
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
   * Actualiza un Quizz usando profesor.pruebas_editar y profesor.preguntas_agregar.
   * Las preguntas anteriores se marcan como 'ELI' (Soft Delete).
   */
  async update(idQuizz: string, quizz: Quizz): Promise<void> {
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");

      // Editar la cabecera del quiz usando profesor.pruebas_editar
      await client.query(
        "CALL profesor.pruebas_editar($1, $2, $3)",
        [parseInt(idQuizz), quizz.title, JSON.stringify({})]
      );

      // Desactivar preguntas anteriores (Soft Delete) usando procedimiento
      await client.query(
        "CALL profesor.preguntas_eliminar($1)",
        [parseInt(idQuizz)]
      );

      // Reinsertar las preguntas usando profesor.preguntas_agregar
      for (const q of quizz.questions) {
        const resPregunta = await client.query(
          "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, NULL, NULL)",
          [
            parseInt(idQuizz),
            q.question || "",
            JSON.stringify(q.answers || []),
            q.solutions?.[0] || 0,
            q.points || 10,
            q.time || 20,
          ]
        );

        const errorPregunta = resPregunta.rows[0]?.pv_error;
        if (errorPregunta) throw new Error(errorPregunta);
      }

      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async delete(idQuizz: string): Promise<void> {
    await pgPool.query(
      "CALL profesor.pruebas_eliminar($1)",
      [parseInt(idQuizz)]
    );
  }
}

export const quizzRepository = new QuizzRepository();
