# Sistema de Puntuación y Tiempos

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/utils/game.ts` · `packages/socket/src/services/game.ts`  
> **Relacionado con:** [05-service-game](./05-service-game.md) · [14-game-flow](./14-game-flow.md)

---

## Sistema de Puntuación

### Fórmula

```typescript
// packages/socket/src/utils/game.ts
export const timeToPoint = (startTime: number, segundos: number): number => {
  let points = 1000

  const tiempoTranscurrido = (Date.now() - startTime) / 1000  // en segundos
  points -= (1000 / segundos) * tiempoTranscurrido

  return Math.max(0, points)  // nunca negativo
}
```

**Parámetros:**
- `startTime`: `Date.now()` del momento en que se emitió `SELECT_ANSWER` (guardado en `round.startTime`)
- `segundos`: valor de `question.time` — los segundos totales para responder

**Comportamiento:**
- Respuesta instantánea: **1000 puntos** (máximo)
- Respuesta al último segundo: **0 puntos** (aproximado)
- Respuesta incorrecta: **0 puntos** (los puntos calculados no se suman)
- Sin respuesta: **0 puntos** (no hay entrada en `playersAnswers`)
- La función es **lineal** — se pierde `(1000 / time)` puntos por segundo

**Ejemplo:**
```
Pregunta con time = 20 segundos
  → responde al 1er segundo:  1000 - (1000/20)*1  = 950 pts
  → responde al 5to segundo:  1000 - (1000/20)*5  = 750 pts
  → responde al 10mo segundo: 1000 - (1000/20)*10 = 500 pts
  → responde al 20mo segundo: 1000 - (1000/20)*20 = 0 pts
```

### Cuándo se calculan los puntos

Los puntos se calculan **en el momento exacto** que el servidor recibe el evento `player:selectedAnswer`:

```typescript
socket.on("player:selectedAnswer", ({ gameId, data: { answerKey } }) => {
  withGame(gameId, socket, (game) => {
    game.selectAnswer(socket, answerKey)  // calcula timeToPoint() aquí
  })
})
```

`selectAnswer()` llama a `timeToPoint(this.round.startTime, question.time)` inmediatamente.

### Actualización del total de puntos

En `showResults()`, los puntos de la ronda se suman al total del jugador solo si la respuesta es correcta:

```typescript
const isCorrect = question.solutions.some(sol => sol === answer.answerId)
const pointsEarned = isCorrect ? answer.points : 0
player.points += pointsEarned
```

---

## Todos los Timeouts y Tiempos del Sistema

### Tiempos del juego (configurables por quiz)

Definidos en cada `QuizzQuestion`, editables desde el `QuizzEditor`.

| Parámetro | Campo | Descripción | Mínimo |
|-----------|-------|-------------|--------|
| Cooldown | `question.cooldown` | Segundos de preview de la pregunta antes de mostrar opciones | 0 |
| Tiempo de respuesta | `question.time` | Segundos disponibles para que los jugadores respondan | 1 |

### Tiempos fijos del sistema

| Tiempo | Valor | Dónde | Cuándo ocurre |
|--------|-------|-------|---------------|
| Cuenta regresiva de inicio | `3 segundos` | `game.ts` → `start()` | Entre `SHOW_START` y la primera ronda |
| Pausa pre-pregunta | `2 segundos` | `game.ts` → `newRound()` | Durante `SHOW_PREPARED` |
| Grace period jugador | `60.000 ms` | `game.ts` → `PLAYER_RECONNECT_GRACE_MS` | Tiempo antes de eliminar jugador desconectado |

### Tiempos de gestión (infra)

| Tiempo | Valor | Dónde | Cuándo ocurre |
|--------|-------|-------|---------------|
| Cleanup partidas vacías | `5 minutos` | `registry.ts` → `EMPTY_GAME_TIMEOUT_MINUTES` | Partida sin manager se elimina |
| Intervalo de cleanup | `60 segundos` | `registry.ts` → `CLEANUP_INTERVAL_MS` | Cada cuánto se ejecuta el cleanup |
| Reconexión del socket | `1 segundo` | `socketProvider.tsx` → `reconnectionDelay` | Delay entre reintentos de reconexión |

### Tiempos de autenticación OIDC

| Tiempo | Valor | Dónde | Cuándo ocurre |
|--------|-------|-------|---------------|
| Estado OIDC pendiente | `10 minutos` | `oidcAuth.ts` → `AUTH_STATE_TTL_MS` | El usuario tiene 10 min para autenticarse en el proveedor |
| Handoff de login | `2 minutos` | `oidcAuth.ts` → `LOGIN_HANDOFF_TTL_MS` | El browser tiene 2 min para reclamar la sesión SSO |

### Caché de media

| Tiempo | Valor | Dónde | Descripción |
|--------|-------|-------|-------------|
| Cache-Control media | `3600 segundos (1h)` | `index.ts` | Archivos de audio servidos desde `/media/` |

---

## Timeline de una ronda (con valores de ejemplo)

```
0s   ← SELECT_ANSWER emitido (round.startTime = now)
     Jugadores pueden responder

     ←← Juagdor A responde a los 3s → 850 pts ←←
     ←← Jugador B responde a los 8s → 600 pts ←←
     ←← Jugador C responde a los 15s → 250 pts ←←

20s  ← Tiempo agotado (cooldown termina)
     ← showResults() se ejecuta

     Jugador D (no respondió) → 0 pts
```

Si todos responden antes del tiempo (ej: en 5s), `abortCooldown()` se llama y el tiempo termina inmediatamente, pasando a `showResults()`.

---

## Tick a tick del countdown

El servidor emite `game:cooldown count` **cada segundo** durante los temporizadores:

```typescript
startCooldown(seconds) {
  return new Promise((resolve) => {
    this.cooldown.active = true
    let remaining = seconds

    const tick = async () => {
      if (!this.cooldown.active || remaining <= 0) {
        resolve()
        return
      }
      this.io.to(this.gameId).emit("game:cooldown", remaining)
      remaining--
      await sleep(1)
      tick()
    }

    tick()
  })
}
```

El frontend usa estos ticks para animar barra de progreso / countdown numérico.
