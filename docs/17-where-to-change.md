# Guía Práctica: Dónde Hacer Cambios

> **Parte de:** [Índice](./INDEX.md)  
> Este archivo es el punto de partida cuando sabes **qué** quieres cambiar pero no **dónde** tocarlo.

---

## Lógica del juego

### Cambiar la fórmula de puntuación

**Archivo:** `packages/socket/src/utils/game.ts`  
**Función:** `timeToPoint(startTime, seconds)`  
**Lectura previa:** [15-scoring-timings](./15-scoring-timings.md)

### Cambiar la duración de la cuenta regresiva inicial (3 segundos)

**Archivo:** `packages/socket/src/services/game.ts`  
**Método:** `start()` → `sleep(3)`

### Cambiar la duración de la pausa "SHOW_PREPARED" (2 segundos)

**Archivo:** `packages/socket/src/services/game.ts`  
**Método:** `newRound()` → `sleep(2)`

### Cambiar el tiempo de gracia para reconexión del jugador (60s)

**Archivo:** `packages/socket/src/services/game.ts`  
**Constante:** `PLAYER_RECONNECT_GRACE_MS`

### Cambiar el tiempo de limpieza de partidas vacías (5 min)

**Archivo:** `packages/socket/src/services/registry.ts`  
**Constante:** `EMPTY_GAME_TIMEOUT_MINUTES`

---

## Quizzes y Preguntas

### Agregar un campo nuevo a las preguntas (ej: campo "hint")

1. **`packages/common/src/types/game/index.ts`** → `QuizzQuestion`: agrega `hint?: string`
2. **`packages/socket/src/services/quizz.ts`** → `normalizeQuizz()`: incluye el campo al construir la pregunta normalizada
3. **`packages/socket/src/services/game.ts`** → `newRound()`: incluye el campo en los datos emitidos (`SHOW_QUESTION` o `SELECT_ANSWER`)
4. **`packages/common/src/types/game/status.ts`** → el `StatusDataMap` del estado correspondiente
5. **`packages/web/src/features/game/components/states/`** → el componente que lo muestra

### Cambiar los límites de validación (mín/máx respuestas, etc.)

**Archivo:** `packages/socket/src/services/quizz.ts`  
**Función:** `normalizeQuizz()`  
**Lectura previa:** El archivo tiene comentarios describiendo cada validación.

### Cambiar el quiz de ejemplo inicial

**Archivo:** `packages/socket/src/services/config.ts`  
**Método:** `init()` → bloque que crea `example.json`

### Cambiar la pregunta de ejemplo al crear un quiz nuevo

**Archivo:** `packages/socket/src/services/accountStore.ts`  
**Método:** `createQuizz()`

---

## Base de Datos

### Agregar una columna a una tabla existente

**Archivo:** `packages/socket/src/services/database.ts`  
**Método:** `initializeSchema()`  
**Pasos:**
1. NO modificar el `CREATE TABLE` existente (rompería instancias existentes)
2. Agregar: `ensureColumn(db, "managers", "nueva_columna", "TEXT")`
3. Si la columna tiene un valor default: `ensureColumn(db, "tabla", "col", "TEXT DEFAULT 'valor'")`

### Agregar una tabla nueva

**Archivo:** `packages/socket/src/services/database.ts`  
**Método:** `initializeSchema()`  
**Pasos:**
1. Agregar `CREATE TABLE IF NOT EXISTS nueva_tabla (...) STRICT`
2. Crear un nuevo servicio (ej: `packages/socket/src/services/newStore.ts`) que use `Database.getDb()`

### Cambiar cómo se ordenan los managers en la lista

**Archivo:** `packages/socket/src/services/accountStore.ts`  
**Método:** `listManagers()`

---

## Autenticación

### Cambiar el algoritmo de hashing de contraseñas

**Archivo:** `packages/socket/src/services/accountStore.ts`  
**Funciones:** `hashPassword()` y `verifyPassword()`  
⚠️ Cambiar esto invalida todas las contraseñas existentes en la BD.

### Agregar un nuevo rol

1. **`packages/common/src/types/game/index.ts`** → `ManagerRole`: agrega el nuevo rol al union type
2. **`packages/socket/src/services/database.ts`** → `CREATE TABLE managers`: actualiza el CHECK constraint  
   *(Pero CHECK en SQLite no se puede alterar sin recrear la tabla)*
3. **`packages/socket/src/index.ts`** → crea helper `requireNewRole(socket)` similar a `requireAdminManager`
4. **`packages/web/src/pages/game/auth/manager/page.tsx`** → agrega tab/funcionalidad según el rol

### Hacer que las sesiones de manager persistan entre reinicios

**Archivo:** `packages/socket/src/index.ts`  
**Variable actual:** `const authenticatedManagers = new Map<string, ManagerSession>()`  
**Cambio:** Reemplazar por una tabla SQLite con `session_id` (clientId), `manager_id`, `expires_at`.

### Verificar la firma del JWT en OIDC

