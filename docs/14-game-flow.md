# Flujo del Juego — Paso a Paso

> **Parte de:** [Índice](./INDEX.md)  
> **Relacionado con:** [05-service-game](./05-service-game.md) · [09-websocket-events](./09-websocket-events.md) · [15-scoring-timings](./15-scoring-timings.md) · [12-frontend-components](./12-frontend-components.md)

---

## Los STATUS del juego

```typescript
export const STATUS = {
  SHOW_ROOM:        "SHOW_ROOM",        // Manager: sala de espera
  SHOW_START:       "SHOW_START",       // Todos: cuenta regresiva de inicio
  SHOW_PREPARED:    "SHOW_PREPARED",    // Todos: "pregunta X se acerca"
  SHOW_QUESTION:    "SHOW_QUESTION",    // Todos: muestra la pregunta
  SELECT_ANSWER:    "SELECT_ANSWER",    // Todos: opciones de respuesta
  SHOW_RESULT:      "SHOW_RESULT",      // Jugadores: resultado individual
  SHOW_RESPONSES:   "SHOW_RESPONSES",   // Manager: distribución de respuestas
  SHOW_LEADERBOARD: "SHOW_LEADERBOARD", // Manager: tabla de líderes
  FINISHED:         "FINISHED",         // Todos: podio final
  WAIT:             "WAIT",             // Jugadores: esperando (ya respondieron)
}
```

---

## Diagrama del flujo completo

```
[Manager en dashboard]
       │
       │ socket.emit("game:create", quizzId)
       ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Servidor: new Game(io, socket, manager, quizz, settings)    │
  │   → Registry.addGame(game)                                  │
  │   → socket.emit("manager:gameCreated", { gameId, inviteCode})│
  └──────────────┬──────────────────────────────────────────────┘
                 │
                 │ Manager navega a /party/manager/:gameId
                 ▼
          STATUS: SHOW_ROOM
          ┌──────────────────────────────────┐
          │ Manager ve:                       │
          │  - QR code                        │
          │  - Código: 123456                 │
          │  - Lista de jugadores (vacía)     │
          └──────────────────────────────────┘
                 │
                 │ [Jugadores se unen]
                 │
                 │ Jugador A: player:join "123456"
                 │   ← game:successRoom gameId
                 │ Jugador A: player:login { username: "Alice" }
                 │   ← game:successJoin gameId
                 │   ← (manager) manager:newPlayer Player
                 │   ← (todos) game:totalPlayers 1
                 │
                 │ [Manager hace click "Start Game"]
                 │ manager:startGame { gameId }
                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ game.start(socket)                                          │
  │   → limpia jugadores desconectados                         │
  │   → started = true                                         │
  └──────────────┬──────────────────────────────────────────────┘
                 │
                 ▼
          STATUS: SHOW_START
          data: { time: 3, subject: "Mi Quiz" }
          ┌──────────────────────────────────┐
          │ Todos ven: cuenta regresiva       │
          │ "Mi Quiz" — 3... 2... 1...        │
          └──────────────────────────────────┘
                 │ (auto: sleep(3))
                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ game.newRound()  ← se llama para CADA pregunta              │
  └──────────────┬──────────────────────────────────────────────┘
                 │
                 ▼
          io.emit("game:updateQuestion", { current: 1, total: 5 })
                 │
                 ▼
          STATUS: SHOW_PREPARED
          data: { totalAnswers: 4, questionNumber: 1 }
          ┌──────────────────────────────────┐
          │ Todos ven: "Pregunta 1 de 5"     │
          │ "4 opciones de respuesta"        │
          └──────────────────────────────────┘
                 │ (auto: sleep(2))
                 ▼
          STATUS: SHOW_QUESTION
          data: { question: "¿Capital de Francia?", image?, cooldown: 5 }
          ┌──────────────────────────────────┐
          │ Todos ven: la pregunta           │
          │ (sin opciones todavía)           │
          │ Temporizador: 5 segundos         │
          └──────────────────────────────────┘
                 │ (auto: sleep(cooldown))
                 ▼
  round.startTime = Date.now()  ← marca el inicio para calcular puntos
                 │
                 ▼
          STATUS: SELECT_ANSWER
          data: { question, answers: ["Berlin","Paris","Madrid","Roma"],
                  multipleCorrect: false, image?, audio?, time: 20, totalPlayer: 3 }
          ┌──────────────────────────────────┐
          │ Manager ve: opciones + contador  │
          │ Jugadores ven: 4 botones de      │
          │ colores para responder           │
          │ Temporizador: 20 segundos        │
          └──────────────────────────────────┘
                 │
                 │ Jugador responde:
                 │ player:selectedAnswer { gameId, data: { answerKey: 1 } }
                 │
                 │ Servidor:
                 │   → calcula puntos (timeToPoint)
                 │   → guarda en round.playersAnswers
                 │   → emite WAIT al jugador que respondió
                 │   → emite game:playerAnswer count a todos
                 │
                 │ [Si todos respondieron → abortCooldown()]
                 │ [Si no, espera el tiempo completo]
                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ game.showResults(question)                                  │
  │   → calcula correctas para cada jugador                    │
  │   → actualiza player.points                                │
  │   → ordena players por puntos                              │
  └──────────────┬──────────────────────────────────────────────┘
                 │
            ┌────┴───────────────┐
            ▼                    ▼
  STATUS: SHOW_RESULT       STATUS: SHOW_RESPONSES
  (a cada jugador)          (solo al manager)
  data: {                   data: {
    correct: true,            question: "...",
    message: "Nice!",         responses: {0:1, 1:2, 2:0, 3:0},
    points: 743,              correct: [1],
    myPoints: 743,            answers: [...],
    rank: 1,                  image?
    aheadOfMe: null         }
  }
          │                         │
          └──────────┬──────────────┘
                     │
                     │ Manager presiona "Next"
                     │ manager:showLeaderboard { gameId }
                     ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ game.showLeaderboard()                                      │
  └──────────────┬──────────────────────────────────────────────┘
                 │
           ¿Última pregunta?
           ┌────┴────────────────────────────────┐
           NO                                   SI
           │                                    │
           ▼                                    ▼
    STATUS: SHOW_LEADERBOARD           STATUS: FINISHED
    (solo al manager)                  (a todos)
    data: {                            data: {
      oldLeaderboard: [...],             subject: "Mi Quiz",
      leaderboard: [...]                 top: [Player, ...],
    }                                    runId: "uuid"
                                       }
           │
           │ Manager presiona "Next"
           │ manager:nextQuestion { gameId }
           │
           ▼
    round.currentQuestion++
    vuelve a newRound() ←──────────────────────────────┐
    (bucle hasta la última pregunta)                   │

                              FINISHED
                                 │
                                 │ [persistHistory()]
                                 │ → History.addRun(managerId, {...})
                                 │
                                 │ Manager presiona "End Quiz"
                                 │ manager:endGame { gameId }
                                 ▼
                    game.endGame(socket)
                    game.terminate("Game ended")
                    Registry.removeGame(gameId)
                    socket.emit("manager:activeGame", null)
                    Manager navega a /manager
```

