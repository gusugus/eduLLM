# Frontend — Router, Páginas y Layouts

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:**  
> - `packages/web/src/router.tsx`  
> - `packages/web/src/main.tsx`  
> - `packages/web/src/pages/game/`  
> **Relacionado con:** [11-frontend-stores](./11-frontend-stores.md) · [12-frontend-components](./12-frontend-components.md) · [13-auth-sessions](./13-auth-sessions.md)

---

## Punto de entrada: `main.tsx`

```tsx
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Router />     {/* Rutas con React Router v7 */}
    <Toaster />    {/* Notificaciones toast globales (react-hot-toast) */}
  </StrictMode>
)
```

`<Toaster />` está **fuera del router** — las notificaciones funcionan en todas las páginas.

---

## Estructura de rutas

```
/                       → GameLayout
├── /                   → AuthLayout
│   ├── /               → PlayerAuthPage   (jugador: ingresa código y username)
│   └── /manager        → AuthManagerPage  (manager: login + dashboard completo)
│
├── /party/:gameId      → PlayerGamePage   (jugador: partida activa)
└── /party/manager/:gameId → ManagerGamePage (manager: controlando partida)
```

---

## GameLayout — `pages/game/layout.tsx`

**Wrappea toda la aplicación.** Proporciona el contexto de Socket.IO.

```tsx
export const GameLayout = () => (
  <SocketProvider>          {/* contexto de WebSocket */}
    <GameLayoutWrapped />   {/* conecta el socket automáticamente */}
  </SocketProvider>
)
```

`GameLayoutWrapped` conecta el socket si no está conectado:
```tsx
useEffect(() => {
  if (!isConnected) connect()
}, [connect, isConnected])
```

También aplica la clase CSS `bg-secondary` al `document.body`.

---

## AuthLayout — `pages/game/auth/layout.tsx`

Layout visual de la sección de autenticación. Contiene el **Outlet** para `PlayerAuthPage` y `AuthManagerPage`.

---

## PlayerAuthPage — `pages/game/auth/page.tsx`

**Ruta:** `/`  
**Quién lo ve:** Jugadores que quieren unirse a una partida.

Flujo:
1. Muestra formulario de código de sala (componente `join/Room.tsx`)
2. Al enviar: `socket.emit("player:join", inviteCode)`
3. Escucha `game:successRoom` → guarda `gameId`, muestra formulario de username
4. Al enviar username: `socket.emit("player:login", { gameId, data: { username } })`
5. Escucha `game:successJoin` → navega a `/party/:gameId`

---

## AuthManagerPage — `pages/game/auth/manager/page.tsx`

**Ruta:** `/manager`  
**Quién lo ve:** Managers. Es la página más compleja del frontend (653 líneas).

### Estados de la página

```
requiresSetup === null          → "Loading manager panel..." (cargando)
!isAuth && requiresSetup        → InitialAdminSetup (primer uso)
!isAuth && !requiresSetup       → ManagerPassword (login)
isAuth && manager === null      → "Restoring manager session..." (reconectando)
isAuth && editingQuizz          → QuizzEditor (editando un quiz)
isAuth && !editingQuizz         → Dashboard con tabs
```

### Tabs del dashboard

| Tab | Visible para | Componente |
|-----|-------------|-----------|
| `quizzes` | Todos | `SelectQuizz` |
| `history` | Todos | `HistoryPanel` |
| `settings` | Todos | `SettingsPanel` |
| `managers` | Solo admin | `ManagersPanel` |
| `sso` | Solo admin | `SsoSettingsPanel` |

### Gestión del estado de autenticación

La página usa `localStorage["manager_auth"] = "true"` para recordar que el manager está autenticado. Al reconectar el socket, si hay `"true"` en localStorage, emite `manager:getDashboard` automáticamente.

Si el servidor responde `manager:errorMessage` con `"Manager authentication required"`, limpia todo el estado local y muestra el login.

### Gestión del login SSO

