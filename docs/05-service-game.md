# Servicio Game (Lógica de Partida)

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/game.ts` (819 líneas)  
> **Relacionado con:** [06-service-registry](./06-service-registry.md) · [07-service-history](./07-service-history.md) · [09-websocket-events](./09-websocket-events.md) · [14-game-flow](./14-game-flow.md) · [15-scoring-timings](./15-scoring-timings.md)

---

## Responsabilidad

La clase `Game` encapsula **toda la lógica de una partida**. Cada instancia vive en **memoria RAM** mientras la partida está activa. Al terminar se elimina del `Registry`.

Una partida persiste entre desconexiones (reconexión de manager o jugadores) hasta que se termina explícitamente o el Registry la limpia.

---

## Ciclo de vida de una instancia Game

```
new Game(io, socket, manager, quizz, settings)
  └── Registrada en Registry.addGame()
  └── Emite manager:gameCreated
  └── STATUS: SHOW_ROOM (sala de espera)

  [jugadores se unen]

game.start(socket)
  └── STATUS: SHOW_START (cuenta regresiva 3s)
  └── game:startCooldown + startCooldown(3)
  └── newRound()  ←──────────────────────────────┐
        └── STATUS: SHOW_PREPARED (2s)            │
        └── STATUS: SHOW_QUESTION (cooldown s)    │
        └── STATUS: SELECT_ANSWER (time s)        │
        └── showResults()                         │
              └── STATUS: SHOW_RESULT (jugadores) │
              └── STATUS: SHOW_RESPONSES (manager)│
        [manager → showLeaderboard()]             │
              └── ¿última ronda?                  │
                    NO → STATUS: SHOW_LEADERBOARD  │
                    [manager → nextRound()] ───────┘
                    SI → STATUS: FINISHED
                         persistHistory()
                         started = false

game.terminate(reason) / endGame()
  └── Registry.removeGame()
  └── emite game:reset a todos
```

---

## Propiedades de una instancia `Game`

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `gameId` | `string` | UUID v4 de la partida |
| `inviteCode` | `string` | Código numérico de 6 dígitos para unirse |
| `started` | `boolean` | `true` después de que el manager inicia |
| `io` | `Server` | Referencia al servidor Socket.IO |
| `manager` | `object` | `{ id: socketId, clientId, accountId, username, connected }` |
| `quizz` | `QuizzWithId` | Quiz completo con preguntas |
| `players` | `Player[]` | Jugadores conectados; se ordena por puntos después de cada ronda |
| `leaderboard` | `Player[]` | Copia ordenada por puntos (para mostrar top 5) |
| `round` | `object` | `{ currentQuestion: number, playersAnswers: Answer[], startTime: number }` |
| `cooldown` | `object` | `{ active: boolean, ms: number }` — estado del temporizador |
| `historyQuestions` | array | Acumula datos de cada ronda para el historial |
| `pendingPlayerRemovals` | `Map` | Timeouts para eliminar jugadores desconectados |
| `defaultAudio` | `string?` | Audio del manager para reproducir durante preguntas |
| `lastBroadcastStatus` | objeto | Último status emitido a todos (para reconexión) |
| `managerStatus` | objeto | Status específico del manager (para reconexión) |
| `playerStatus` | `Map<socketId, status>` | Status individual de cada jugador (para reconexión) |

---

## Métodos de unión y gestión de jugadores

### `join(socket, username)`

Valida:
1. ¿El `clientId` ya está conectado? → error "Player already connected"
2. ¿Username válido? (Zod: 4-20 chars) → error con mensaje del validator

Si OK:
- Añade jugador al array `players`
- Cancela cualquier remoción pendiente del mismo `clientId`
- Emite `manager:newPlayer` al manager
- Emite `game:totalPlayers` a toda la room
- Emite `game:successJoin gameId` al jugador

### `kickPlayer(socket, playerId)`

Solo el manager puede expulsar. Verifica `socket.id === manager.id`.

- Elimina jugador de `players`
- Lo saca del room de Socket.IO
- Emite `game:reset "You have been kicked by the manager"` al jugador
- Emite `manager:playerKicked playerId` al manager

---

## Métodos de reconexión

### `reconnect(socket)`

Detecta si quien reconecta es el manager (por `clientId`) o un jugador, y delega.

### `reconnectManager(socket)` _(privado)_

Solo si el `clientId` coincide y el manager no está ya conectado:
- Llama a `activateManagerControl(socket)` que restaura el estado del manager
- Llama a `Registry.reactivateGame()`

### `reconnectPlayer(socket)` _(privado)_

- Actualiza `player.id` con el nuevo `socket.id`
- Cancela remoción pendiente
- Emite `player:successReconnect` con estado actual + pregunta actual

### `takeOverManager(socket)`

Desconecta el manager anterior (emite `game:reset "Game taken over"`) y conecta el nuevo. Permite que otro browser del mismo manager tome el control.

---

## El temporizador: `startCooldown(seconds)`

```typescript
startCooldown(seconds: number): Promise<void>
```

- Emite `game:cooldown count` cada segundo (countdown)
- Resuelve la Promise cuando llega a 0 o cuando `abortCooldown()` es llamado
- Usado para el preview de respuesta (segundos definidos por `question.cooldown`) y para el tiempo de respuesta (`question.time`)

```typescript
abortCooldown()
  this.cooldown.active &&= false  // detiene el interval del próximo tick
