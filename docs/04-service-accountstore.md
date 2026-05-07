# Servicio AccountStore

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/accountStore.ts` (595 líneas)  
> **Relacionado con:** [02-database](./02-database.md) · [03-service-config](./03-service-config.md) · [07-service-history](./07-service-history.md) · [13-auth-sessions](./13-auth-sessions.md)

---

## Responsabilidad

`AccountStore` es el servicio principal de **gestión de cuentas**. Maneja:

- Cuentas de managers (CRUD, autenticación, roles, habilitación)
- Quizzes asociados a managers (CRUD)
- Configuración personal de cada manager (audio por defecto)
- Migración de datos legacy (del sistema de archivos a SQLite)

Todos los datos se persisten en **SQLite** via `Database`.

---

## Seguridad de contraseñas

```typescript
// Hashing
const hashPassword = (password: string) => {
  const salt = randomBytes(16).toString("hex")  // 16 bytes aleatorios → 32 chars hex
  const hash = scryptSync(password, salt, 64).toString("hex")  // 64 bytes → 128 chars hex
  return `${salt}:${hash}`  // formato "salt:hash"
}

// Verificación
const verifyPassword = (password: string, passwordHash: string) => {
  const [salt, storedHash] = passwordHash.split(":")
  const derivedHash = scryptSync(password, salt, storedHash.length / 2).toString("hex")
  return timingSafeEqual(
    Buffer.from(derivedHash, "hex"),
    Buffer.from(storedHash, "hex"),
  )
}
```

**Algoritmo:** `scrypt` (node:crypto)  
**Salt:** 16 bytes aleatorios por contraseña  
**Comparación:** `timingSafeEqual` — previene ataques de timing

---

## Arranque y migración legacy

### `AccountStore.init()`

```
AccountStore.init()
  └── Database.init()         ← inicializa SQLite
  └── autoMigrateLegacyAdmin()
        ├── ¿managers en BD? ← SI → no hace nada
        └── ¿game.json tiene password válida (≠ "PASSWORD")?
              └── SI → createManagerRecord("admin", password, "admin")
              └── migrateLegacyResources(admin.id)
```

### `migrateLegacyResources(managerId)`

Solo se ejecuta si **no hay quizzes en SQLite** (primera migración):

```
migrateLegacyResources(managerId)
  ├── ¿quizzes en SQLite? → 0 → importa desde Config.quizz() (archivos .json)
  ├── ¿game.json tiene defaultAudio? → importa a manager_settings
  └── History.claimLegacyRuns(managerId) → asigna runs sin manager_id
```

---

## Métodos de managers

### `isBootstrapRequired() → boolean`
Retorna `true` si la tabla `managers` está vacía. Usado para mostrar el setup inicial en el frontend.

### `createInitialAdmin(username, password) → ManagerSession`
Solo ejecutable cuando `isBootstrapRequired() === true`. Lanza error si ya existe un admin.  
Después de crear el admin, llama a `migrateLegacyResources()`.

### `authenticateManager(username, password) → LoginResult`

```typescript
type LoginResult =
  | { ok: true; manager: ManagerSession }
  | { ok: false; reason: "invalid" | "disabled" }
```

Flujo:
1. Busca el manager por username (case-insensitive)
2. Si no existe o no tiene `password_hash`: `{ ok: false, reason: "invalid" }`
3. Si `disabled_at` tiene valor: `{ ok: false, reason: "disabled" }`
4. Si la contraseña no coincide: `{ ok: false, reason: "invalid" }`
5. Si todo OK: `{ ok: true, manager: { id, username, role } }`

### `getManagerById(managerId) → ManagerAccount | null`
Busca por UUID. Devuelve `ManagerAccount` completo o `null`.

### `listManagers() → ManagerAccount[]`
Ordenados: admins primero, luego por username ascendente (case-insensitive).

### `createManager(username, password) → ManagerAccount`
Crea con role `"manager"`. Requiere ser admin para llamarlo (validado en `index.ts`).

### `createOidcManager(username, role) → ManagerAccount`
Crea manager auto-provisionado por SSO. La contraseña es aleatoria (no se usa para login local).  
El username se sanitiza y se genera uno disponible si ya existe.

### `resetManagerPassword(managerId, password) → ManagerAccount`
Actualiza el `password_hash`. Lanza error si el manager no existe.

### `setManagerDisabled(managerId, disabled) → ManagerAccount`
Establece/limpia `disabled_at`. El servidor en `index.ts` también revoca sesiones activas y partidas si `disabled = true`.

### `updateManagerRole(managerId, role) → ManagerAccount`
Cambia el rol entre `"admin"` y `"manager"`. Llamado por `OidcAuth` cuando el rol en el JWT cambia.

---

## Métodos de configuración del manager

### `getManagerSettings(managerId) → ManagerSettings`
Lee de `manager_settings`. Devuelve `{ defaultAudio?: string }`.

### `updateManagerSettings(managerId, settings) → ManagerSettings`

```typescript
type ManagerSettingsUpdate = {
  password?: string      // cambia contraseña del manager
  defaultAudio?: string | null  // null = borrar audio; undefined = no cambiar
}
```

Usa `INSERT ... ON CONFLICT DO UPDATE` (upsert) para `manager_settings`.

---

## Métodos de quizzes

### `listQuizzes(managerId) → QuizzWithId[]`
Ordenados por `subject` (case-insensitive). El `payload_json` se parsea para devolver el objeto completo.

### `getQuizz(managerId, quizzId) → QuizzWithId | null`
Busca por `id` AND `manager_id` (un manager no puede acceder a quizzes de otro).

### `createQuizz(managerId, subject) → QuizzWithId`
Crea con un UUID v4 como ID y una pregunta de ejemplo:
```json
{
  "question": "New question",
  "answers": ["Answer 1", "Answer 2"],
  "solutions": [0],
  "cooldown": 5,
  "time": 20
}
```
Normaliza el quiz con `normalizeQuizz()` antes de guardar.

### `updateQuizz(managerId, quizzId, quizz) → QuizzWithId`
Normaliza y actualiza. Lanza error si la fila no existe (0 rows affected).

### `deleteQuizz(managerId, quizzId)`
Elimina. Lanza error si no existe.

---

## Generación de usernames únicos (OIDC)

`generateAvailableUsername(baseUsername)` — para managers creados via SSO:

```
1. Sanitiza: minúsculas, solo [a-z0-9._-], máx 20 chars
2. Si quedan < 4 chars, añade sufijo aleatorio
3. Busca en BD si el username existe
4. Si existe, añade sufijo numérico: "juan", "juan-2", "juan-3", ...
5. Retorna el primer username disponible
```

---

## Tipos de datos devueltos

### `ManagerAccount` — cuenta completa (para listas de admins)
```typescript
{
  id: string
  username: string
  role: "admin" | "manager"
  disabledAt: string | null
  createdAt: string
  updatedAt: string
}
```

### `ManagerSession` — solo para sesiones en memoria
```typescript
{
  id: string
  username: string
  role: "admin" | "manager"
}
```

### `QuizzWithId` — quiz con su id
```typescript
{
  id: string
  subject: string
  questions: QuizzQuestion[]
}
```

---

## Errores comunes lanzados

| Situación | Error |
|-----------|-------|
| Username duplicado al crear | `"Username is already in use"` |
| Manager no encontrado al actualizar | `"Manager not found"` |
| Quiz no encontrado | `"Quiz not found"` |
| Setup ya realizado | `"Initial admin is already configured"` |
| Password vacío | `"Password is required"` |
| Username inválido (Zod) | Mensaje del validator (4-20 chars) |