```typescript
// Al cargar: detecta query params ?oidc=success o ?oidc=error
const oidcResult = params.get("oidc")
if (oidcResult === "success") {
  setPendingOidcCompletion(true)
  navigate(pathname, { replace: true })  // limpia query params
}

// Cuando socket conecta y pendingOidcCompletion:
socket.emit("manager:completeOidcLogin")
```

### Función de logout

Limpia todo el estado local + emite `manager:logout` al servidor + navega a `/manager`.

---

## ManagerGamePage — `pages/game/party/manager/page.tsx`

**Ruta:** `/party/manager/:gameId`  
**Quién lo ve:** El manager controlando la partida activa.

Escucha eventos:
- `game:status` → actualiza el store del manager con el nuevo estado
- `connect` → emite `manager:reconnect` automáticamente (para reconexión)
- `manager:successReconnect` → restaura estado tras reconexión
- `game:reset` → navega a `/manager` y limpia estado
- `manager:historyExportReady` → descarga CSV

### Botón de acción ("Next", "Skip", "Start Game", "End Quiz")

El botón está en `GameWrapper`. Al presionarlo, dispara `handleSkip()`:

```typescript
const handleSkip = () => {
  if (status.name === STATUS.FINISHED) {
    socket.emit("manager:endGame", { gameId })
    navigate("/manager")
    return
  }
  if (isKeyOf(MANAGER_SKIP_EVENTS, status.name)) {
    socket.emit(MANAGER_SKIP_EVENTS[status.name], { gameId })
  }
}
```

Mapa de STATUS → evento emitido al presionar el botón:

| STATUS | Botón | Evento emitido |
|--------|-------|---------------|
| `SHOW_ROOM` | "Start Game" | `manager:startGame` |
| `SELECT_ANSWER` | "Skip" | `manager:abortQuiz` |
| `SHOW_RESPONSES` | "Next" | `manager:showLeaderboard` |
| `SHOW_LEADERBOARD` | "Next" | `manager:nextQuestion` |
| `FINISHED` | "End Quiz" | `manager:endGame` |

---

## PlayerGamePage — `pages/game/party/page.tsx`

**Ruta:** `/party/:gameId`  
**Quién lo ve:** El jugador durante la partida.

Escucha eventos:
- `connect` → emite `player:reconnect` automáticamente
- `player:successReconnect` → restaura estado
- `game:status` → actualiza el store del jugador
- `game:reset` → navega a `/` y limpia estado

### Reconexión automática al volver al tab

```typescript
useEffect(() => {
  const attemptReconnect = () => {
    if (!socket?.connected) reconnect()
  }

  window.addEventListener("focus", attemptReconnect)
  window.addEventListener("pageshow", attemptReconnect)
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") attemptReconnect()
  })
}, [gameIdParam, reconnect, socket])
```

Detecta cuando el usuario vuelve a la pestaña y reconecta el socket si está desconectado.

---

## Renderizado dinámico de componentes

Tanto `PlayerGamePage` como `ManagerGamePage` usan el mismo patrón:

```typescript
const CurrentComponent =
  status && isKeyOf(GAME_STATE_COMPONENTS_MANAGER, status.name)
    ? GAME_STATE_COMPONENTS_MANAGER[status.name]
    : null

return (
  <GameWrapper statusName={status?.name} onNext={handleSkip} manager>
    {CurrentComponent && <CurrentComponent data={status!.data as never} />}
  </GameWrapper>
)
```

`GAME_STATE_COMPONENTS` mapea cada STATUS a su componente React correspondiente. Ver [12-frontend-components](./12-frontend-components.md).

---

## Navegación programática

| Acción | Navegación |
|--------|-----------|
| Game creada | `/party/manager/:gameId` |
| Manager reconecta a partida | `/party/manager/:gameId` |
| `game:reset` (manager) | `/manager` |
| `game:reset` (jugador) | `/` |
| Jugador se une exitosamente | `/party/:gameId` |
| Logout | `/manager` |
| End Game | `/manager` |
