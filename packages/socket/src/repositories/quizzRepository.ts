import { Quizz, QuizzWithId } from "@mindbuzz/common/types/game";
import { pgPool } from "../services/pgDatabase.js";

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
            id: q.id_pregunta,
            question: q.texto || "",
            answers: typeof q.opciones === "string"
              ? JSON.parse(q.opciones)
              : (q.opciones || []),
            solutions: [parseInt(q.respuesta_correcta) || 0],
            time: q.tiempo_limite || 20,
            cooldown: q.cooldown || 5,
            image: q.image_url || undefined,
            audio: q.audio_url || undefined,
            video: q.video_url || undefined,
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
    console.log(`[QuizzRepository] Creando cuestionario: ${quizz.title}`);
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");
      // Crear la cabecera del quiz
      const pruebaRes = await client.query(
        "CALL profesor.pruebas_crear($1, $2, $3, $4, $5, NULL, NULL)",
        [quizz.title, quizz.subject, idUsuario, quizz.materiaId || null, JSON.stringify({})]
      );

      const idPrueba = pruebaRes.rows[0]?.pn_id_prueba;
      const errorPrueba = pruebaRes.rows[0]?.pv_error;
      if (errorPrueba) throw new Error(errorPrueba);

      // Agregar las preguntas usando profesor.preguntas_agregar
      for (const q of quizz.questions) {
        const options = (q.answers || []).map((text, index) => ({
          texto: text,
          correcta: (q.solutions || []).includes(index)
        }));

        const resPregunta = await client.query(
          "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, $7, $8, NULL, NULL)",
          [
            idPrueba,
            q.question || "",
            JSON.stringify(options),
            q.cooldown || 5,
            q.time || 20,
            q.image || null,
            q.audio || null,
            q.video || null,
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
    const idPrueba = parseInt(idQuizz);
    console.log(`[QuizzRepository] Actualizando cuestionario ID: ${idQuizz}. Preguntas a procesar: ${quizz.questions.length}`);
    const client = await pgPool.connect();
    try {
      await client.query("BEGIN");

      // 1. Editar la cabecera del quiz
      console.log(`[QuizzRepository] Sobrescribiendo cabecera de quiz ID: ${idPrueba}`);
      await client.query(
        "CALL profesor.pruebas_editar($1, $2, $3)",
        [idPrueba, quizz.title, JSON.stringify({})]
      );

      // 2. Obtener IDs de preguntas actuales en la base de datos para este quiz
      const currentQuestionsRes = await client.query(
        "SELECT id_pregunta FROM comun.INFO_PREGUNTA WHERE id_prueba = $1 AND id_estado = comun.obtener_id_estado_activo()",
        [idPrueba]
      );
      const dbQuestionIds = currentQuestionsRes.rows.map(r => r.id_pregunta);
      const incomingQuestionIds = quizz.questions.filter(q => q.id).map(q => q.id);

      console.log(`[QuizzRepository] Preguntas en DB: [${dbQuestionIds}], Preguntas entrantes con ID: [${incomingQuestionIds}]`);

      // 3. Procesar cada pregunta recibida del frontend
      for (const q of quizz.questions) {
        const options = (q.answers || []).map((text, index) => ({
          texto: text,
          correcta: (q.solutions || []).includes(index)
        }));

        if (q.id) {
          // SOBREESCRIBIR (EDITAR)
          console.log(`[QuizzRepository] SOBREESCRIBIENDO pregunta ID: ${q.id}`);
          const res = await client.query(
            "CALL profesor.preguntas_editar($1, $2, $3, $4, $5, $6, $7, $8, NULL)",
            [q.id, q.question || "", JSON.stringify(options), q.cooldown || 5, q.time || 20, q.image || null, q.audio || null, q.video || null]
          );
          const errorPregunta = res.rows[0]?.pv_error;
          if (errorPregunta) throw new Error(errorPregunta);
        } else {
          // INSERTAR NUEVA
          console.log(`[QuizzRepository] INSERTANDO nueva pregunta para quiz ID: ${idPrueba}`);
          const resPregunta = await client.query(
            "CALL profesor.preguntas_agregar($1, $2, $3, $4, $5, $6, $7, $8, NULL, NULL)",
            [
              idPrueba,
              q.question || "",
              JSON.stringify(options),
              q.cooldown || 5,
              q.time || 20,
              q.image || null,
              q.audio || null,
              q.video || null,
            ]
          );
          const errorPregunta = resPregunta.rows[0]?.pv_error;
          if (errorPregunta) throw new Error(errorPregunta);
        }
      }

      // 4. ELIMINACIÓN LÓGICA de las preguntas que ya no están en el borrador
      const idsToDelete = dbQuestionIds.filter(id => !incomingQuestionIds.includes(id));
      for (const id of idsToDelete) {
        console.log(`[QuizzRepository] ELIMINANDO LÓGICAMENTE pregunta ID: ${id}`);
        await client.query(
          "CALL profesor.pregunta_eliminar_individual($1)",
          [id]
        );
      }

      await client.query("COMMIT");
      console.log(`[QuizzRepository] Transacción completada con éxito para quiz ID: ${idPrueba}`);
    } catch (e) {
      await client.query("ROLLBACK");
      console.error(`[QuizzRepository] Error en update: ${e instanceof Error ? e.message : String(e)}`);
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
