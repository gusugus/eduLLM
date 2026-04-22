# Base de Datos — SQLite

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/database.ts`  
> **Relacionado con:** [04-service-accountstore](./04-service-accountstore.md) · [07-service-history](./07-service-history.md) · [08-service-oidc](./08-service-oidc.md)

---

## Tecnología

MindBuzz usa **SQLite** a través de la API nativa de **Node.js 24** (`node:sqlite`). No requiere drivers externos ni instalar `better-sqlite3` — es parte del runtime.

Toda la interacción con la base de datos pasa por el singleton `Database`, que expone la instancia de `DatabaseSync`.

---

## Ubicación del archivo

| Entorno | Ruta del archivo `history.db` |
|---------|-------------------------------|
| Desarrollo (CWD = `packages/socket/`) | `../../config/history.db` → `MindBuzz/config/history.db` |
| Docker (`CONFIG_PATH=/app/config`) | `/app/config/history.db` |

El directorio se crea automáticamente si no existe.

---

## Singleton `Database`

**Archivo:** `packages/socket/src/services/database.ts`

```typescript
class Database {
  private static db: DatabaseSync | null = null  // instancia única

  static getDb(): DatabaseSync   // crea si no existe, inicializa schema
  static init(): void            // alias de getDb(), llamado al arrancar
}
```

El singleton se inicializa una sola vez y se reutiliza en toda la aplicación. Todos los servicios (`AccountStore`, `History`, `OidcStore`) llaman a `Database.getDb()`.

**PRAGMA activado:** `PRAGMA foreign_keys = ON` — las foreign keys están **siempre activas**.

**Modo STRICT:** Todas las tablas usan `STRICT` — SQLite verifica los tipos de columna.

---

## Tablas

### `managers`

Almacena las cuentas de los usuarios que administran partidas.

```sql
CREATE TABLE managers (
  id            TEXT PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('admin', 'manager')),
  disabled_at   TEXT,              -- ISO timestamp o NULL (NULL = activo)
  created_at    TEXT NOT NULL,     -- ISO timestamp
  updated_at    TEXT NOT NULL
) STRICT
```

| Columna | Tipo | Notas |
|---------|------|-------|
| `id` | UUID v4 | Generado con la librería `uuid` |
| `username` | string | Case-insensitive (COLLATE NOCASE); 4-20 chars |
| `password_hash` | string | Formato `salt:hash`; `scrypt` con salt de 16 bytes |
| `role` | `'admin'` o `'manager'` | Solo estos dos valores |
| `disabled_at` | ISO timestamp / NULL | Si tiene valor, el login queda bloqueado |

---

### `manager_settings`

Configuración personal de cada manager (una fila por manager).

```sql
CREATE TABLE manager_settings (
  manager_id    TEXT PRIMARY KEY,
  default_audio TEXT,              -- URL de audio o NULL
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE
) STRICT
```

| Columna | Notas |
|---------|-------|
| `default_audio` | URL `/media/archivo.mp3` o `https://...`; NULL si no configurado |

---

### `quizzes`

Almacena los quizzes de cada manager. El contenido completo se guarda como JSON.

```sql
CREATE TABLE quizzes (
  id           TEXT PRIMARY KEY,   -- UUID v4
  manager_id   TEXT NOT NULL,
  subject      TEXT NOT NULL,       -- nombre del quiz (para búsquedas sin parsear JSON)
  payload_json TEXT NOT NULL,       -- JSON serializado del objeto Quizz completo
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE
) STRICT
```

**Estructura del `payload_json`:**
```json
{
  "subject": "Historia del Arte",
  "questions": [
    {
      "question": "¿Quién pintó la Mona Lisa?",
      "answers": ["Picasso", "Da Vinci", "Monet", "Dalí"],
      "solutions": [1],
      "cooldown": 5,
      "time": 20,
      "image": "https://...",
      "audio": "/media/pregunta.mp3",
      "video": "https://..."
    }
  ]
}
```

---

### `manager_oidc_identities`

Vincula cuentas de managers locales con identidades de proveedores OIDC (SSO).

