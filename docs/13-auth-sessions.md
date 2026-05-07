# Autenticación y Sesiones

> **Parte de:** [Índice](./INDEX.md)  
> **Relacionado con:** [04-service-accountstore](./04-service-accountstore.md) · [08-service-oidc](./08-service-oidc.md) · [11-frontend-stores](./11-frontend-stores.md)

---

## Principio general: sin cookies

MindBuzz **no usa cookies en ninguna parte**. La autenticación se gestiona con:
- **Memoria del proceso Node.js** (para la sesión del manager)
- **`localStorage` del navegador** (para persistir el estado entre recargas)
- **Socket.IO auth** (para identificar el dispositivo en el handshake)

---

## Identidad del dispositivo: `clientId`

El `clientId` es la pieza central del sistema de sesiones. Es un **UUID v7** generado una sola vez por dispositivo y guardado en `localStorage["client_id"]`.

```
Primera visita:
  localStorage["client_id"] → no existe
  → genera UUID v7 nuevo
  → lo guarda en localStorage
  → lo envía en el handshake de Socket.IO

Visitas siguientes:
  localStorage["client_id"] → "01959a4b-..."
  → lo lee y lo envía en el handshake
```

**En el servidor:** el `clientId` llega en `socket.handshake.auth.clientId`. `getSocketClientId(socket)` lo extrae.

---

## Autenticación de Managers — Flujo usuario/contraseña

### Login

```
1. Manager ingresa username + password en el formulario
2. Frontend → socket.emit("manager:auth", { username, password })
3. Servidor:
   a. AccountStore.authenticateManager(username, password)
   b. Si ok: authenticatedManagers.set(clientId, { id, username, role })
   c. emitManagerDashboard(socket, manager)  → emite 7 eventos
4. Frontend recibe manager:authSuccess { manager }
   → setIsAuth(true) + setManager(manager)
   → localStorage["manager_auth"] = "true"
```

### Dónde vive la sesión del manager

```typescript
// En index.ts — Map en memoria del proceso Node.js
const authenticatedManagers = new Map<string, ManagerSession>()
//              clientId(string) → { id, username, role }
```

**Nunca se persiste en disco** — si el servidor se reinicia, todos los managers quedan "deslogueados" (aunque el frontend cree que sigue logueado).

### Verificación de autenticación

Cada handler de socket que requiere autenticación llama:

```typescript
const requireAuthenticatedManager = (socket) => {
  const clientId = getSocketClientId(socket)
  const manager = authenticatedManagers.get(clientId)
  if (!manager) {
    socket.emit("manager:errorMessage", "Manager authentication required")
    return null
  }
  return manager
}
```

Si el mensaje de error es exactamente `"Manager authentication required"`, el frontend limpia el estado local y muestra el login.

### Verificación de rol Admin

```typescript
const requireAdminManager = (socket) => {
  const manager = requireAuthenticatedManager(socket)
  if (!manager) return null
  if (manager.role !== "admin") {
    socket.emit("manager:errorMessage", "Admin access required")
    return null
  }
  return manager
}
```

### Reconexión automática

Si el manager recarga la página:

```
1. Frontend lee localStorage["manager_auth"] === "true"
2. Socket conecta → emite manager:getBootstrapState
3. Servidor responde manager:bootstrapState { requiresSetup: false }
4. Frontend detecta: isAuth && !requiresSetup && !manager
   → emite manager:getDashboard
5. Servidor llama requireAuthenticatedManager(socket)
   → si el clientId está en authenticatedManagers → ok (proceso no se reinició)
   → si no está → emite "Manager authentication required" → login de nuevo
```

### Logout

```
Frontend → socket.emit("manager:logout")
Servidor:
  1. authenticatedManagers.delete(clientId)
  2. revokeControlledGameForClient(clientId, "Manager logged out")  → termina partida activa
Frontend:
  1. localStorage.removeItem("manager_auth")
  2. limpia todo el estado local
  3. navega a /manager
```

---

## Autenticación SSO/OIDC — Flujo desde el cliente

Ver [08-service-oidc](./08-service-oidc.md) para el flujo completo en el servidor.