```

`abortCooldown()` se llama cuando:
- Todos los jugadores ya respondieron (todos respondieron antes del tiempo)
- El manager hace "Skip" (`abortRound`)
- La partida se termina

---

## Flujo de una ronda: `newRound()`

```typescript
async newRound() {
  const question = this.quizz.questions[this.round.currentQuestion]

  this.playerStatus.clear()                    // limpia status individuales

  // Emite actualización de número de pregunta
  this.io.to(this.gameId).emit("game:updateQuestion", {...})

  // 1. SHOW_PREPARED (2 segundos)
  this.broadcastStatus(STATUS.SHOW_PREPARED, {...})
  await sleep(2)

  // 2. SHOW_QUESTION (cooldown segundos - preview de la pregunta)
  this.broadcastStatus(STATUS.SHOW_QUESTION, { question, image, cooldown })
  await sleep(question.cooldown)

  // 3. SELECT_ANSWER (time segundos - jugadores responden)
  this.round.startTime = Date.now()           // marca inicio para calcular puntos
  this.broadcastStatus(STATUS.SELECT_ANSWER, { answers, time, ... })
  await this.startCooldown(question.time)

  // 4. Muestra resultados
  this.showResults(question)
}
```

---

## `showResults(question)`

Se ejecuta al terminar el tiempo de respuesta. Para cada jugador:

1. Busca si respondió y qué respondió
2. Verifica si la respuesta es correcta
3. Calcula puntos (ya calculados cuando `selectAnswer` fue llamado, se suma aquí)
4. Actualiza `player.points`
5. Ordena `players` por puntos (descending)
6. Acumula en `historyQuestions`

Emite:
- `game:status { name: SHOW_RESULT, data: { correct, message, points, myPoints, rank, aheadOfMe } }` a **cada jugador individualmente** (status diferente por jugador)
- `game:status { name: SHOW_RESPONSES, data: { question, responses, correct, answers } }` solo al manager

### Campos de `SHOW_RESULT` por jugador:

```typescript
{
  correct: boolean          // si acertó
  message: "Nice!" | "Too bad"
  points: number           // puntos de esta ronda
  myPoints: number         // total acumulado
  rank: number             // posición en el ranking
  aheadOfMe: string | null // username del jugador justo delante
}
```

---

## `selectAnswer(socket, answerId)`

```typescript
selectAnswer(socket: Socket, answerId: number)
```

Se llama cuando un jugador envía `player:selectedAnswer`.

Validaciones:
- ¿El socket es un jugador válido?
- ¿Ya respondió? (solo una respuesta por ronda)
- ¿`answerId` es un entero dentro del rango de respuestas?

Si OK:
- Registra `{ playerId, answerId, points: timeToPoint(...) }` en `round.playersAnswers`
- Emite `game:status { WAIT }` al jugador que respondió
- Emite `game:playerAnswer count` a toda la room (para que el manager vea cuántos respondieron)
- Si todos respondieron: llama `abortCooldown()` → el tiempo termina inmediatamente

---

## `showLeaderboard()`

Llamado cuando el manager hace "Next" después de las respuestas.

- **Si es la última pregunta:**
  - Establece `started = false`
  - Llama a `persistHistory()` → guarda en SQLite
  - Emite `STATUS.FINISHED` a todos con el top 3

- **Si no es la última:**
  - Emite `STATUS.SHOW_LEADERBOARD` solo al manager con `{ oldLeaderboard, leaderboard }` (para animar cambios de posición)

---

## Gestión de desconexiones de jugadores

### Durante la sala de espera (antes de `start()`):

```
jugador se desconecta
  └── player.connected = false
  └── game.schedulePlayerRemoval(player.id)
        └── setTimeout(60s) → elimina si sigue desconectado
```

Si el jugador reconecta antes de los 60s: `cancelPendingPlayerRemoval()` cancela el timeout.

Si no reconecta: el jugador se **elimina de la lista** y el manager lo ve desaparecer.

### Durante la partida activa (después de `start()`):

```
jugador se desconecta
  └── player.connected = false
  └── NO se elimina — sigue en la lista
  └── Si el manager termina la ronda, el jugador sin respuesta no suma puntos
```

Los jugadores desconectados en partida permanecen en la lista por si reconectan.

### `removeDisconnectedWaitingPlayers()`

Llamado justo antes de `start()`. Elimina todos los jugadores que estén desconectados en el momento de iniciar (limpieza preventiva).

---

## Terminación de una partida

### `terminate(reason)`

```typescript
terminate(reason: string) {
  this.abortCooldown()
  this.started = false
  this.clearPendingPlayerRemovals()
  this.revokeManagerControl(reason)
  this.io.to(this.gameId).emit("game:reset", reason)
  registry.removeGame(this.gameId)
}
```

Emite `game:reset` a **todos** (incluyendo jugadores). Todos los clientes navegan a `/` al recibir este evento.

### `revokeManagerControl(reason)`

Solo revoca el control del manager (sin afectar jugadores). Usado cuando el manager se desconecta voluntariamente.

---

## Persistencia del historial: `persistHistory()`

Solo se ejecuta una vez por partida. Genera un UUID v4 como `runId` y llama a:

```typescript
History.addRun(this.manager.accountId, {
  id: runId,
  gameId: this.gameId,
  quizzId: this.quizz.id,
  subject: this.quizz.subject,
  startedAt: this.startedAt,
  endedAt: new Date().toISOString(),
  totalPlayers: this.players.length,
  questionCount: this.quizz.questions.length,
  winner: this.leaderboard[0]?.username ?? null,
  leaderboard: [...],
  questions: this.historyQuestions,
})
```

El `runId` es devuelto y emitido en `STATUS.FINISHED` para que el manager pueda descargar el CSV.
