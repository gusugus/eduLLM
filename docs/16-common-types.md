# Tipos Compartidos, Validadores y Utils

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:** `packages/common/src/`  
> **Relacionado con:** [09-websocket-events](./09-websocket-events.md) · [04-service-accountstore](./04-service-accountstore.md)

---

## Propósito del paquete `@mindbuzz/common`

Contiene tipos TypeScript, validadores Zod y utilidades compartidas entre el backend (`@mindbuzz/socket`) y el frontend (`@mindbuzz/web`).

**Regla de oro:** Si algo necesita ser consistente entre cliente y servidor (tipos de datos, validaciones, constantes), vive aquí.

---

## Tipos de dominio — `types/game/index.ts`

### Jugador

```typescript
type Player = {
  id: string          // socket.id actual (cambia en reconexión)
  clientId: string    // UUID permanente del navegador
  connected: boolean  // si está conectado en este momento
  username: string    // elegido al unirse (4-20 chars)
  points: number      // puntos acumulados
}
```

### Respuesta de ronda

```typescript
type Answer = {
  playerId: string  // socket.id del jugador al momento de responder
  answerId: number  // índice 0-based de la opción elegida
  points: number    // puntos calculados en el momento (timeToPoint())
}
```

### Pregunta de quiz

```typescript
type QuizzQuestion = {
  question: string    // texto de la pregunta (requerido)
  image?: string      // URL de imagen (opcional)
  video?: string      // URL de video (opcional)
  audio?: string      // URL o path de audio (opcional)
  answers: string[]   // opciones de respuesta (2-4)
  solutions: number[] // índices de respuestas correctas (1+)
  cooldown: number    // segundos de preview (≥ 0)
  time: number        // segundos para responder (> 0)
}
```

### Quiz

```typescript
type Quizz = {
  subject: string           // nombre del quiz
  questions: QuizzQuestion[]
}

type QuizzWithId = Quizz & {
  id: string  // UUID v4 (en SQLite) o nombre de archivo (legacy)
}
```

### Cuentas de Manager

```typescript
type ManagerRole = "admin" | "manager"

// Cuenta completa — para listas de administración
type ManagerAccount = {
  id: string
  username: string
  role: ManagerRole
  disabledAt: string | null   // ISO timestamp o null
  createdAt: string
  updatedAt: string
}

// Sesión ligera — para autenticación en memoria
type ManagerSession = Pick<ManagerAccount, "id" | "username" | "role">

// Configuración personal
type ManagerSettings = {
  defaultAudio?: string
}

// Entrada para actualizar configuración
type ManagerSettingsUpdate = {
  password?: string
  defaultAudio?: string | null  // null = borrar audio
}
```

### Partida activa (para la UI)

```typescript
type ActiveManagerGame = {
  gameId: string
  inviteCode: string
  subject: string
  started: boolean
  controlledByCurrentSession: boolean  // ¿El clientId actual controla esta partida?
}
```

### Configuración OIDC

```typescript
// Expuesta al frontend (sin clientSecret)
type OidcConfig = {
  enabled: boolean
  autoProvisionEnabled: boolean
  discoveryUrl: string
  clientId: string
  hasClientSecret: boolean    // true/false, sin revelar el secret
  scopes: string[]
  roleClaimPath: string
  adminRoleValues: string[]
  managerRoleValues: string[]
}

// Input para guardar (puede incluir clientSecret)
type OidcConfigInput = {
  enabled: boolean
  autoProvisionEnabled: boolean
  discoveryUrl: string
  clientId: string
  clientSecret?: string          // undefined = no cambiar
  clearClientSecret?: boolean    // true = borrar
  scopes: string[]
  roleClaimPath: string
  adminRoleValues: string[]
  managerRoleValues: string[]
}

// Estado resumido para mostrar el botón SSO
type OidcStatus = {
  enabled: boolean
  configured: boolean  // tiene todos los campos necesarios
}
```

### Identidad OIDC

```typescript
type ManagerOidcIdentity = {
  id: string
  managerId: string
  issuer: string
  subject: string
  email: string | null
  usernameClaim: string | null
  lastLoginAt: string | null
  createdAt: string
  updatedAt: string
}
```

### Historial de partidas

```typescript
// Resumen — para la lista del panel
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

// Detalle — para la exportación CSV
type QuizRunHistoryDetail = QuizRunHistorySummary & {
  leaderboard: QuizRunLeaderboardEntry[]
  questions: QuizRunQuestion[]
}

type QuizRunLeaderboardEntry = {
  playerId: string
  rank: number
  username: string
  points: number
}

type QuizRunQuestion = {
  questionNumber: number
  question: string
  answers: string[]
  correctAnswers: number[]
  correctAnswerTexts: string[]
  responses: QuizRunQuestionResponse[]
}

type QuizRunQuestionResponse = {
  playerId: string
  username: string
  answerId: number | null      // null si no respondió
  answerText: string | null
  isCorrect: boolean
  points: number               // puntos de esta pregunta
  totalPoints: number          // acumulado hasta este momento
}
```

