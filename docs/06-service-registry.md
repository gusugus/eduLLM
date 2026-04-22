# Servicio Registry

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/registry.ts` (167 líneas)  
> **Relacionado con:** [05-service-game](./05-service-game.md) · [15-scoring-timings](./15-scoring-timings.md)

---

## Responsabilidad

`Registry` es el **registro central en memoria** de todas las partidas activas (`Game` instances). Es un **Singleton** — existe una sola instancia durante toda la vida del proceso.

Mantiene dos listas:
- `games[]` — todas las partidas activas
- `emptyGames[]` — partidas cuyo manager se desconectó (para limpiarlas después de un tiempo)

---

## Arquitectura: Singleton

```typescript
class Registry {
  private static instance: Registry | null = null
  private games: Game[] = []
  private emptyGames: EmptyGame[] = []

  static getInstance(): Registry {
    Registry.instance ||= new Registry()
    return Registry.instance
  }

  private constructor() {
    this.startCleanupTask()  // inicia el timer de limpieza al crear
  }
}
```

Ambos `index.ts` y `game.ts` usan `Registry.getInstance()`.

---

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `EMPTY_GAME_TIMEOUT_MINUTES` | `5` minutos | Tiempo que espera antes de eliminar una partida sin manager |
| `CLEANUP_INTERVAL_MS` | `60.000 ms` (1 min) | Cada cuánto ejecuta la limpieza |

---

## Métodos de gestión de partidas

### `addGame(game)`
Agrega una instancia `Game` al array. Loguea el total actual.

### `removeGame(gameId) → boolean`
Elimina de `games` y `emptyGames`. Devuelve `true` si se eliminó algo.

### Métodos de búsqueda

| Método | Busca por |
|--------|----------|
| `getGameById(gameId)` | UUID de la partida |
| `getGameByInviteCode(inviteCode)` | Código de 6 dígitos |
| `getPlayerGame(gameId, clientId)` | Partida que contiene al jugador con ese `clientId` |
| `getManagerGame(gameId, clientId)` | Partida donde el manager tiene ese `clientId` |
| `getGameByManagerAccountId(managerId)` | Partida del manager (por UUID de cuenta) |
| `getGameByManagerSocketId(socketId)` | Partida del manager (por socket.id actual) |
| `getGameByPlayerSocketId(socketId)` | Partida que contiene al jugador con ese socket.id |

### `getAllGames() → Game[]`
Devuelve una **copia** del array (spread `[...this.games]`), no el array original.

---

## El sistema de partidas vacías

Cuando el manager se desconecta durante una partida en curso, la partida no se elimina inmediatamente — el manager podría reconectar. En cambio:

```
manager.disconnect (index.ts)
  └── managerGame.manager.connected = false
  └── registry.markGameAsEmpty(managerGame)
        └── agrega { since: timestamp, game } a emptyGames[]
```

Si el manager reconecta:
```
manager:reconnect o manager:takeOverGame
  └── game.reconnect(socket) → activateManagerControl()
  └── registry.reactivateGame(gameId)
        └── elimina de emptyGames[]
```

Si el manager NO reconecta en 5 minutos:
```
cleanupEmptyGames() [cada 60s]
  └── calcula tiempo transcurrido con dayjs
  └── elimina del array games[] las partidas expiradas
  └── loguea cuántas eliminó
```

**Resultado:** Los jugadores en partidas con manager desconectado reciben `game:reset` cuando el Registry limpia la partida (vía el `game:reset` que emite el sistema de desconexión en `index.ts`).

> ⚠️ En la implementación actual, cuando el manager se desconecta **y la partida no ha iniciado**, se llama directamente a `registry.removeGame()` (no a `markGameAsEmpty`). Solo las partidas ya iniciadas van a la lista de vacías.

---

## Cleanup Task automático

El constructor de Registry llama a `startCleanupTask()`:

```typescript
private startCleanupTask(): void {
  this.cleanupInterval = setInterval(() => {
    this.cleanupEmptyGames()
  }, this.CLEANUP_INTERVAL_MS)  // cada 60 segundos
}
```

`cleanupEmptyGames()` lógica:
```typescript
private cleanupEmptyGames(): void {
  const now = dayjs()
  const stillEmpty = this.emptyGames.filter(g =>
    now.diff(dayjs.unix(g.since), "minute") < this.EMPTY_GAME_TIMEOUT_MINUTES
  )
  // elimina del array games[] las que ya superaron el timeout
  const removedGameIds = removed.map(r => r.game.gameId)
  this.games = this.games.filter(g => !removedGameIds.includes(g.gameId))
  this.emptyGames = stillEmpty
}
```

---

## Shutdown graceful

En `index.ts`:
```typescript
process.on("SIGINT",  () => { Registry.getInstance().cleanup(); process.exit(0) })
process.on("SIGTERM", () => { Registry.getInstance().cleanup(); process.exit(0) })
```

`cleanup()` detiene el interval y vacía ambos arrays.

---

## Uso de `dayjs`

Registry usa la librería `dayjs` para calcular diferencias de tiempo:
```typescript
now.diff(dayjs.unix(g.since), "minute")
```
`g.since` es un Unix timestamp (segundos) obtenido con `dayjs().unix()`.

---

## Resumen visual

```
Registry (singleton)
├── games: Game[]
│   ├── Game { gameId: "abc", inviteCode: "123456", started: true, ... }
│   ├── Game { gameId: "def", inviteCode: "789012", started: false, ... }
│   └── ...
│
└── emptyGames: EmptyGame[]
    ├── { since: 1713456000, game: Game {...} }  ← manager desconectado hace 2 min
    └── ...

[cada 60s] → cleanupEmptyGames()
  → elimina las que llevan > 5 min en emptyGames
```