**Desde el punto de vista del frontend:**

```
1. Manager hace click en "Sign in with SSO"
   └── Solo disponible si oidcStatus.enabled && oidcStatus.configured
   └── Se obtiene oidcStatus desde GET /auth/oidc/status al cargar la página

2. Frontend construye URL y navega:
   window.location.assign(`/auth/oidc/login?clientId=${clientId}&returnTo=/manager`)
   ← Abandona la SPA, navega fuera

3. Usuario autentica en el proveedor externo...

4. Proveedor redirige al servidor: /auth/oidc/callback
   Servidor procesa y redirige a: /manager?oidc=success

5. SPA carga de nuevo en /manager
   useEffect detecta params.get("oidc") === "success"
   → setPendingOidcCompletion(true)
   → navigate(pathname, { replace: true })  // limpia ?oidc=success de la URL

6. Cuando el socket conecta Y pendingOidcCompletion === true:
   → socket.emit("manager:completeOidcLogin")
   → setPendingOidcCompletion(false)

7. Servidor responde igual que un login normal (manager:authSuccess + dashboard)
```

---

## Sesión de Jugadores — Sin autenticación real

Los jugadores NO se autentican. Su identidad es:

| Dato | Dónde | Cuándo se crea |
|------|-------|---------------|
| `clientId` | `localStorage["client_id"]` | Primera visita al sitio |
| `username` | `localStorage["player-session"]` (Zustand) | Al unirse a una partida |
| `gameId` | `localStorage["player-session"]` (Zustand) | Al unirse a una partida |
| `socket.id` | En memoria, cambia en cada conexión | Cada vez que conecta el socket |

### Reconexión del jugador

```
Jugador recarga la página → Zustand carga el estado de localStorage
PlayerGamePage detecta gameId en el store
  → cuando socket conecta → emite player:reconnect { gameId }
  ← servidor responde player:successReconnect { gameId, status, player, currentQuestion }
  → store se actualiza con el estado actual del servidor
```

El servidor identifica al jugador por `clientId` (del handshake) y `gameId`. Si la partida sigue activa, reconecta al jugador con su username, puntos y estado de juego actuales.

---

## localStorage — Resumen de claves

| Clave | Valor | Persistencia | Propósito |
|-------|-------|-------------|-----------|
| `client_id` | UUID v7 | Permanente | Identifica el dispositivo |
| `manager_auth` | `"true"` | Hasta logout | ¿El manager estaba logueado? |
| `player-session` | JSON (Zustand) | Hasta `reset()` | Estado del jugador (gameId, username, puntos, status) |

---

## Tabla de expiración de sesiones

| Sesión | Cómo expira |
|--------|------------|
| Manager en servidor | Proceso Node.js reinicia (Map en memoria se pierde) |
| Manager en cliente | `localStorage["manager_auth"]` se borra al hacer logout o al recibir el error de auth |
| Jugador en cliente | `localStorage["player-session"]` se borra al llamar `reset()` (en `game:reset`) |
| Estado OIDC pendiente | 10 minutos (TTL en `authorizationStates`) |
| Handoff de login SSO | 2 minutos (TTL en `loginHandoffs`) |
| Partida sin manager | 5 minutos (cleanup del Registry) |
| Jugador desconectado | 60 segundos (grace period antes de eliminar del juego) |

---

## Seguridad: lo que hay y lo que no hay

**Lo que SÍ existe:**
- Contraseñas hasheadas con `scrypt` + salt aleatorio por contraseña
- Comparación de contraseñas con `timingSafeEqual` (anti-timing attack)
- PKCE en el flujo OIDC (anti-code-interception)
- Validación de `nonce` en el ID token
- Sanitización de filenames al subir media
- Protección contra path traversal en `/media/`
- Validación de inputs con Zod

**Lo que NO existe (trade-offs conscientes):**
- No verifica la firma criptográfica de los JWT del proveedor OIDC
- No hay rate limiting en los eventos de socket
- No hay tokens de sesión con tiempo de expiración para managers
- La sesión del manager muere con el proceso (no persiste en BD)
- El `clientSecret` OIDC se guarda en texto plano en JSON
