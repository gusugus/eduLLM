# Frontend — Stores y SocketProvider

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:**  
> - `packages/web/src/features/game/contexts/socketProvider.tsx`  
> - `packages/web/src/features/game/stores/manager.tsx`  
> - `packages/web/src/features/game/stores/player.tsx`  
> - `packages/web/src/features/game/stores/question.tsx`  
> **Relacionado con:** [09-websocket-events](./09-websocket-events.md) · [10-frontend-router](./10-frontend-router.md) · [13-auth-sessions](./13-auth-sessions.md)

---

## SocketProvider — El puente WebSocket

**Archivo:** `packages/web/src/features/game/contexts/socketProvider.tsx`

Provee el socket de Socket.IO a toda la aplicación usando React Context.

### Inicialización del socket

```typescript
// Solo se crea una vez (guard con if (socket) return)
socketClient = io("/", {
  path: "/ws",               // mismo path que el servidor
  autoConnect: false,        // NO conecta automáticamente
  reconnection: true,
  reconnectionAttempts: Infinity,  // reintentos infinitos
  reconnectionDelay: 1000,   // 1 segundo entre intentos
  auth: { clientId },        // UUID del localStorage enviado al handshake
})
```

`autoConnect: false` — el socket se crea pero no conecta hasta que se llame a `connect()`. GameLayout llama a `connect()` al montar.

### El `clientId`

```typescript
const getClientId = (): string => {
  try {
    const stored = localStorage.getItem("client_id")
    if (stored) return stored

    const newId = uuid()  // UUID v7 (tiempo-basado)
    localStorage.setItem("client_id", newId)
    return newId
  } catch {
    return uuid()  // fallback si localStorage no está disponible
  }
}
```

El `clientId` es el **identificador permanente del dispositivo/navegador**. Se usa en el servidor para:
- Identificar qué manager está conectado (`authenticatedManagers.get(clientId)`)
- Reconectar jugadores a su partida anterior
- Identificar quién creó la partida tras un takeover

### Valores expuestos por el contexto

```typescript
interface SocketContextValue {
  socket: TypedSocket | null   // el socket de socket.io-client
  isConnected: boolean         // true cuando socket.connected
  clientId: string             // UUID permanente del navegador
  connect: () => void          // llama socket.connect()
  disconnect: () => void       // llama socket.disconnect()
  reconnect: () => void        // disconnect + connect (fuerza nueva conexión)
}
```

### Hooks exportados

#### `useSocket()`
Accede a los valores del contexto desde cualquier componente descendiente.

```tsx
const { socket, isConnected, clientId } = useSocket()
```

#### `useEvent<E>(event, callback)`

Registra un listener de evento que se **limpia automáticamente** al desmontar el componente o cuando el socket cambia:

```tsx
// En un componente:
useEvent("game:status", ({ name, data }) => {
  setStatus(name, data)
})

// Equivalente manual (no recomendado):
useEffect(() => {
  if (!socket) return
  socket.on("game:status", handler)
  return () => socket.off("game:status", handler)
}, [socket, handler])
```

⚠️ El `callback` debe ser estable (usar `useCallback` si depende de estado) o el efecto re-registrará el listener en cada render.

---

## useManagerStore — Estado del Manager en Partida

**Archivo:** `packages/web/src/features/game/stores/manager.tsx`  
**Librería:** Zustand  
**Persistencia:** ❌ No persiste (en memoria)

```typescript
type ManagerStore = {
  gameId: string | null      // ID de la partida activa
  status: Status | null      // estado actual del juego (nombre + datos)
  players: Player[]          // jugadores conectados en la sala

  setGameId(gameId)
  setStatus(name, data)      // crea un objeto { name, data } tipado
  resetStatus()              // status = null
  setPlayers(players)
  reset()                    // vuelve a { gameId: null, status: null, players: [] }
}
```

**Quién lo usa:**
- `AuthManagerPage` — para gestionar gameId y status al crear/reconectar partidas
- `ManagerGamePage` — para actualizar status con eventos del socket
- `GameWrapper` — para acceder al status y mostrar el componente correcto

**Cuando se hace `reset()`:**
- Al hacer logout
- Al recibir `game:reset`
- Al terminar la partida manualmente

---

## usePlayerStore — Estado del Jugador

**Archivo:** `packages/web/src/features/game/stores/player.tsx`  
**Librería:** Zustand  
**Persistencia:** ✅ Persiste en `localStorage["player-session"]`

```typescript
type PlayerStore = {
  gameId: string | null            // ID de la partida actual
  player: { username?, points? } | null  // datos del jugador
  status: Status | null            // estado del juego

  setGameId(gameId)
  setPlayer(state)
  login(username)     // guarda solo el username
  join(gameId)        // establece gameId + resetea points a 0
  updatePoints(points)
  setStatus(name, data)
  reset()
}
```

**Campos persistidos** (solo estos van a localStorage):
```typescript
partialize: (state) => ({
  gameId: state.gameId,
  player: state.player,
  status: state.status,
})
```

**Por qué persiste:** Si el jugador recarga la página, puede reconectar a su partida con el mismo `gameId`, `username` y estado de juego.

**Flujo de reconexión del jugador:**
1. Recarga la página → Zustand carga el estado de `localStorage["player-session"]`
2. El componente lee `gameId` del store
3. `PlayerGamePage` emite `player:reconnect { gameId }`
4. Servidor responde `player:successReconnect { gameId, status, player, currentQuestion }`
5. Store se actualiza con el estado actual del juego

---

## useQuestionStore — Progreso de Pregunta

**Archivo:** `packages/web/src/features/game/stores/question.tsx`  
**Librería:** Zustand  
**Persistencia:** ❌ No persiste

```typescript
type QuestionStore = {
  questionStates: { current: number; total: number } | null
  setQuestionStates(state)
}
```

**Quién emite el evento:** El servidor envía `game:updateQuestion { current, total }` al inicio de cada ronda.

**Quién lo escucha:** `GameWrapper` — registra el handler y muestra el indicador `X / N` en la esquina superior.

**Por qué está separado:** Este estado es el mismo para manager y jugadores, y es usado directamente por `GameWrapper` sin necesidad de pasar por el store del manager o del jugador.

---

## Relación entre stores y eventos WebSocket

```
Evento socket                    → Acción en store
─────────────────────────────────────────────────────
game:status (en ManagerGamePage) → useManagerStore.setStatus(name, data)
game:status (en PlayerGamePage)  → usePlayerStore.setStatus(name, data)
game:updateQuestion              → useQuestionStore.setQuestionStates({current, total})
manager:newPlayer                → (state local en AuthManagerPage, no en store)
player:successReconnect          → usePlayerStore.setGameId + setStatus + setPlayer
manager:successReconnect         → useManagerStore.setGameId + setStatus + setPlayers
game:reset                       → useManagerStore.reset() o usePlayerStore.reset()
manager:gameCreated              → useManagerStore.setGameId + setStatus
```

---

## createStatus — Helper de tipado

**Archivo:** `packages/web/src/features/game/utils/createStatus.ts`

```typescript
const createStatus = (name, data) => ({ name, data })
```

Función auxiliar usada en los stores para crear objetos de status tipados. Su importancia está en el tipado TypeScript — asegura que `name` y `data` sean consistentes según `StatusDataMap`.