```sql
CREATE TABLE manager_oidc_identities (
  id             TEXT PRIMARY KEY,  -- UUID v4
  manager_id     TEXT NOT NULL,
  issuer         TEXT NOT NULL,     -- URL del proveedor (ej: "https://accounts.google.com")
  subject        TEXT NOT NULL,     -- "sub" claim del JWT del proveedor
  email          TEXT,
  username_claim TEXT,              -- "preferred_username" del proveedor
  last_login_at  TEXT,              -- ISO timestamp del último login
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE,
  UNIQUE (issuer, subject)          -- un manager no puede tener dos identidades
) STRICT                            -- del mismo proveedor
```

Permite que un manager tenga múltiples identidades SSO (ej: Google + Okta).

---

### `quiz_runs`

Historial de partidas completadas.

```sql
CREATE TABLE quiz_runs (
  id             TEXT PRIMARY KEY,    -- UUID v4
  game_id        TEXT NOT NULL,       -- UUID de la instancia de Game
  quizz_id       TEXT NOT NULL,       -- ID del quiz usado
  subject        TEXT NOT NULL,       -- nombre del quiz al momento del juego
  started_at     TEXT NOT NULL,       -- ISO timestamp
  ended_at       TEXT NOT NULL,       -- ISO timestamp
  total_players  INTEGER NOT NULL,
  question_count INTEGER NOT NULL,
  winner         TEXT,                -- username del 1er lugar o NULL
  payload_json   TEXT NOT NULL,       -- QuizRunHistoryDetail completo serializado
  manager_id     TEXT                 -- NULL en registros legacy
) STRICT
```

**El `payload_json` contiene el historial completo:**
```json
{
  "id": "...",
  "subject": "...",
  "leaderboard": [{ "playerId": "...", "rank": 1, "username": "...", "points": 850 }],
  "questions": [
    {
      "questionNumber": 1,
      "question": "...",
      "answers": ["..."],
      "correctAnswers": [1],
      "correctAnswerTexts": ["Da Vinci"],
      "responses": [
        {
          "playerId": "...",
          "username": "...",
          "answerId": 1,
          "answerText": "Da Vinci",
          "isCorrect": true,
          "points": 743,
          "totalPoints": 743
        }
      ]
    }
  ]
}
```

---

## Índices

```sql
CREATE INDEX idx_quizzes_manager_id
  ON quizzes(manager_id)

CREATE INDEX idx_quiz_runs_manager_id
  ON quiz_runs(manager_id)

CREATE INDEX idx_manager_oidc_identities_manager_id
  ON manager_oidc_identities(manager_id)
```

Todos los índices aceleran las consultas por `manager_id`, que es la forma más común de filtrar datos.

---

## Migraciones

MindBuzz no usa un sistema de migraciones formal. En su lugar, `initializeSchema()` usa:

1. **`CREATE TABLE IF NOT EXISTS`** → crea tablas solo si no existen
2. **`ensureColumn()`** → agrega columnas si no están presentes:

```typescript
private static ensureColumn(db, table, column, definition) {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all()
  if (columns.some(item => item.name === column)) return
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`)
}
```

Actualmente se usa para agregar `manager_id` en `quiz_runs` (columna añadida en versión reciente).

**Para agregar una columna nueva:** añade `ensureColumn(db, "tabla", "columna", "TEXT")` en `initializeSchema()`.  
**Para una tabla nueva:** añade `CREATE TABLE IF NOT EXISTS` en el mismo método.

---

## Relaciones entre tablas

```
managers (1) ──── (N) manager_settings
managers (1) ──── (N) quizzes
managers (1) ──── (N) manager_oidc_identities
managers (1) ──── (N) quiz_runs  (via manager_id, nullable)
```

Todas las foreign keys tienen `ON DELETE CASCADE`: si se borra un manager, se borran sus quizzes, configuraciones e identidades automáticamente.

---

## Notas importantes

- La base de datos es **síncrona** (`DatabaseSync`) — no usa Promises ni async/await
- SQLite no tiene servidor propio; el archivo es bloqueado por el proceso Node.js
- No hay pool de conexiones — una sola conexión global para todo el backend
- Todos los timestamps se almacenan como **ISO 8601 strings** (ej: `"2026-04-20T20:00:00.000Z"`)
- Los UUIDs se generan con la librería `uuid` (v4 para entidades, excepto `clientId` del navegador que es v7)
