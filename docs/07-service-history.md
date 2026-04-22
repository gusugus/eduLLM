# Servicio History

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/history.ts` (196 líneas)  
> **Relacionado con:** [02-database](./02-database.md) · [05-service-game](./05-service-game.md)

---

## Responsabilidad

`History` persiste y consulta el historial de **partidas completadas** en SQLite. También genera exportaciones CSV.

---

## Métodos

### `init()`
Alias de `Database.init()`. Llamado al arrancar el servidor.

### `addRun(managerId, run)`

Guarda una partida completada. Usa `INSERT OR REPLACE` por si se llama dos veces con el mismo ID (aunque en la práctica `persistHistory()` en `Game` lo previene con `historyRunId`).

```typescript
History.addRun(managerId, {
  id: string,           // UUID v4 generado por Game
  gameId: string,       // UUID de la instancia Game
  quizzId: string,      // ID del quiz usado
  subject: string,      // nombre del quiz
  startedAt: string,    // ISO timestamp del inicio
  endedAt: string,      // ISO timestamp del fin
  totalPlayers: number,
  questionCount: number,
  winner: string | null,  // username del 1er lugar
  leaderboard: [...],
  questions: [...]      // historial completo por pregunta
})
```

El objeto completo se serializa como JSON y se guarda en `payload_json`.

### `listRuns(managerId) → QuizRunHistorySummary[]`

Devuelve lista resumida, ordenada por `ended_at DESC` (más reciente primero).

```typescript
type QuizRunHistorySummary = {
  id: string
  gameId: string
  quizzId: string
  subject: string
  startedAt: string
  endedAt: string
  totalPlayers: number
  questionCount: number
  winner: string | null
}
```

### `getRun(managerId, runId) → QuizRunHistoryDetail | null`

Obtiene el detalle completo desde `payload_json`. Aplica `normalizeRun()` para compatibilidad con formato legacy.

```typescript
type QuizRunHistoryDetail = QuizRunHistorySummary & {
  leaderboard: QuizRunLeaderboardEntry[]
  questions: QuizRunQuestion[]
}
```

### `claimLegacyRuns(managerId)`

Asigna `manager_id` a todas las filas de `quiz_runs` donde `manager_id IS NULL`. Solo relevante durante la migración del primer admin.

---

## Exportación CSV: `exportCsv(managerId, runId)`

Genera un string CSV con **una fila por respuesta de cada jugador en cada pregunta**.

**Columnas:**
```
Quiz | Started At | Ended At | Question Number | Question |
Player | Answer Id | Answer Text | Correct Answer Ids |
Correct Answer Texts | Is Correct | Points Earned | Total Points | Final Rank
```

**Nombre del archivo generado:** `{subject-slug}-{runId}.csv`  
(ej: `historia-del-arte-abc123.csv`)

**Escape CSV:** Los valores se envuelven en comillas dobles y las comillas internas se duplican (`"` → `""`).

**El CSV se devuelve como string** — el servidor lo emite via Socket.IO al manager (`manager:historyExportReady`). El frontend lo descarga vía Blob + `<a download>`.

---

## Normalización de formato legacy: `normalizeRun()`

Versiones antiguas de MindBuzz guardaban:
```json
{ "correctAnswer": 1, "correctAnswerText": "Da Vinci" }
```

Versiones nuevas usan arrays:
```json
{ "correctAnswers": [1], "correctAnswerTexts": ["Da Vinci"] }
```

`normalizeRun()` convierte automáticamente el formato viejo al nuevo al leer del disco:

```typescript
const normalizeRun = (run: LegacyQuizRunHistoryDetail): QuizRunHistoryDetail => ({
  ...run,
  questions: run.questions.map(question => ({
    ...question,
    correctAnswers:
      question.correctAnswers ??
      (question.correctAnswer !== undefined ? [question.correctAnswer] : []),
    correctAnswerTexts:
      question.correctAnswerTexts ??
      (question.correctAnswerText ? [question.correctAnswerText] : []),
  })),
})
```
