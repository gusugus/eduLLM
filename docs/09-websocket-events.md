# Eventos WebSocket (Socket.IO)

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:**  
> - `packages/common/src/types/game/socket.ts` — definición de tipos  
> - `packages/socket/src/index.ts` — manejadores en el servidor  
> - `packages/web/src/features/game/contexts/socketProvider.tsx` — conexión cliente  
> **Relacionado con:** [05-service-game](./05-service-game.md) · [11-frontend-stores](./11-frontend-stores.md) · [14-game-flow](./14-game-flow.md)

---

## Configuración del socket

**Servidor (index.ts):**
```typescript
const io = new ServerIO(httpServer, {
  path: "/ws",               // ruta distinta de "/" para convivir con HTTP
  maxHttpBufferSize: 25 * 1024 * 1024  // 25 MB (para uploads de audio)
})
```

**Cliente (socketProvider.tsx):**
```typescript
io("/", {
  path: "/ws",
  autoConnect: false,
  reconnection: true,
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,         // 1 segundo entre reintentos
  auth: { clientId }               // UUID del localStorage, enviado en el handshake
})
```

**El `clientId`** es el identificador permanente del navegador (UUID v7). Es como un "token de dispositivo" — permite al servidor saber quién está conectado aunque el socket.id cambie.

---

## Namespaces y rooms

- **Sin namespaces personalizados** — todo en el namespace por defecto `/`
- **Room por partida:** cada `Game` tiene su propio `gameId` como room name
  - Manager hace `socket.join(this.gameId)`
  - Jugadores hacen `socket.join(this.gameId)` al unirse
  - `io.to(gameId).emit(...)` → llega a todos en esa room

---

## Eventos: Cliente → Servidor

### Setup y autenticación del manager

| Evento | Payload | Descripción |
|--------|---------|-------------|
| `manager:getBootstrapState` | — | ¿Hay managers? ¿Necesita setup? |
| `manager:createInitialAdmin` | `{username: string, password: string}` | Crea el primer admin (solo si BD vacía) |
| `manager:auth` | `{username: string, password: string}` | Login con contraseña |
| `manager:completeOidcLogin` | — | Completa el login SSO post-callback |
| `manager:getDashboard` | — | Solicita todos los datos del dashboard |
| `manager:logout` | — | Cierra sesión y aborta partida activa |

### Administración de managers (solo admin)

| Evento | Payload |
|--------|---------|
| `manager:listManagers` | — |
| `manager:createManager` | `{username, password}` |
| `manager:resetManagerPassword` | `{managerId, password}` |
| `manager:setManagerDisabled` | `{managerId, disabled: boolean}` |

### Configuración OIDC (solo admin)

| Evento | Payload |
|--------|---------|
| `manager:getOidcConfig` | — |
| `manager:updateOidcConfig` | `OidcConfigInput` |
| `manager:testOidcConfig` | `OidcConfigInput` |

### Quizzes y configuración

| Evento | Payload |
|--------|---------|
| `manager:createQuizz` | `{subject: string}` |
| `manager:updateQuizz` | `{quizzId: string, quizz: Quizz}` |
| `manager:deleteQuizz` | `{quizzId: string}` |
| `manager:updateSettings` | `{password?: string, defaultAudio?: string \| null}` |
| `manager:uploadMedia` | `{filename: string, content: string}` (base64) |
| `manager:downloadHistory` | `{runId: string}` |

### Control de partida (manager)

| Evento | Payload | Llama a |
|--------|---------|---------|
| `game:create` | `quizzId: string` | Instancia `new Game(...)` |
| `manager:reconnect` | `{gameId}` | `game.reconnect(socket)` |
| `manager:takeOverGame` | `{gameId}` | `game.takeOverManager(socket)` |
| `manager:startGame` | `{gameId}` | `game.start(socket)` |
| `manager:kickPlayer` | `{gameId, playerId}` | `game.kickPlayer(socket, playerId)` |
| `manager:abortQuiz` | `{gameId}` | `game.abortRound(socket)` |
| `manager:nextQuestion` | `{gameId}` | `game.nextRound(socket)` |
| `manager:showLeaderboard` | `{gameId}` | `game.showLeaderboard()` |
| `manager:endGame` | `{gameId}` | `game.endGame(socket)` |

### Acciones de jugador

| Evento | Payload | Descripción |
|--------|---------|-------------|
| `player:join` | `inviteCode: string` | Busca sala por código de 6 dígitos |
| `player:login` | `{gameId, data: {username}}` | Entra a la sala con un username |
| `player:reconnect` | `{gameId}` | Reconecta a una partida existente |
| `player:selectedAnswer` | `{gameId, data: {answerKey: number}}` | Selecciona respuesta (índice 0-based) |

### Evento de sistema

| Evento | Descripción |
|--------|-------------|
| `disconnect` | Manejado automáticamente por Socket.IO; el servidor gestiona desconexiones |

---

## Eventos: Servidor → Cliente

### Eventos de juego (todos los clientes en la room)