**Archivo:** `packages/socket/src/services/oidcAuth.ts`  
**Método:** `validateIdToken()`  
**Dependencia a agregar:** `jose` o `jsonwebtoken` con soporte de JWKS.

---

## Eventos WebSocket

### Agregar un evento nuevo del CLIENTE al SERVIDOR

1. **`packages/common/src/types/game/socket.ts`** → `ClientToServerEvents`: agrega el evento y su tipo
2. **`packages/socket/src/index.ts`** → dentro de `io.on("connection", ...)`: agrega `socket.on("mi:evento", handler)`

### Agregar un evento nuevo del SERVIDOR al CLIENTE

1. **`packages/common/src/types/game/socket.ts`** → `ServerToClientEvents`: agrega el evento y su tipo
2. **En el backend:** emite el evento con `socket.emit("mi:evento", data)` o `io.to(gameId).emit(...)`
3. **En el frontend:** usa `useEvent("mi:evento", callback)` en el componente que lo procesa

---

## UI (Frontend)

### Cambiar lo que ve el jugador al responder

**Archivo:** `packages/web/src/features/game/components/states/Answers.tsx`

### Cambiar el podio final

**Archivo:** `packages/web/src/features/game/components/states/Podium.tsx`

### Cambiar los colores de los botones de respuesta

**Archivo:** `packages/web/src/features/game/utils/constants.ts`  
**Constante:** `ANSWERS_COLORS`

### Agregar una pantalla nueva al flujo del juego

1. **`packages/common/src/types/game/status.ts`** → agrega el STATUS al enum y a `StatusDataMap`
2. **`packages/web/src/features/game/components/states/`** → crea el componente `MiEstado.tsx`
3. **`packages/web/src/features/game/utils/constants.ts`** → agrega al mapa `GAME_STATE_COMPONENTS` o `GAME_STATE_COMPONENTS_MANAGER`
4. **`packages/socket/src/services/game.ts`** → emite el STATUS en el momento correcto

### Agregar un tab al dashboard del manager

**Archivo:** `packages/web/src/pages/game/auth/manager/page.tsx`  
**Constantes:** `BASE_TABS` (visible para todos) o `ADMIN_TAB` / `ADMIN_SSO_TAB` (solo admins)

### Cambiar los sonidos

**Archivo:** `packages/web/src/features/game/utils/constants.ts` → constantes `SFX_*`  
**Archivos de audio:** `packages/web/public/sounds/` → reemplaza los archivos .mp3

### Agregar soporte para un nuevo tipo de media en las preguntas

1. Agrega el campo en `QuizzQuestion` (ver sección de quizzes arriba)
2. El componente `Question.tsx` o `Answers.tsx` debe renderizarlo

---

## Configuración e Infraestructura

### Cambiar el puerto del backend

**Archivo:** `packages/socket/src/index.ts` → constante `WS_PORT`  
**También:** `packages/web/vite.config.ts` → targets del proxy (`"http://localhost:3001"`)

### Cambiar el puerto del frontend

**Archivo:** `packages/web/vite.config.ts` → `server.port`  
**En Docker:** `Dockerfile` → `EXPOSE` y `compose.yml` → `ports`

### Agregar una nueva variable de entorno

1. Agrega al archivo `.env` en la raíz del proyecto
2. Accede en el código con `process.env.NOMBRE_VARIABLE`
3. **Solo disponible en el backend** (el frontend usa Vite, que tiene su propio sistema con `import.meta.env`)

### Agregar soporte para un nuevo formato de audio en `/media/`

**Archivo:** `packages/socket/src/index.ts`  
**Objeto:** `mimeTypes` dentro del handler de `GET /media/`

```typescript
const mimeTypes: Record<string, string> = {
  ".aac": "audio/aac",
  ".mp3": "audio/mpeg",
  // → agrega aquí tu nuevo formato
  ".flac": "audio/flac",
}
```

---

## Datos y Migración

### Migrar quizzes legacy del filesystem a SQLite manualmente

El proceso ocurre automáticamente cuando no hay managers en la BD (primera instalación). Si necesitas forzarlo, mira `AccountStore.migrateLegacyResources(managerId)`.

### Reclamar historial legacy sin manager_id

```typescript
History.claimLegacyRuns(managerId)
// Asigna todos los quiz_runs con manager_id NULL al managerId dado
```

---

## Checklist al agregar un campo nuevo (end-to-end)

```
□ Agregar al tipo en packages/common/src/types/game/index.ts
□ Agregar al StatusDataMap si afecta el estado del juego
□ Agregar al schema de la BD si se persiste (database.ts → ensureColumn)
□ Actualizar el servicio que lee/escribe el dato (accountStore, game, etc.)
□ Actualizar la validación en quizz.ts si es un campo del quiz
□ Actualizar el evento WebSocket correspondiente (emitir el nuevo campo)
□ Actualizar el componente React que lo muestra
□ Actualizar el editor del manager si es editable (QuizzEditor.tsx)
□ Actualizar la exportación CSV si es relevante (history.ts → exportCsv)
```