---

## Flujo del Jugador en detalle

```
1. Navega a /
   └── Formulario de código de sala (join/Room.tsx)

2. Ingresa código de 6 dígitos
   └── socket.emit("player:join", "123456")
   ← game:successRoom gameId     (sala encontrada)
   └── Formulario de username (join/Username.tsx)

3. Ingresa username (4-20 chars)
   └── socket.emit("player:login", { gameId, data: { username: "Alice" } })
   ← game:successJoin gameId     (unido exitosamente)
   └── navega a /party/:gameId

4. Espera en WAIT/sin status hasta que el manager inicia
   └── STATUS: WAIT se recibe automáticamente si el juego ya empezó

5. Por cada pregunta:
   ← game:status SHOW_START
   ← game:status SHOW_PREPARED
   ← game:status SHOW_QUESTION
   ← game:status SELECT_ANSWER
   
   └── Jugador presiona botón de respuesta
   └── socket.emit("player:selectedAnswer", { gameId, data: { answerKey: 1 } })
   ← game:status WAIT        (mientras esperan a los demás)
   ← game:status SHOW_RESULT (resultado propio)

6. ← game:status FINISHED (cuando termina la última pregunta)

7. Si el manager termina: ← game:reset "Game ended"
   └── navega a /
   └── reset() del store del jugador
```

---

## Gestión de estados concurrentes

El servidor envía **status diferentes al manager y a los jugadores** para el mismo momento del juego:

| Momento | Manager ve | Jugadores ven |
|---------|-----------|--------------|
| Después de responder | Cuenta cuántos respondieron (`game:playerAnswer`) | `WAIT` |
| Al terminar el tiempo | `SHOW_RESPONSES` (distribución) | `SHOW_RESULT` (individual) |
| Entre preguntas (si no última) | `SHOW_LEADERBOARD` | `SHOW_RESULT` (sigue visible) |
| Al terminar el juego | `FINISHED` | `FINISHED` |

---

## Reconexión durante la partida

### Manager se reconecta

```
1. Manager pierde conexión → game.manager.connected = false
                          → registry.markGameAsEmpty(game)
2. Si la partida no había iniciado → game:reset a todos
3. Si la partida estaba iniciada → espera hasta 5 minutos
4. Manager reconecta → socket.emit("manager:reconnect", { gameId })
5. Servidor: game.reconnect(socket) → manager reconnects
   ← manager:successReconnect { gameId, status, players, currentQuestion }
6. Manager ve el estado actual de la partida
```

### Jugador se reconecta (antes de iniciar)

```
1. Jugador pierde conexión → player.connected = false
                           → game.schedulePlayerRemoval(player.id)  — 60s timer
2. Jugador reconecta → socket.emit("player:reconnect", { gameId })
3. Servidor detecta clientId coincide con jugador existente
   → update player.id con new socket.id
   → cancelPendingPlayerRemoval()
   ← player:successReconnect { gameId, status, player, currentQuestion }
```

### Jugador se reconecta (durante partida)

```
Igual que antes, pero el jugador no se remueve automáticamente
(durante partida activa, los jugadores desconectados se mantienen en lista)
```

---

## Abortar una ronda

El manager puede presionar "Skip" durante `SELECT_ANSWER`. Esto emite `manager:abortQuiz`:

```typescript
game.abortRound(socket)
  → this.abortCooldown()  // detiene el countdown
  // el flujo continúa normalmente con showResults()
  // los jugadores que no respondieron no suman puntos
```