### Progreso de pregunta

```typescript
type GameUpdateQuestion = {
  current: number  // pregunta actual (1-based)
  total: number    // total de preguntas
}
```

---

## Tipos de estado — `types/game/status.ts`

### El enum STATUS

```typescript
export const STATUS = {
  SHOW_ROOM:        "SHOW_ROOM",
  SHOW_START:       "SHOW_START",
  SHOW_PREPARED:    "SHOW_PREPARED",
  SHOW_QUESTION:    "SHOW_QUESTION",
  SELECT_ANSWER:    "SELECT_ANSWER",
  SHOW_RESULT:      "SHOW_RESULT",
  SHOW_RESPONSES:   "SHOW_RESPONSES",
  SHOW_LEADERBOARD: "SHOW_LEADERBOARD",
  FINISHED:         "FINISHED",
  WAIT:             "WAIT",
} as const

export type Status = (typeof STATUS)[keyof typeof STATUS]
```

### StatusDataMap — datos de cada estado

```typescript
// Compartidos (jugadores y manager)
type CommonStatusDataMap = {
  SHOW_START:    { time: number; subject: string }
  SHOW_PREPARED: { totalAnswers: number; questionNumber: number }
  SHOW_QUESTION: { question: string; image?: string; cooldown: number }
  SELECT_ANSWER: {
    question: string; answers: string[]; multipleCorrect: boolean
    image?: string; video?: string; audio?: string
    time: number; totalPlayer: number
  }
  SHOW_RESULT: {
    correct: boolean; message: string; points: number
    myPoints: number; rank: number; aheadOfMe: string | null
  }
  WAIT:     { text: string }
  FINISHED: { subject: string; top: Player[]; runId: string }
}

// Solo para el manager
type ManagerExtraStatus = {
  SHOW_ROOM: { text: string; inviteCode?: string }
  SHOW_RESPONSES: {
    question: string; responses: Record<number, number>
    correct: number[]; answers: string[]; image?: string; video?: string
  }
  SHOW_LEADERBOARD: { oldLeaderboard: Player[]; leaderboard: Player[] }
}

export type PlayerStatusDataMap  = CommonStatusDataMap
export type ManagerStatusDataMap = CommonStatusDataMap & ManagerExtraStatus
export type StatusDataMap        = PlayerStatusDataMap & ManagerStatusDataMap
```

---

## Tipos de eventos socket — `types/game/socket.ts`

Ver [09-websocket-events](./09-websocket-events.md) para la lista completa.

```typescript
// Tipos del servidor Socket.IO
export type Server = ServerIO<ClientToServerEvents, ServerToClientEvents>
export type Socket = SocketIO<ClientToServerEvents, ServerToClientEvents>
```

---

## Validadores Zod — `validators/auth.ts`

```typescript
import z from "zod"

// Username del jugador
export const usernameValidator = z
  .string()
  .min(4, "Username cannot be less than 4 characters")
  .max(20, "Username cannot exceed 20 characters")

// Código de invitación de sala
export const inviteCodeValidator = z.string().length(6, "Invalid invite code")
```

Usados en:
- **Backend** (`index.ts`): valida los datos recibidos antes de procesarlos
- **Frontend** (`join/Room.tsx`, `join/Username.tsx`): valida antes de enviar el evento

---

## Utils de audio — `utils/audio.ts`

```typescript
export const LOCAL_MEDIA_PREFIX = "/media/"

// Permite: /media/archivo.mp3 y URLs http/https
// Rechaza: todo lo demás (rutas relativas, javascript:, etc.)
export const normalizeAudioUrl = (value?: string | null): string | undefined => {
  const trimmed = value?.trim()
  if (!trimmed) return undefined

  if (trimmed.startsWith(LOCAL_MEDIA_PREFIX)) return trimmed

  try {
    const parsed = new URL(trimmed)
    const ALLOWED = new Set(["http:", "https:"])
    return ALLOWED.has(parsed.protocol) ? trimmed : undefined
  } catch {
    return undefined
  }
}

export const isAudioUrlAllowed = (value?: string | null): boolean =>
  normalizeAudioUrl(value) !== undefined
```

Usadas en:
- **Backend** (`config.ts`, `game.ts`): valida URLs de audio antes de pasarlas al cliente
- **Frontend**: para mostrar/ocultar controles de audio según si la URL es válida
