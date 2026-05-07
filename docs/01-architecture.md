# Arquitectura General

> **Parte de:** [Índice](./INDEX.md)  
> **Relacionado con:** [09-websocket-events](./09-websocket-events.md) · [02-database](./02-database.md) · [01-architecture](./01-architecture.md)

---

## ¿Qué es MindBuzz?

Aplicación de quizzes en tiempo real estilo Kahoot. Un **manager** crea y controla la partida; múltiples **jugadores** se unen con un código de 6 dígitos y responden preguntas simultáneamente.

---

## Stack tecnológico

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Frontend | React + Vite | React 19 · Vite 7 |
| Estilos | TailwindCSS v4 | v4.2 |
| Estado global | Zustand | v5 |
| Routing SPA | React Router | v7 |
| Animaciones | Motion (framer) | v12 |
| Notificaciones | react-hot-toast | v2 |
| WebSockets (cliente) | socket.io-client | v4.8 |
| WebSockets (servidor) | socket.io | v4.8 |
| Backend | Node.js + TypeScript | Node 24 |
| Base de datos | SQLite nativa | `node:sqlite` (Node 24) |
| Monorepo | pnpm workspaces | pnpm 10 |
| Contenedores | Docker + Nginx + supervisord | node:24-alpine |

---

## Diagrama de arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                     BROWSER (Puerto 3000)                       │
│                                                                 │
│   ┌─────────────────────────────────────────┐                  │
│   │        React SPA (@mindbuzz/web)         │                  │
│   │                                         │                  │
│   │  SocketProvider (socket.io-client)       │                  │
│   │  ┌────────────────┐ ┌──────────────────┐│                  │
│   │  │  Manager SPA   │ │   Player SPA     ││                  │
│   │  │  /manager      │ │   /             ││                  │
│   │  │  /party/mgr/id │ │   /party/:id    ││                  │
│   │  └────────────────┘ └──────────────────┘│                  │
│   └─────────────────────────────────────────┘                  │
│                         │ WebSocket /ws                         │
│                         │ HTTP /auth /media                     │
└─────────────────────────┼───────────────────────────────────────┘
                          │ (En dev: proxiado por Vite)
                          │ (En prod: proxiado por Nginx)