| Evento | Payload | Descripción |
|--------|---------|-------------|
| `game:status` | `{name: Status, data: StatusDataMap[Status]}` | Cambio de estado del juego |
| `game:totalPlayers` | `count: number` | Total de jugadores conectados |
| `game:startCooldown` | — | Señal de inicio del countdown de partida |
| `game:cooldown` | `count: number` | Tick del temporizador (cada segundo) |
| `game:reset` | `message: string` | La partida termina — todos navegan fuera |
| `game:updateQuestion` | `{current: number, total: number}` | Progreso de preguntas |
| `game:playerAnswer` | `count: number` | Cuántos jugadores han respondido |

### Eventos de juego (individuales)

| Evento | Destinatario | Payload |
|--------|-------------|---------|
| `game:successRoom` | Jugador | `gameId: string` — sala encontrada por código |
| `game:successJoin` | Jugador | `gameId: string` — unido exitosamente |
| `game:errorMessage` | Socket individual | `message: string` |

### Reconexión

| Evento | Destinatario | Payload |
|--------|-------------|---------|
| `player:successReconnect` | Jugador | `{gameId, status, player, currentQuestion}` |
| `manager:successReconnect` | Manager | `{gameId, status, players, currentQuestion}` |

### Events del manager — Dashboard

| Evento | Payload |
|--------|---------|
| `manager:bootstrapState` | `{requiresSetup: boolean}` |
| `manager:authSuccess` | `{manager: ManagerSession}` |
| `manager:activeGame` | `ActiveManagerGame \| null` |
| `manager:quizzList` | `QuizzWithId[]` |
| `manager:historyList` | `QuizRunHistorySummary[]` |
| `manager:settings` | `{defaultAudio?: string}` |
| `manager:managersList` | `ManagerAccount[]` |
| `manager:oidcConfig` | `OidcConfig` |
| `manager:oidcStatus` | `{enabled: boolean, configured: boolean}` |
| `manager:errorMessage` | `message: string` |

### Events del manager — Confirmaciones CRUD

| Evento | Payload |
|--------|---------|
| `manager:quizzCreated` | `QuizzWithId` |
| `manager:quizzUpdated` | `QuizzWithId` |
| `manager:quizzDeleted` | `quizzId: string` |
| `manager:managerCreated` | `ManagerAccount` |
| `manager:managerUpdated` | `ManagerAccount` |
| `manager:gameCreated` | `{gameId, inviteCode}` |
| `manager:mediaUploaded` | `{url: string}` |
| `manager:historyExportReady` | `{filename: string, content: string}` |
| `manager:oidcConfigSaved` | `OidcConfig` |
| `manager:oidcConfigTested` | `OidcConfigTestResult` |
| `manager:playerKicked` | `playerId: string` |
| `manager:newPlayer` | `Player` |
| `manager:removePlayer` | `playerId: string` |

---

## El helper `withGame`

La mayoría de los eventos relacionados con partidas usan este helper en `index.ts`:

```typescript
// packages/socket/src/utils/game.ts
export const withGame = (gameId, socket, callback) => {
  if (!gameId) {
    socket.emit("game:errorMessage", "Game not found")
    return
  }
  const game = Registry.getInstance().getGameById(gameId)
  if (!game) {
    socket.emit("game:errorMessage", "Game not found")
    return
  }
  callback(game)
}

// Uso en index.ts:
socket.on("manager:startGame", ({ gameId }) =>
  withGame(gameId, socket, (game) => game.start(socket))
)
```

---

## Flujo de `emitManagerDashboard`

Cuando un manager se autentica (login, reconexión, completar OIDC), el servidor emite **7 eventos** en secuencia:

```typescript
socket.emit("manager:authSuccess", { manager })
socket.emit("manager:quizzList", AccountStore.listQuizzes(manager.id))
socket.emit("manager:historyList", History.listRuns(manager.id))
socket.emit("manager:settings", AccountStore.getManagerSettings(manager.id))
socket.emit("manager:activeGame", activeGame?.getActiveManagerGame(clientId) ?? null)
socket.emit("manager:oidcStatus", OidcAuth.status())
socket.emit("manager:managersList", manager.role === "admin" ? AccountStore.listManagers() : [])
```

---

## Tipos de `game:status` por estado

El evento `game:status` usa un campo `name` para discriminar el tipo. Los datos varían:

| `name` | `data` |
|--------|--------|
| `SHOW_ROOM` | `{text: string, inviteCode?: string}` |
| `SHOW_START` | `{time: number, subject: string}` |
| `SHOW_PREPARED` | `{totalAnswers: number, questionNumber: number}` |
| `SHOW_QUESTION` | `{question: string, image?: string, cooldown: number}` |
| `SELECT_ANSWER` | `{question, answers[], multipleCorrect, image?, video?, audio?, time, totalPlayer}` |
| `SHOW_RESULT` | `{correct, message, points, myPoints, rank, aheadOfMe}` |
| `SHOW_RESPONSES` | `{question, responses: Record<number,number>, correct[], answers[], image?}` |
| `SHOW_LEADERBOARD` | `{oldLeaderboard: Player[], leaderboard: Player[]}` |
| `FINISHED` | `{subject: string, top: Player[], runId: string}` |
| `WAIT` | `{text: string}` |