┌─────────────────────────▼───────────────────────────────────────┐
│           Servidor Node.js (@mindbuzz/socket) Puerto 3001        │
│                                                                 │
│  HTTP Server                   Socket.IO Server                 │
│  ├── GET /auth/oidc/status      ├── path: /ws                   │
│  ├── GET /auth/oidc/login       └── maxBuffer: 25MB             │
│  ├── GET /auth/oidc/callback                                    │
│  └── GET /media/*                                               │
│                                                                 │
│  Servicios en memoria y filesystem:                             │
│  Config · AccountStore · Game · Registry · History              │
│  OidcAuth · OidcStore · Quizz (helpers)                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              SQLite  config/history.db                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Filesystem:                                                    │
│  config/game.json · config/auth.json · config/quizz/*.json     │
│  media/*.mp3 · media/*.wav · ...                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Estructura de paquetes (monorepo)

```
MindBuzz/                        ← raíz del monorepo
├── packages/
│   ├── common/                  ← @mindbuzz/common  (tipos + utils compartidos)
│   ├── socket/                  ← @mindbuzz/socket  (servidor Node.js)
│   └── web/                     ← @mindbuzz/web     (frontend React)
├── config/                      ← datos de configuración (fuera del código)
├── media/                       ← archivos de audio subidos
├── docker/                      ← nginx.conf + supervisord.conf
├── Dockerfile
├── compose.yml
└── docs/                        ← esta documentación
```

El paquete `common` es importado por `socket` y `web`. Los tres comparten los mismos tipos TypeScript, evitando duplicación y garantizando consistencia entre cliente y servidor.

---

## Estructura interna de cada paquete

### `packages/socket/src/`

```
index.ts              ← punto de entrada: HTTP server + Socket.IO + todos los eventos
services/
  database.ts         ← wrapper SQLite singleton
  accountStore.ts     ← CRUD managers y quizzes
  game.ts             ← clase Game (lógica de partida)
  registry.ts         ← registro en memoria de Games activos
  history.ts          ← historial de partidas en SQLite
  config.ts           ← lectura/escritura de JSON en filesystem
  oidcAuth.ts         ← flujo OIDC/PKCE
  oidcStore.ts        ← identidades OIDC en SQLite
  quizz.ts            ← helpers de normalización/validación
utils/
  game.ts             ← withGame(), createInviteCode(), timeToPoint()
  sleep.ts            ← sleep(seconds)
```

### `packages/web/src/`

```
main.tsx              ← punto de entrada React
router.tsx            ← rutas de la SPA
index.css             ← estilos globales (Tailwind)
assets/               ← background.webp, logo.svg
hooks/
  useScreenSize.ts
features/game/
  contexts/
    socketProvider.tsx ← Context WebSocket + hooks useSocket/useEvent
  stores/
    manager.tsx        ← Zustand store del manager en partida
    player.tsx         ← Zustand store del jugador (persistido en localStorage)
    question.tsx       ← estado de pregunta actual
  components/
    GameWrapper.tsx    ← layout compartido de partida
    states/            ← un componente por STATUS del juego
    create/            ← componentes del panel del manager
    join/              ← formularios de entrada del jugador
    icons/             ← SVG como componentes React
  utils/
    constants.ts       ← mapas STATUS→Componente, sonidos, colores
    createStatus.ts
    score.ts
pages/game/
  layout.tsx           ← GameLayout con SocketProvider
  auth/                ← login manager + entrada jugador
  party/               ← pages de partida activa
```

### `packages/common/src/`

```
types/game/
  index.ts    ← todos los tipos de dominio (Player, Quiz, Manager, etc.)
  socket.ts   ← tipos de eventos Socket.IO (ClientToServer, ServerToClient)
  status.ts   ← STATUS enum + StatusDataMap
validators/
  auth.ts     ← usernameValidator, inviteCodeValidator (Zod)
utils/
  audio.ts    ← normalizeAudioUrl, isAudioUrlAllowed
```

---

## Despliegue

### Desarrollo local

```bash
pnpm install
pnpm dev        # corre web (:3000) y socket (:3001) en paralelo

# o por separado:
pnpm dev:web    # solo Vite dev server (:3000)
pnpm dev:socket # solo tsx watch (:3001)
```

**Proxy en desarrollo (Vite):**

| Ruta | Target |
|------|--------|
| `/auth/*` | `http://localhost:3001` |
| `/media/*` | `http://localhost:3001` |
| `/ws` | `http://localhost:3001` (WebSocket) |

### Producción con Docker

**Multi-stage build:**
1. **builder**: instala deps con pnpm, ejecuta `pnpm build` (genera `/app/packages/web/dist` y `/app/packages/socket/dist/index.cjs`)
2. **runner**: imagen limpia con Nginx + supervisord · copia solo los artefactos compilados

**supervisord** gestiona dos procesos dentro del contenedor:
- Nginx (sirve la SPA estática + actúa como proxy reverso)  
- Node.js (ejecuta `socket/index.cjs` · Puerto 3001)

**Docker Compose** monta dos volúmenes para persistencia:
- `./config:/app/config` — configuración y base de datos
- `./media:/app/media` — archivos de audio subidos

**Variable de entorno en Docker:**
```
CONFIG_PATH=/app/config
```
El servidor la usa para localizar `history.db`, `game.json`, `auth.json` y el directorio de quizzes.

---

## Puertos

| Puerto | Quién lo usa | Descripción |
|--------|-------------|-------------|
| `3000` | Vite dev / Nginx prod | Punto de entrada del usuario (HTTP) |
| `3001` | Node.js servidor | WebSocket + HTTP interno (nunca expuesto directamente al usuario) |
