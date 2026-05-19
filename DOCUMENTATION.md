# eduLLM — Documentación Técnica Completa

> Versión del proyecto: `1.10.2`  
> Fecha de documentación: 2026-04-20  
> Propósito: Referencia exhaustiva para desarrollo, mantenimiento y planificación de cambios.

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura General](#2-arquitectura-general)
3. [Estructura de Directorios](#3-estructura-de-directorios)
4. [Paquete `@edullm/socket` — Servidor WebSocket/HTTP](#4-paquete-edullmsocket--servidor-websockethttp)
   - [Punto de entrada `index.ts`](#41-punto-de-entrada-indexts)
   - [Servicio `Database`](#42-servicio-database)
   - [Servicio `AccountStore`](#43-servicio-accountstore)
   - [Servicio `Game`](#44-servicio-game)
   - [Servicio `Registry`](#45-servicio-registry)
   - [Servicio `History`](#46-servicio-history)
   - [Servicio `Config`](#47-servicio-config)
   - [Servicio `OidcAuth`](#48-servicio-oidcauth)
   - [Servicio `OidcStore`](#49-servicio-oidcstore)
   - [Servicio `Quizz` (helpers)](#410-servicio-quizz-helpers)
   - [Utils del socket](#411-utils-del-socket)
5. [Paquete `@edullm/common` — Tipos Compartidos](#5-paquete-edullmcommon--tipos-compartidos)
   - [Tipos del juego](#51-tipos-del-juego)
   - [Tipos de socket (eventos)](#52-tipos-de-socket-eventos)
   - [Tipos de estado (`STATUS`)](#53-tipos-de-estado-status)
   - [Validadores](#54-validadores)
   - [Utils comunes](#55-utils-comunes)
6. [Paquete `@edullm/web` — Frontend React](#6-paquete-edullmweb--frontend-react)
   - [Punto de entrada y router](#61-punto-de-entrada-y-router)
   - [Rutas y páginas](#62-rutas-y-páginas)
   - [Context: `SocketProvider`](#63-context-socketprovider)
   - [Stores (Zustand)](#64-stores-zustand)
   - [Componentes de estado del juego](#65-componentes-de-estado-del-juego)
   - [Componentes del panel Manager](#66-componentes-del-panel-manager)
   - [Componentes de join/lobby](#67-componentes-de-joinlobby)
   - [Componentes generales](#68-componentes-generales)
   - [Íconos SVG](#69-íconos-svg)
   - [Utils del frontend](#610-utils-del-frontend)
7. [Flujo Completo de Eventos WebSocket](#7-flujo-completo-de-eventos-websocket)
   - [Eventos Cliente → Servidor](#71-eventos-cliente--servidor)
   - [Eventos Servidor → Cliente](#72-eventos-servidor--cliente)
8. [Estados del Juego (`STATUS`)](#8-estados-del-juego-status)
9. [Autenticación y Sesiones](#9-autenticación-y-sesiones)
   - [Autenticación de Managers (usuario/contraseña)](#91-autenticación-de-managers-usuariocontraseña)
   - [Autenticación SSO/OIDC](#92-autenticación-ssooídc)
   - [Sesión de Jugadores](#93-sesión-de-jugadores)
   - [Sin cookies — Todo en memoria + localStorage](#94-sin-cookies--todo-en-memoria--localstorage)
10. [Base de Datos SQLite](#10-base-de-datos-sqlite)
    - [Tablas](#101-tablas)
    - [Ubicación del archivo](#102-ubicación-del-archivo)
11. [Configuración del Sistema](#11-configuración-del-sistema)
    - [`config/game.json`](#111-configgamejson)
    - [`config/auth.json`](#112-configauthjson)
    - [`config/quizz/`](#113-configquizz)
    - [Variables de entorno](#114-variables-de-entorno)
12. [Tiempos y Timeouts del Sistema](#12-tiempos-y-timeouts-del-sistema)
13. [Archivos de Media](#13-archivos-de-media)
14. [Infraestructura y Despliegue](#14-infraestructura-y-despliegue)
    - [Desarrollo local](#141-desarrollo-local)
    - [Producción con Docker](#142-producción-con-docker)
    - [Proxy inverso (Nginx en Docker)](#143-proxy-inverso-nginx-en-docker)
15. [Flujo del Juego — Paso a Paso](#15-flujo-del-juego--paso-a-paso)
16. [Sistema de Puntuación](#16-sistema-de-puntuación)
17. [Mapa de Dónde Hacer Cambios](#17-mapa-de-dónde-hacer-cambios)

---

## 1. Resumen Ejecutivo

**eduLLM** es una aplicación de quizzes en tiempo real estilo Kahoot. Un _manager_ crea y controla una partida; múltiples _jugadores_ se unen con un código de invitación de 6 dígitos y responden preguntas de forma simultánea. El sistema calcula puntajes en función del tiempo de respuesta.

**Stack tecnológico:**

| Capa | Tecnología |
|------|-----------|
| Frontend | React 19 + Vite + TailwindCSS v4 + Zustand + React Router v7 |
| Comunicación | Socket.IO v4 (WebSockets) |
| Backend | Node.js (TypeScript) con servidor HTTP nativo |
| Base de datos | SQLite (historial local) + PostgreSQL (`pg`, cuentas y progreso) |
| Autenticación | Contraseña propia + OIDC/SSO opcional |
| Monorepo | pnpm workspaces |
| Contenedores | Docker (Nginx + Node.js supervisado) |

---

## 2. Arquitectura General

```
┌─────────────────────────────────────────────────────────────────┐
│                         BROWSER (Puerto 3000)                   │
│                                                                 │
│   ┌─────────────────────────────────────────┐                  │
│   │        React SPA (@edullm/web)         │                  │
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
│              Servidor Node.js (@edullm/socket) Puerto 3001     │
│                                                                 │
│  ┌──────────────────────┐  ┌────────────────────────────────┐  │
│  │   HTTP Server         │  │   Socket.IO Server             │  │
│  │  POST /api/students/* │  │   ws path: /ws                 │  │
│  │  GET /auth/oidc/...   │  │   maxBuffer: 25MB              │  │
│  │  GET /media/*         │  │                                │  │
│  └──────────────────────┘  └────────────────────────────────┘  │
│                                                                 │
│  Servicios:                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │AccountStr│ │  Game    │ │Registry  │ │ History  │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │  Config  │ │ OidcAuth │ │OidcStore │ │  Quizz   │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                PostgreSQL (edu_llm)                      │   │
│  │  esquemas: comun, admin, profesor, estudiante            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                SQLite (history.db)                       │   │
│  │  managers | manager_settings | quizzes |                 │   │
│  │  manager_oidc_identities | quiz_runs                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Filesystem:                                                    │
│  config/game.json | config/auth.json | config/quizz/*.json     │
│  media/*.mp3 | media/*.wav | ...                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Estructura de Directorios

```
eduLLM/
├── package.json              # Scripts raíz (dev, build, start, lint)
├── pnpm-workspace.yaml       # Workspaces: packages/*
├── tsconfig.json             # TS config base del monorepo
├── Dockerfile                # Build multi-etapa (builder + runner)
├── compose.yml               # Docker Compose: puerto 3000, volúmenes config/ media/
├── .release-please-manifest.json
├── CHANGELOG.md
│
├── config/                   # DATOS DE CONFIGURACIÓN (fuera del código)
│   ├── game.json             # { managerPassword, defaultAudio? }
│   ├── auth.json             # Configuración OIDC
│   ├── history.db            # Base de datos SQLite
│   └── quizz/               # JSON de quizzes (legacy, ahora en SQLite)
│       └── example.json
│
├── media/                    # Archivos de audio subidos
│
├── docker/
│   ├── nginx.conf            # Config Nginx para producción
│   └── supervisord.conf      # Supervisor: gestiona Nginx + Node
│
└── packages/
    ├── common/               # @edullm/common — Tipos y utils compartidos
    │   └── src/
    │       ├── types/game/
    │       │   ├── index.ts  # Todos los tipos de dominio
    │       │   ├── socket.ts # Tipos de eventos Socket.IO
    │       │   └── status.ts # STATUS enum + StatusDataMap
    │       ├── utils/
    │       │   └── audio.ts  # normalizeAudioUrl, isAudioUrlAllowed
    │       └── validators/
    │           └── auth.ts   # usernameValidator, inviteCodeValidator (Zod)
    │
    ├── socket/               # @edullm/socket — Servidor backend
    │   └── src/
    │       ├── index.ts      # Servidor HTTP + Socket.IO (punto de entrada)
    │       ├── controllers/
    │       │   └── studentController.ts  # Endpoint de login de estudiantes
    │       ├── repositories/
    │       │   └── studentRepository.ts  # Capa de datos para estudiantes
    │       ├── services/
    │       │   ├── database.ts     # Wrapper SQLite singleton
    │       │   ├── pgDatabase.ts   # Pool de conexión PostgreSQL
    │       │   ├── accountStore.ts # CRUD de managers y quizzes
    │       │   ├── game.ts         # Lógica de partida (clase Game)
    │       │   ├── registry.ts     # Registro en memoria de partidas activas
    │       │   ├── history.ts      # Historial de partidas en SQLite
    │       │   ├── config.ts       # Lee/escribe config JSON del filesystem
    │       │   ├── oidcAuth.ts     # Flujo OIDC/PKCE completo
    │       │   ├── oidcStore.ts    # CRUD identidades OIDC en SQLite
    │       │   └── quizz.ts        # normalizeQuizz, validaciones
    │       └── utils/
    │           ├── game.ts         # withGame, createInviteCode, timeToPoint
    │           └── sleep.ts        # sleep(seconds): Promise
    │
    └── web/                  # @edullm/web — Frontend React
        ├── index.html
        ├── vite.config.ts    # Puerto 3000, proxy a :3001 para /ws /auth /media
        └── src/
            ├── main.tsx      # Punto de entrada React
            ├── router.tsx    # Rutas de la SPA
            ├── index.css     # Estilos globales (Tailwind)
            ├── assets/       # background.webp, logo.svg
            ├── hooks/
            │   └── useScreenSize.ts
            ├── features/game/
            │   ├── contexts/
            │   │   └── socketProvider.tsx  # Context + hooks useSocket, useEvent
            │   ├── stores/
            │   │   ├── manager.tsx         # Zustand store del manager en partida
            │   │   ├── player.tsx          # Zustand store del jugador (persistido)
            │   │   └── question.tsx        # Estado de pregunta actual
            │   ├── components/
            │   │   ├── GameWrapper.tsx      # Wrapper de layout para partidas
            │   │   ├── AnswerButton.tsx
            │   │   ├── Button.tsx
            │   │   ├── Form.tsx
            │   │   ├── Input.tsx
            │   │   ├── Loader.tsx
            │   │   ├── Toaster.tsx
            │   │   ├── icons/              # SVG como componentes React
            │   │   │   ├── Circle.tsx
            │   │   │   ├── CricleCheck.tsx
            │   │   │   ├── CricleXmark.tsx
            │   │   │   ├── Pentagon.tsx
            │   │   │   ├── Rhombus.tsx
            │   │   │   ├── Square.tsx
            │   │   │   └── Triangle.tsx
            │   │   ├── states/             # Un componente por estado del juego
            │   │   │   ├── Room.tsx        # SHOW_ROOM (manager: sala de espera)
            │   │   │   ├── Start.tsx       # SHOW_START (cuenta regresiva inicio)
            │   │   │   ├── Prepared.tsx    # SHOW_PREPARED (se acerca pregunta)
            │   │   │   ├── Question.tsx    # SHOW_QUESTION (muestra pregunta)
            │   │   │   ├── Answers.tsx     # SELECT_ANSWER (jugador elige)
            │   │   │   ├── Wait.tsx        # WAIT (esperando)
            │   │   │   ├── Result.tsx      # SHOW_RESULT (resultado individual)
            │   │   │   ├── Responses.tsx   # SHOW_RESPONSES (manager: distribución)
            │   │   │   ├── Leaderboard.tsx # SHOW_LEADERBOARD (manager: tabla)
            │   │   │   └── Podium.tsx      # FINISHED (podio final)
            │   │   ├── create/             # Componentes del panel de manager
            │   │   │   ├── SelectQuizz.tsx
            │   │   │   ├── QuizzEditor.tsx
            │   │   │   ├── HistoryPanel.tsx
            │   │   │   ├── SettingsPanel.tsx
            │   │   │   ├── SsoSettingsPanel.tsx
            │   │   │   ├── ManagersPanel.tsx
            │   │   │   ├── ManagerPassword.tsx
            │   │   │   └── InitialAdminSetup.tsx
            │   │   └── join/               # Componentes de entrada del jugador
            │   │       ├── Room.tsx
            │   │       └── Username.tsx
            │   └── utils/
            │       ├── constants.ts        # Mapas STATUS→Componente, sonidos
            │       ├── createStatus.ts     # Helper para crear objetos status
            │       └── score.ts            # Utilidades de puntaje (frontend)
            └── pages/game/
                ├── layout.tsx              # GameLayout con SocketProvider
                ├── auth/
                │   ├── layout.tsx          # Layout de la sección auth
                │   ├── page.tsx            # Página del jugador (join room)
                │   ├── studentLogin/       
                │   │   └── page.tsx        # Login exclusivo para estudiantes
                │   └── manager/
                │       └── page.tsx        # Dashboard completo del manager
                └── party/
                    ├── page.tsx            # Página de jugador en partida
                    └── manager/
                        └── page.tsx        # Página de manager controlando partida
```

---

## 4. Paquete `@edullm/socket` — Servidor WebSocket/HTTP

### 4.1 Punto de entrada `index.ts`

**Archivo:** `packages/socket/src/index.ts` (878 líneas)

Crea el servidor HTTP nativo de Node.js y el servidor Socket.IO sobre él.

#### Variables globales clave

```typescript
const WS_PORT = 3001  // Puerto fijo del backend

// Mapa en memoria: clientId → ManagerSession
// NO persiste entre reinicios del proceso
const authenticatedManagers = new Map<string, ManagerSession>()

const registry = Registry.getInstance()  // Singleton de partidas activas
```

#### Rutas HTTP (además de WebSocket)

| Método | Ruta | Función |
|--------|------|---------|
| `GET` | `/auth/oidc/status` | Devuelve `OidcStatus` (enabled/configured) como JSON |
| `GET` | `/auth/oidc/login` | Inicia flujo OIDC; requiere `?clientId=&returnTo=`; redirige al proveedor |
| `GET` | `/auth/oidc/callback` | Callback del proveedor OIDC; procesa `code` y `state`; redirige al manager |
| `POST`| `/api/students/login` | Recibe JSON con `username` y `password`, autentica en DB y devuelve DTO del estudiante logueado |
| `GET` | `/media/*` | Sirve archivos de audio del directorio `media/`; `Cache-Control: public, max-age=3600` |
| Todo lo demás | — | `404 Not found` |

**Funciones auxiliares internas:**

| Función | Qué hace |
|---------|---------|
| `getMimeType(filename)` | Mapea extensión de audio a MIME type |
| `sendJson(res, status, body)` | Responde JSON con `Cache-Control: no-store` |
| `getRequestOrigin(req)` | Lee `x-forwarded-proto` y `x-forwarded-host` para construir URL base (funciona detrás de proxy) |
| `buildManagerRedirect(origin, returnTo, params)` | Construye URL de redirección al manager con query params |
| `getSocketClientId(socket)` | Lee `socket.handshake.auth.clientId` |
| `getAuthenticatedManager(socket)` | Busca en `authenticatedManagers` por clientId |
| `requireAuthenticatedManager(socket)` | Requiere manager autenticado; emite error si no |
| `requireAdminManager(socket)` | Requiere `role === "admin"`; emite error si no |
| `emitBootstrapState(socket)` | Emite `manager:bootstrapState` con `requiresSetup` |
| `emitManagerDashboard(socket, manager)` | Emite 7 eventos de estado al conectar un manager |
| `revokeControlledGameForClient(clientId, reason)` | Termina/aborta partida controlada por un clientId |
| `revokeManagerAccountAccess(managerId, reason)` | Revoca todos los clientes de un managerId y termina su partida |

#### Inicialización del servidor

```typescript
Config.init()        // Crea directorios y archivos de config si no existen
AccountStore.init()  // Inicializa BD y migra cuentas legacy
History.init()       // Inicializa BD
httpServer.listen(WS_PORT)
```

#### Manejadores de eventos Socket.IO

Todos los eventos se registran en `io.on("connection", (socket) => { ... })`.

**Eventos de Manager — Setup:**

| Evento recibido | Acción |
|----------------|--------|
| `manager:getBootstrapState` | Emite `manager:bootstrapState` |
| `manager:createInitialAdmin` | Crea admin inicial si no hay managers; autentica |
| `manager:auth` | Login usuario/contraseña; guarda en `authenticatedManagers` |
| `manager:completeOidcLogin` | Consume handoff OIDC en memoria; autentica |
| `manager:getDashboard` | Emite todos los datos del dashboard |
| `manager:logout` | Elimina de `authenticatedManagers`; aborta partida activa |

**Eventos de Manager — Administración:**

| Evento recibido | Requiere | Acción |
|----------------|---------|--------|
| `manager:listManagers` | admin | Lista managers |
| `manager:createManager` | admin | Crea manager |
| `manager:resetManagerPassword` | admin | Resetea contraseña |
| `manager:setManagerDisabled` | admin | Habilita/deshabilita cuenta |
| `manager:getOidcConfig` | admin | Devuelve config OIDC |
| `manager:updateOidcConfig` | admin | Guarda config OIDC |
| `manager:testOidcConfig` | admin | Prueba discovery URL |

**Eventos de Manager — Quizzes:**

| Evento recibido | Acción |
|----------------|--------|
| `manager:createQuizz` | Crea quiz en SQLite |
| `manager:updateQuizz` | Actualiza quiz en SQLite |
| `manager:deleteQuizz` | Borra quiz en SQLite |
| `manager:updateSettings` | Guarda configuración del manager (audio, etc.) |
| `manager:uploadMedia` | Sube archivo de audio al filesystem |
| `manager:downloadHistory` | Genera y devuelve CSV de historial |

**Eventos de Manager — Control de partida:**

| Evento recibido | Acción |
|----------------|--------|
| `game:create` | Instancia nueva `Game`; emite `manager:gameCreated` |
| `manager:reconnect` | Reconecta manager a su partida |
| `manager:takeOverGame` | Toma control de partida desde otro cliente |
| `manager:startGame` | Inicia la partida |
| `manager:kickPlayer` | Expulsa jugador |
| `manager:abortQuiz` | Aborta temporizador de respuesta |
| `manager:nextQuestion` | Avanza a la siguiente pregunta |
| `manager:showLeaderboard` | Muestra tabla de puntuajes |
| `manager:endGame` | Termina el juego |

**Eventos de Jugador:**

| Evento recibido | Acción |
|----------------|--------|
| `player:join` | Busca partida por código de invitación; devuelve `game:successRoom` |
| `player:login` | Une al jugador a la partida (`game.join`) |
| `player:reconnect` | Reconecta jugador a su partida |
| `player:selectedAnswer` | Registra respuesta del jugador |

**Evento de desconexión:**

`disconnect` — Gestiona cierre de partida o marcado como desconectado según estado.

---

### 4.2 Servicio `Database`

**Archivo:** `packages/socket/src/services/database.ts`

Singleton que provee la conexión SQLite usando la API nativa de Node.js 24 (`node:sqlite`).

**Métodos públicos:**

| Método | Descripción |
|--------|-------------|
| `Database.getDb()` | Devuelve la instancia singleton. La crea si no existe. |
| `Database.init()` | Alias para `getDb()`. Llamado al arrancar el servidor. |

**Comportamiento:**
- La ruta de la BD es `config/history.db` (relativa al CWD) o `$CONFIG_PATH/history.db`.
- Crea el directorio si no existe.
- Llama a `initializeSchema()` al crear la conexión.
- `PRAGMA foreign_keys = ON` — Las foreign keys están activas.
- `ensureColumn()` — Migraciones básicas: añade columnas si faltan (_ej.: `manager_id` en `quiz_runs`_).

---

### 4.3 Servicio `AccountStore`

**Archivo:** `packages/socket/src/services/accountStore.ts` (595 líneas)

Gestiona cuentas de managers y sus quizzes en SQLite.

**Funciones privadas internas:**

| Función | Descripción |
|---------|-------------|
| `hashPassword(password)` | `scrypt` con salt de 16 bytes aleatorios. Formato: `salt:hash` |
| `verifyPassword(password, hash)` | Comparación en tiempo constante con `timingSafeEqual` |
| `normalizePassword(password)` | Trim + validación no vacío |
| `formatManager(row)` | Convierte fila DB a `ManagerAccount` |
| `toSession(row)` | Convierte fila DB a `ManagerSession` (solo id/username/role) |

**Métodos públicos de `AccountStore`:**

| Método | Descripción |
|--------|-------------|
| `init()` | Inicializa BD + migra admin legacy |
| `isBootstrapRequired()` | `true` si no hay managers en la BD |
| `autoMigrateLegacyAdmin()` | Si no hay managers y `game.json` tiene contraseña válida, crea admin automáticamente |
| `createInitialAdmin(username, password)` | Solo cuando `isBootstrapRequired()`. Crea admin y migra quizzes legacy. |
| `authenticateManager(username, password)` | Returns `LoginResult`. Comprueba existe, no deshabilitado, contraseña correcta. |
| `getManagerById(managerId)` | Busca por UUID |
| `listManagers()` | Ordenados: admins primero, luego por username |
| `createManager(username, password)` | Crea manager con role `"manager"` |
| `createOidcManager(username, role)` | Crea manager auto-provisionado por SSO (contraseña aleatoria) |
| `resetManagerPassword(managerId, password)` | Actualiza hash |
| `setManagerDisabled(managerId, disabled)` | Pone/quita `disabled_at` timestamp |
| `updateManagerRole(managerId, role)` | Cambia rol |
| `getManagerSettings(managerId)` | Lee `manager_settings`: `{ defaultAudio }` |
| `updateManagerSettings(managerId, settings)` | Puede cambiar contraseña y/o audio por defecto |
| `listQuizzes(managerId)` | Lista quizzes del manager, ordenados por subject |
| `getQuizz(managerId, quizzId)` | Busca quiz por id y managerId |
| `createQuizz(managerId, subject)` | Crea quiz con pregunta de ejemplo |
| `updateQuizz(managerId, quizzId, quizz)` | Actualiza y normaliza |
| `deleteQuizz(managerId, quizzId)` | Elimina de la BD |

**`migrateLegacyResources(managerId)`** — Importa quizzes del filesystem JSON y configuración de audio a la BD SQLite. Solo se ejecuta si no hay quizzes existentes.

---

### 4.4 Servicio `Game`

**Archivo:** `packages/socket/src/services/game.ts` (819 líneas)

Clase `Game` que encapsula toda la lógica de una partida en curso. Vive **en memoria** (Register).

#### Propiedades de instancia

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `gameId` | `string` | UUID de la partida |
| `inviteCode` | `string` | Código de 6 dígitos para unirse |
| `started` | `boolean` | Si la partida ha comenzado |
| `manager` | `object` | Datos del manager (socketId, clientId, accountId, username, connected) |
| `quizz` | `QuizzWithId` | Quiz con preguntas en uso |
| `players` | `Player[]` | Lista de jugadores conectados |
| `leaderboard` | `Player[]` | Ordenado por puntos |
| `round` | `object` | Estado de ronda actual (currentQuestion, playersAnswers, startTime) |
| `cooldown` | `object` | Estado del temporizador (active, ms) |
| `historyQuestions` | `QuizRunHistoryDetail["questions"]` | Historial acumulado para guardar al final |
| `pendingPlayerRemovals` | `Map<string, Timeout>` | Timeouts de limpieza de jugadores desconectados |
| `defaultAudio` | `string?` | Audio por defecto del manager |
| `lastBroadcastStatus` | `{name, data}` | Último estado emitido a todos |
| `managerStatus` | `{name, data}` | Estado específico del manager |
| `playerStatus` | `Map<string, {name, data}>` | Estado por socket id de jugador |

#### Métodos públicos de `Game`

| Método | Descripción |
|--------|-------------|
| `constructor(io, socket, manager, quizz, settings)` | Genera gameId, inviteCode; une al manager al room; emite `manager:gameCreated` |
| `broadcastStatus(status, data)` | Emite `game:status` a **todos** en la room |
| `sendStatus(target, status, data)` | Emite `game:status` a **un** socket específico |
| `join(socket, username)` | Une jugador, valida username, emite `manager:newPlayer` y `game:successJoin` |
| `kickPlayer(socket, playerId)` | Solo manager puede expulsar; emite `game:reset` al jugador |
| `getActiveManagerGame(currentClientId)` | Devuelve resumen para la UI del manager |
| `isOwnedByManager(managerId)` | Compara `manager.accountId` |
| `reconnect(socket)` | Detecta si es manager o jugador y delega |
| `takeOverManager(socket)` | Desconecta manager anterior y conecta el nuevo |
| `startCooldown(seconds)` | Temporizador con broadcast cada segundo de `game:cooldown` |
| `abortCooldown()` | Para el temporizador en curso |
| `start(socket)` | Inicia partida: limpia desconectados, emite SHOW_START, cuenta 3s, llama `newRound()` |
| `newRound()` | Lanza SHOW_PREPARED → (2s) → SHOW_QUESTION → (cooldown) → SELECT_ANSWER → (time) → showResults |
| `showResults(question)` | Calcula puntos, ordena jugadores, emite SHOW_RESULT a cada uno y SHOW_RESPONSES al manager |
| `selectAnswer(socket, answerId)` | Registra respuesta con puntaje basado en tiempo; si todos respondieron, aborta cooldown |
| `nextRound(socket)` | Avanza `currentQuestion++` y llama `newRound()` |
| `abortRound(socket)` | Solo manager; llama `abortCooldown()` |
| `showLeaderboard()` | Si es última ronda: emite FINISHED y guarda historial. Si no: emite SHOW_LEADERBOARD |
| `endGame(socket)` | Solo manager; llama `terminate()` |
| `terminate(reason)` | Aborta cooldown, emite `game:reset` a todos, elimina del registry |
| `revokeManagerControl(reason)` | Emite `game:reset` solo al manager y lo saca del room |
| `schedulePlayerRemoval(playerId)` | Programa eliminar jugador desconectado tras `PLAYER_RECONNECT_GRACE_MS` (60s) |
| `cancelPendingPlayerRemoval(clientId)` | Cancela el timeout si el jugador reconectó |
| `clearPendingPlayerRemovals()` | Limpia todos los timeouts (al terminar partida) |
| `persistHistory()` | Guarda la partida en `quiz_runs` via `History.addRun()` |

---

### 4.5 Servicio `Registry`

**Archivo:** `packages/socket/src/services/registry.ts`

Singleton que mantiene la lista de partidas activas **en memoria**. Se reinicia con el proceso.

#### Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `EMPTY_GAME_TIMEOUT_MINUTES` | `5` minutos | Tiempo antes de limpiar partida sin manager |
| `CLEANUP_INTERVAL_MS` | `60.000` ms (1 min) | Intervalo del cleanup automático |

#### Métodos

| Método | Descripción |
|--------|-------------|
| `getInstance()` | Singleton |
| `addGame(game)` | Agrega partida al array |
| `getGameById(gameId)` | Busca por UUID |
| `getGameByInviteCode(inviteCode)` | Busca por código de 6 dígitos |
| `getPlayerGame(gameId, clientId)` | Busca partida que contenga al jugador |
| `getManagerGame(gameId, clientId)` | Busca partida del manager por clientId |
| `getGameByManagerAccountId(managerId)` | Busca por UUID de cuenta del manager |
| `getGameByManagerSocketId(socketId)` | Busca por socket.id del manager |
| `getGameByPlayerSocketId(socketId)` | Busca por socket.id de cualquier jugador |
| `markGameAsEmpty(game)` | Marca partida como vacía (manager desconectado) |
| `reactivateGame(gameId)` | Quita partida de la lista de vacías |
| `removeGame(gameId)` | Elimina partida de ambas listas |
| `getAllGames()` | Copia del array de partidas |
| `getGameCount()` | Número de partidas activas |
| `getEmptyGameCount()` | Número de partidas sin manager |
| `cleanup()` | Limpia todo (usado en SIGINT/SIGTERM) |

**Cleanup automático:** Cada 60 segundos, examina las partidas "vacías". Si llevan más de 5 minutos vacías (sin manager conectado), las elimina del registry.

---

### 4.6 Servicio `History`

**Archivo:** `packages/socket/src/services/history.ts`

Persiste y consulta las partidas terminadas en SQLite.

| Método | Descripción |
|--------|-------------|
| `init()` | Alias para `Database.init()` |
| `addRun(managerId, run)` | Inserta o reemplaza (`INSERT OR REPLACE`) una partida en `quiz_runs` |
| `listRuns(managerId)` | Lista partidas del manager, ordenadas por `ended_at DESC` |
| `getRun(managerId, runId)` | Obtiene detalle completo de una partida (desde `payload_json`) |
| `claimLegacyRuns(managerId)` | Asigna runs sin `manager_id` al manager dado (migración) |
| `exportCsv(managerId, runId)` | Genera string CSV con todas las respuestas de todos los jugadores |

**Formato CSV exportado:** Columnas: Quiz, Started At, Ended At, Question Number, Question, Player, Answer Id, Answer Text, Correct Answer Ids, Correct Answer Texts, Is Correct, Points Earned, Total Points, Final Rank.

`normalizeRun()` — Migración de formato legacy: convierte `correctAnswer` (número singular) a `correctAnswers` (array).

---

### 4.7 Servicio `Config`

**Archivo:** `packages/socket/src/services/config.ts` (545 líneas)

Lee y escribe archivos de configuración del filesystem. **No usa la BD.** Funciona con rutas relativas al CWD o `$CONFIG_PATH`.

| Método | Descripción |
|--------|-------------|
| `init()` | Crea directorios `config/`, `config/quizz/`, `media/`; crea archivos iniciales si no existen |
| `game()` | Lee y parsea `config/game.json` |
| `managerSettings()` | Lee `defaultAudio` de `game.json` |
| `quizz()` | Lista y parsea todos los `.json` de `config/quizz/` (lectura legacy) |
| `createQuizz(subject)` | Crea archivo JSON en `config/quizz/` (legacy) |
| `updateQuizz(quizzId, quizz)` | Actualiza archivo JSON en `config/quizz/` (legacy) |
| `deleteQuizz(quizzId)` | Elimina archivo JSON de `config/quizz/` (legacy) |
| `updateManagerSettings(settings)` | Escribe en `game.json` |
| `oidc()` | Lee `auth.json` y devuelve `OidcConfig` (sin `clientSecret`) |
| `oidcSecret()` | Lee `clientSecret` de `auth.json` |
| `oidcStatus()` | Calcula si OIDC está `enabled` y `configured` |
| `updateOidc(settings)` | Valida y escribe `auth.json` |
| `validateTestableOidcConfig(settings)` | Valida sin requerir clientSecret |
| `uploadMedia(filename, content)` | Escribe buffer base64 en `media/`; retorna URL `/media/filename` |
| `mediaDirectory()` | Ruta al directorio `media/` |
| `authConfigPath()` | Ruta a `config/auth.json` |
| `quizzDirectory()` | Ruta a `config/quizz/` |

**Config OIDC por defecto:**
```json
{
  "enabled": false,
  "autoProvisionEnabled": false,
  "discoveryUrl": "",
  "clientId": "",
  "clientSecret": "",
  "scopes": ["openid", "profile", "email"],
  "roleClaimPath": "groups",
  "adminRoleValues": ["edullm-admin"],
  "managerRoleValues": ["edullm-manager"]
}
```

---

### 4.8 Servicio `OidcAuth`

**Archivo:** `packages/socket/src/services/oidcAuth.ts` (449 líneas)

Implementa el flujo OIDC con PKCE (Authorization Code + code_verifier/challenge SHA-256).

#### Constantes de tiempo

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `AUTH_STATE_TTL_MS` | `10 * 60 * 1000` (10 min) | Tiempo máximo para completar el login OIDC |
| `LOGIN_HANDOFF_TTL_MS` | `2 * 60 * 1000` (2 min) | Tiempo para que el frontend reclame el login tras callback |

#### Estructuras en memoria

```typescript
// Estado de autorización pendiente: state_token → AuthorizationState
const authorizationStates = new Map<string, AuthorizationState>()

// Handoff post-callback: clientId → LoginHandoff
const loginHandoffs = new Map<string, LoginHandoff>()
```

**Ninguna de estas estructuras persiste** — se perderán si el servidor se reinicia durante un login SSO en curso.

#### Métodos

| Método | Descripción |
|--------|-------------|
| `status()` | Devuelve `Config.oidcStatus()` |
| `getDiscoveryDocument()` | Fetch a `discoveryUrl` del OIDC provider; valida campos requeridos |
| `testConfiguration(settings)` | Prueba discovery URL con config provisional |
| `buildAuthorizationUrl(input)` | Genera URL de autorización con PKCE; guarda estado en `authorizationStates` |
| `handleCallback(input)` | Intercambia `code` por tokens, valida ID token, obtiene userinfo, crea/actualiza manager |
| `consumeLoginHandoff(clientId)` | Recupera y borra el handoff para completar el login en el socket |

**Flujo completo de SSO:**
1. Manager hace click en "Login SSO" → frontend navega a `/auth/oidc/login?clientId=&returnTo=`
2. El servidor construye authorization URL con PKCE y redirige al proveedor
3. Usuario se autentica en proveedor → callback a `/auth/oidc/callback?code=&state=`
4. Servidor valida state, intercambia code por tokens, valida ID token
5. Mapea rol desde claims JWT
6. Crea o actualiza manager en BD; guarda identidad OIDC
7. Guarda `LoginHandoff` en memoria con el `clientId` del manager
8. Redirige a `/manager?oidc=success`
9. Frontend detecta `?oidc=success`, emite `manager:completeOidcLogin`
10. Servidor consume el handoff y autentica al manager en la sesión socket

**Funciones privadas:**

| Función | Descripción |
|---------|-------------|
| `toBase64Url(input)` | Base64URL encoding |
| `createCodeVerifier()` | 48 bytes aleatorios en base64url |
| `createCodeChallenge(verifier)` | SHA-256 del verifier en base64url |
| `createStateToken()` | 24 bytes aleatorios en base64url |
| `parseJwtClaims(token)` | Decodifica payload JWT (sin verificar firma) |
| `getNestedClaim(source, path)` | Accede a claims por path punteado ej: `"groups.admin"` |
| `normalizeRoleValues(value)` | Acepta string (CSV) o array |
| `mapRoleFromClaims(claims)` | Mapea valores de claim a `"admin"` o `"manager"` |
| `deriveUsername(claims)` | Usa `preferred_username` → email username → random |
| `cleanupExpiredEntries()` | Limpia entradas TTL expiradas de ambos Maps |

---

### 4.9 Servicio `OidcStore`

**Archivo:** `packages/socket/src/services/oidcStore.ts`

CRUD de identidades OIDC en la tabla `manager_oidc_identities`.

| Método | Descripción |
|--------|-------------|
| `getIdentityByIssuerSubject(issuer, subject)` | Busca por `(issuer, subject)` unique |
| `listIdentitiesForManager(managerId)` | Lista identidades de un manager |
| `upsertIdentity(input)` | Insert o Update de identidad OIDC |

---

### 4.10 Servicio `Quizz` (helpers)

**Archivo:** `packages/socket/src/services/quizz.ts`

Utilidades de normalización y validación de quizzes.

| Exportación | Descripción |
|------------|-------------|
| `type RawQuizz` | Input antes de normalizar (compatible con formato legacy) |
| `type RawQuizzQuestion` | Pregunta con `solution` (singular) o `solutions` (array) |
| `normalizeOptionalAsset(value)` | Trim; retorna undefined si vacío |
| `normalizeSolutions(question, answers, index)` | Normaliza array de soluciones; valida índices |
| `normalizeQuizz(quizz)` | Valida y normaliza quiz completo; lanza Error con mensaje descriptivo |

**Reglas de validación:**
- Subject no puede estar vacío
- Mínimo 1 pregunta
- Cada pregunta: texto no vacío; entre 2 y 4 respuestas; mínimo 1 solución válida; cooldown ≥ 0; time > 0
- Todos los índices de soluciones deben ser válidos (dentro del rango de answers)

---

### 4.11 Utils del socket

**`packages/socket/src/utils/game.ts`:**

| Función | Descripción |
|---------|-------------|
| `withGame(gameId, socket, callback)` | Helper: busca partida en registry; emite error si no existe; ejecuta callback |
| `createInviteCode(length = 6)` | Genera código numérico aleatorio de 6 dígitos |
| `timeToPoint(startTime, seconds)` | Calcula puntos basados en tiempo: `1000 - (1000/tiempo_total) * tiempo_transcurrido`, mínimo 0 |

**`packages/socket/src/utils/sleep.ts`:**

| Función | Descripción |
|---------|-------------|
| `sleep(sec)` | `Promise` que resuelve después de `sec` segundos |

---

## 5. Paquete `@edullm/common` — Tipos Compartidos

### 5.1 Tipos del juego

**Archivo:** `packages/common/src/types/game/index.ts`

```typescript
// Jugador en memoria durante la partida
type Player = {
  id: string        // socket.id (cambia en reconexión)
  clientId: string  // UUID persistente del navegador
  connected: boolean
  username: string
  points: number
}

// Respuesta registrada durante una ronda
type Answer = {
  playerId: string  // socket.id
  answerId: number  // índice 0-based de la respuesta
  points: number    // puntos calculados en el momento de respuesta
}

// Pregunta de quiz
type QuizzQuestion = {
  question: string
  image?: string
  video?: string
  audio?: string
  answers: string[]   // array de 2-4 opciones
  solutions: number[] // índices de respuestas correctas
  cooldown: number    // segundos de preview antes de mostrar opciones
  time: number        // segundos disponibles para responder
}

type Quizz = { subject: string; questions: QuizzQuestion[] }
type QuizzWithId = Quizz & { id: string }

// Roles de manager
type ManagerRole = "admin" | "manager"

// Cuenta completa (BD)
type ManagerAccount = {
  id: string; username: string; role: ManagerRole
  disabledAt: string | null; createdAt: string; updatedAt: string
}

// Sesión en memoria (solo campos esenciales)
type ManagerSession = Pick<ManagerAccount, "id" | "username" | "role">

// Estado de partida activa para la UI del manager
type ActiveManagerGame = {
  gameId: string; inviteCode: string; subject: string
  started: boolean; controlledByCurrentSession: boolean
}

// Configuración OIDC (expuesta, sin clientSecret)
type OidcConfig = { enabled, autoProvisionEnabled, discoveryUrl,
  clientId, hasClientSecret, scopes, roleClaimPath,
  adminRoleValues, managerRoleValues }

// Tipos de historial...
type QuizRunHistorySummary = { id, gameId, quizzId, subject,
  startedAt, endedAt, totalPlayers, questionCount, winner }
type QuizRunHistoryDetail = QuizRunHistorySummary & { leaderboard, questions }
```

### 5.2 Tipos de socket (eventos)

**Archivo:** `packages/common/src/types/game/socket.ts`

Define los tipos de todos los eventos WebSocket de forma bidireccional.

```typescript
export type Server = ServerIO<ClientToServerEvents, ServerToClientEvents>
export type Socket = SocketIO<ClientToServerEvents, ServerToClientEvents>
```

**`ServerToClientEvents`** — Eventos que el servidor emite al cliente (completos en sección 7).

**`ClientToServerEvents`** — Eventos que el cliente emite al servidor (completos en sección 7).

### 5.3 Tipos de estado (`STATUS`)

**Archivo:** `packages/common/src/types/game/status.ts`

```typescript
export const STATUS = {
  SHOW_ROOM:       "SHOW_ROOM",       // Manager: sala de espera inicial
  SHOW_START:      "SHOW_START",      // Todos: cuenta regresiva de inicio
  SHOW_PREPARED:   "SHOW_PREPARED",   // Todos: "se viene pregunta X"
  SHOW_QUESTION:   "SHOW_QUESTION",   // Todos: muestra texto/imagen de pregunta
  SELECT_ANSWER:   "SELECT_ANSWER",   // Todos: muestra opciones para responder
  SHOW_RESULT:     "SHOW_RESULT",     // Jugadores: resultado individual
  SHOW_RESPONSES:  "SHOW_RESPONSES",  // Manager: distribución de respuestas
  SHOW_LEADERBOARD:"SHOW_LEADERBOARD",// Manager: tabla de líderes
  FINISHED:        "FINISHED",        // Todos: podio final
  WAIT:            "WAIT",            // Quien ya respondió: espera
}
```

### 5.4 Validadores

**Archivo:** `packages/common/src/validators/auth.ts`

```typescript
// Zod validators compartidos entre servidor y cliente
export const usernameValidator = z.string().min(4).max(20)
export const inviteCodeValidator = z.string().length(6)
```

### 5.5 Utils comunes

**Archivo:** `packages/common/src/utils/audio.ts`

```typescript
export const LOCAL_MEDIA_PREFIX = "/media/"

// Acepta URLs http/https o rutas /media/*; rechaza lo demás
export const normalizeAudioUrl = (value?: string | null) => ...
export const isAudioUrlAllowed = (value?: string | null) => ...
```

---

## 6. Paquete `@edullm/web` — Frontend React

### 6.1 Punto de entrada y router

**`packages/web/src/main.tsx`:**
```tsx
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Router />     {/* Provee todas las rutas */}
    <Toaster />    {/* Notificaciones toast globales */}
  </StrictMode>
)
```

**`packages/web/src/router.tsx`:** Define las rutas con React Router v7.

### 6.2 Rutas y páginas

| Ruta | Componente | Descripción |
|------|-----------|-------------|
| `/` | `PlayerAuthPage` | Página de entrada del jugador: ingresa código de sala y username |
| `/login` | `StudentLoginPage` | Autenticación exclusiva para estudiantes que guarda sesión |
| `/manager` | `AuthManagerPage` | Dashboard completo del manager (login + gestión) |
| `/party/:gameId` | `PlayerGamePage` | Partida como jugador |
| `/party/manager/:gameId` | `ManagerGamePage` | Partida como manager |

**Jerarquía de layouts:**
```
GameLayout (SocketProvider)
  └── AuthLayout
      ├── "/" → PlayerAuthPage
      ├── "/login" → StudentLoginPage
      └── "/manager" → AuthManagerPage
  └── "/party/:gameId" → PlayerGamePage
  └── "/party/manager/:gameId" → ManagerGamePage
```

**`GameLayout`** (`packages/web/src/pages/game/layout.tsx`):
- Envuelve toda la app con `SocketProvider`
- Conecta el socket automáticamente si no está conectado
- Aplica clase CSS `bg-secondary` al body

### 6.3 Context: `SocketProvider`

**Archivo:** `packages/web/src/features/game/contexts/socketProvider.tsx`

El cerebro de la comunicación WebSocket en el frontend.

#### `getClientId()`

Genera o recupera un **UUID v7** persistente en `localStorage` con clave `"client_id"`. Este ID es el identificador permanente del navegador/dispositivo y se envía como `auth.clientId` en el handshake del socket.

```typescript
// El socket se inicializa con:
io("/", {
  path: "/ws",
  autoConnect: false,         // No conecta automáticamente
  reconnection: true,          // Reconexión automática habilitada
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,    // 1 segundo entre intentos
  auth: { clientId }           // El UUID del localStorage
})
```

#### Exports del context

| Export | Descripción |
|--------|-------------|
| `SocketProvider` | Componente proveedor |
| `useSocket()` | Hook: `{ socket, isConnected, clientId, connect, disconnect, reconnect }` |
| `useEvent(event, callback)` | Hook para suscribirse a un evento del servidor; se limpia automáticamente |

**`useEvent`** registra/desregistra el listener cuando cambia el socket o el callback. Los componentes usan este hook en lugar de `socket.on()` directamente.

### 6.4 Stores (Zustand)

#### `useManagerStore` — `packages/web/src/features/game/stores/manager.tsx`

Estado del manager durante la partida. **No persiste** (en memoria).

```typescript
{
  gameId: string | null
  status: Status | null
  players: Player[]
  
  setGameId(gameId)
  setStatus(name, data)    // Actualiza el status actual
  resetStatus()
  setPlayers(players)
  reset()                  // Vuelve a initialState
}
```

#### `usePlayerStore` — `packages/web/src/features/game/stores/player.tsx`

Estado del jugador. **Persiste en `localStorage`** con clave `"player-session"` (via `zustand/middleware/persist`).

```typescript
{
  gameId: string | null
  player: { username?, points? } | null
  status: Status | null
  
  setGameId(gameId)
  setPlayer(state)
  login(username)         // Guarda username
  join(gameId)            // Setea gameId + puntos en 0
  updatePoints(points)
  setStatus(name, data)
  reset()
}
```

**Campos persistidos:** `gameId`, `player`, `status`. Esto permite que el jugador se reconecte si recarga la página.

#### `useQuestionStore` — `packages/web/src/features/game/stores/question.tsx`

Estado simple del número de pregunta actual. No persiste.

```typescript
{
  questionStates: { current: number; total: number } | null
  setQuestionStates(state)
}
```

### 6.5 Componentes de estado del juego

Ubicados en `packages/web/src/features/game/components/states/`.

Cada componente recibe `data` tipado según el estado correspondiente.

| Componente | `STATUS` | Visible por | Data que recibe |
|-----------|---------|-------------|----------------|
| `Room.tsx` | `SHOW_ROOM` | Manager | `{ text, inviteCode? }` — muestra código QR y lista de jugadores |
| `Start.tsx` | `SHOW_START` | Todos | `{ time, subject }` — cuenta regresiva animada |
| `Prepared.tsx` | `SHOW_PREPARED` | Todos | `{ totalAnswers, questionNumber }` — "Pregunta X está por llegar" |
| `Question.tsx` | `SHOW_QUESTION` | Todos | `{ question, image?, cooldown }` — muestra pregunta + temporizador |
| `Answers.tsx` | `SELECT_ANSWER` | Todos | `{ question, answers[], multipleCorrect, image?, video?, audio?, time, totalPlayer }` — opciones de respuesta con colores/íconos |
| `Wait.tsx` | `WAIT` | Jugadores | `{ text }` — "Esperando..." |
| `Result.tsx` | `SHOW_RESULT` | Jugadores | `{ correct, message, points, myPoints, rank, aheadOfMe }` — resultado individual |
| `Responses.tsx` | `SHOW_RESPONSES` | Manager | `{ question, responses, correct, answers, image? }` — distribución de respuestas |
| `Leaderboard.tsx` | `SHOW_LEADERBOARD` | Manager | `{ oldLeaderboard, leaderboard }` — animación de cambio de ranking |
| `Podium.tsx` | `FINISHED` | Todos | `{ subject, top[], runId }` — podio animado con confetti y sonidos |

**`GameWrapper.tsx`** — Layout compartido:
- Fondo fijo (`background.webp`)
- Indicador `X / N` de pregunta actual (si hay `questionStates`)
- Botón de acción para el manager (ej: "Start Game", "Skip", "Next")
- Barra inferior del jugador mostrando username y puntos
- Spinner "Connecting..." si no hay conexión y no hay status

### 6.6 Componentes del panel Manager

Ubicados en `packages/web/src/features/game/components/create/`.

| Componente | Descripción |
|-----------|-------------|
| `InitialAdminSetup.tsx` | Formulario de creación del primer admin |
| `ManagerPassword.tsx` | Login usuario/contraseña + botón SSO opcional |
| `SelectQuizz.tsx` | Lista de quizzes con crear, editar, borrar, iniciar partida |
| `QuizzEditor.tsx` | Editor completo de quiz: preguntas, respuestas, tiempos, media |
| `HistoryPanel.tsx` | Lista de partidas pasadas con descarga CSV |
| `SettingsPanel.tsx` | Audio por defecto, subir audio local, cambiar contraseña |
| `ManagersPanel.tsx` | Lista de managers (admin): crear, resetear contraseña, deshabilitar |
| `SsoSettingsPanel.tsx` | Configuración OIDC completa con test de discovery |

### 6.7 Componentes de join/lobby

Ubicados en `packages/web/src/features/game/components/join/`.

| Componente | Descripción |
|-----------|-------------|
| `Room.tsx` | Formulario para ingresar código de sala de 6 dígitos |
| `Username.tsx` | Formulario para ingresar username (4-20 chars) |

### 6.8 Componentes generales

| Componente | Descripción |
|-----------|-------------|
| `Button.tsx` | Botón estilizado |
| `Input.tsx` | Input estilizado |
| `Form.tsx` | Wrapper de formulario |
| `AnswerButton.tsx` | Botón de respuesta del jugador |
| `Loader.tsx` | Spinner SVG animado |
| `Toaster.tsx` | Configuración global de react-hot-toast |

### 6.9 Íconos SVG

En `packages/web/src/features/game/components/icons/`.

| Ícono | Color asignado | Índice de respuesta |
|-------|---------------|---------------------|
| Triangle | Rojo | 0 |
| Rhombus | Azul | 1 |
| Circle | Amarillo | 2 |
| Square | Verde | 3 |

### 6.10 Utils del frontend

**`packages/web/src/features/game/utils/constants.ts`:**

| Constante | Descripción |
|-----------|-------------|
| `ANSWERS_COLORS` | `["bg-red-500", "bg-blue-500", "bg-yellow-500", "bg-green-500"]` |
| `ANSWERS_ICONS` | `[Triangle, Rhombus, Circle, Square]` |
| `GAME_STATE_COMPONENTS` | Mapa `STATUS` → componente React (para jugadores) |
| `GAME_STATE_COMPONENTS_MANAGER` | Igual + SHOW_ROOM, SHOW_RESPONSES, SHOW_LEADERBOARD, FINISHED |
| `MANAGER_SKIP_EVENTS` | Mapa `STATUS` → evento socket que emite el botón de acción |
| `MANAGER_SKIP_BTN` | Mapa `STATUS` → texto del botón de acción |
| `SFX_*` | Rutas a efectos de sonido en `/public/sounds/` |

**Archivos de sonido (en `public/sounds/`):**

| Constante | Archivo | Momento |
|-----------|---------|---------|
| `SFX_ANSWERS_MUSIC` | `answersMusic.mp3` | Música durante respuestas |
| `SFX_ANSWERS_SOUND` | `answersSound.mp3` | Sonido al abrir respuestas |
| `SFX_RESULTS_SOUND` | `results.mp3` | Al mostrar resultados |
| `SFX_SHOW_SOUND` | `show.mp3` | Al mostrar pregunta |
| `SFX_BOUMP_SOUND` | `boump.mp3` | Efecto de impacto |
| `SFX_PODIUM_THREE` | `three.mp3` | Podio 3er lugar |
| `SFX_PODIUM_SECOND` | `second.mp3` | Podio 2do lugar |
| `SFX_PODIUM_FIRST` | `first.mp3` | Podio 1er lugar |
| `SFX_SNEAR_ROOL` | `snearRoll.mp3` | Redoble de tambor |

---

## 7. Flujo Completo de Eventos WebSocket

### 7.1 Eventos Cliente → Servidor

#### Manager — Setup y autenticación

| Evento | Payload | Descripción |
|--------|---------|-------------|
| `manager:getBootstrapState` | — | Consulta si se necesita setup inicial |
| `manager:createInitialAdmin` | `{username, password}` | Crea el primer admin |
| `manager:auth` | `{username, password}` | Login estándar |
| `manager:completeOidcLogin` | — | Completa login SSO (post-callback) |
| `manager:getDashboard` | — | Solicita todos los datos del dashboard |
| `manager:logout` | — | Cierra sesión |

#### Manager — Administración

| Evento | Payload | Requiere |
|--------|---------|---------|
| `manager:listManagers` | — | admin |
| `manager:createManager` | `{username, password}` | admin |
| `manager:resetManagerPassword` | `{managerId, password}` | admin |
| `manager:setManagerDisabled` | `{managerId, disabled}` | admin |
| `manager:getOidcConfig` | — | admin |
| `manager:updateOidcConfig` | `OidcConfigInput` | admin |
| `manager:testOidcConfig` | `OidcConfigInput` | admin |

#### Manager — Quizzes y configuración

| Evento | Payload |
|--------|---------|
| `manager:createQuizz` | `{subject}` |
| `manager:updateQuizz` | `{quizzId, quizz: Quizz}` |
| `manager:deleteQuizz` | `{quizzId}` |
| `manager:updateSettings` | `ManagerSettingsUpdate` |
| `manager:uploadMedia` | `{filename, content: base64}` |
| `manager:downloadHistory` | `{runId}` |

#### Manager — Control de partida

| Evento | Payload |
|--------|---------|
| `game:create` | `quizzId: string` |
| `manager:reconnect` | `{gameId}` |
| `manager:takeOverGame` | `{gameId}` |
| `manager:kickPlayer` | `{gameId, playerId}` |
| `manager:startGame` | `{gameId}` |
| `manager:abortQuiz` | `{gameId}` |
| `manager:nextQuestion` | `{gameId}` |
| `manager:showLeaderboard` | `{gameId}` |
| `manager:endGame` | `{gameId}` |

#### Jugador

| Evento | Payload |
|--------|---------|
| `player:join` | `inviteCode: string` |
| `player:login` | `{gameId, data: {username}}` |
| `player:reconnect` | `{gameId}` |
| `player:selectedAnswer` | `{gameId, data: {answerKey: number}}` |

### 7.2 Eventos Servidor → Cliente

#### Eventos generales de juego

| Evento | Payload | Destinatario |
|--------|---------|-------------|
| `game:status` | `{name: Status, data: StatusDataMap[Status]}` | Según estado |
| `game:successRoom` | `gameId: string` | Jugador que se unió a sala |
| `game:successJoin` | `gameId: string` | Jugador que hizo login |
| `game:totalPlayers` | `count: number` | Toda la room |
| `game:errorMessage` | `message: string` | Socket individual |
| `game:startCooldown` | — | Toda la room |
| `game:cooldown` | `count: number` | Toda la room |
| `game:reset` | `message: string` | Toda la room o individual |
| `game:updateQuestion` | `{current, total}` | Toda la room |
| `game:playerAnswer` | `count: number` | Toda la room |

#### Eventos de jugador

| Evento | Payload |
|--------|---------|
| `player:successReconnect` | `{gameId, status, player, currentQuestion}` |

#### Eventos de manager

| Evento | Payload |
|--------|---------|
| `manager:bootstrapState` | `{requiresSetup: boolean}` |
| `manager:authSuccess` | `{manager: ManagerSession}` |
| `manager:activeGame` | `ActiveManagerGame \| null` |
| `manager:quizzList` | `QuizzWithId[]` |
| `manager:quizzCreated` | `QuizzWithId` |
| `manager:quizzUpdated` | `QuizzWithId` |
| `manager:quizzDeleted` | `quizzId: string` |
| `manager:historyList` | `QuizRunHistorySummary[]` |
| `manager:historyExportReady` | `{filename, content: string}` |
| `manager:settings` | `ManagerSettings` |
| `manager:managersList` | `ManagerAccount[]` |
| `manager:managerCreated` | `ManagerAccount` |
| `manager:managerUpdated` | `ManagerAccount` |
| `manager:oidcConfig` | `OidcConfig` |
| `manager:oidcConfigSaved` | `OidcConfig` |
| `manager:oidcConfigTested` | `OidcConfigTestResult` |
| `manager:oidcStatus` | `OidcStatus` |
| `manager:mediaUploaded` | `{url: string}` |
| `manager:errorMessage` | `message: string` |
| `manager:playerKicked` | `playerId: string` |
| `manager:newPlayer` | `Player` |
| `manager:removePlayer` | `playerId: string` |
| `manager:gameCreated` | `{gameId, inviteCode}` |
| `manager:successReconnect` | `{gameId, status, players, currentQuestion}` |

---

## 8. Estados del Juego (`STATUS`)

Secuencia temporal de estados durante una partida:

```
[Manager dashboard]
      │ game:create
      ▼
SHOW_ROOM          ← Manager ve sala de espera + código QR
      │ manager:startGame
      ▼
SHOW_START         ← Cuenta regresiva 3 segundos con nombre del quiz
      │ (auto: 3s delay)
      ▼
game:startCooldown → SHOW_PREPARED  ← "Pregunta X se aproxima"
      │ (auto: 2s delay)
      ▼
SHOW_QUESTION      ← Muestra texto + imagen, temporizador de preview (cooldown s)
      │ (auto: cooldown delay)
      ▼
SELECT_ANSWER      ← Jugadores eligen respuesta (time segundos)
      │ (auto: time delay O todos respondieron)
      ▼
SHOW_RESULT        ← Cada jugador ve su resultado individual
SHOW_RESPONSES     ← Manager ve distribución de respuestas
      │ manager:showLeaderboard
      ▼
SHOW_LEADERBOARD   ← Manager ve top 5 con animación
      │ manager:nextQuestion (si no es la última)
      └── [vuelve a SHOW_PREPARED]
      │ (si es la última pregunta)
      ▼
FINISHED           ← Podio con top 3, confetti, sonidos
      │ manager:endGame
      ▼
[Manager dashboard]
```

| STATUS | Quién lo ve | Cuándo |
|--------|------------|--------|
| `SHOW_ROOM` | Solo Manager | Al crear partida |
| `SHOW_START` | Todos | Al iniciar |
| `SHOW_PREPARED` | Todos | Antes de cada pregunta |
| `SHOW_QUESTION` | Todos | Durante preview de pregunta |
| `SELECT_ANSWER` | Todos | Cuando abren las opciones |
| `WAIT` | Jugador que ya respondió | Al registrar respuesta |
| `SHOW_RESULT` | Jugadores (individual) | Al terminar tiempo |
| `SHOW_RESPONSES` | Solo Manager | Al terminar tiempo |
| `SHOW_LEADERBOARD` | Solo Manager | Al pedir leaderboard |
| `FINISHED` | Todos | Al terminar todas las preguntas |

---

## 9. Autenticación y Sesiones

### 9.1 Autenticación de Managers (usuario/contraseña)

**No usa cookies ni sesiones HTTP.** La autenticación vive en memoria del proceso del socket.

```
authenticatedManagers: Map<clientId, ManagerSession>
```

**Flujo:**
1. Manager envía `manager:auth` con `{username, password}`
2. Servidor verifica contra BD con `scrypt` + `timingSafeEqual`
3. Si OK: guarda `{ id, username, role }` en `authenticatedManagers[clientId]`
4. Emite 6 eventos de dashboard al manager

**Persistencia del lado cliente:**
```typescript
// En localStorage del manager:
localStorage.getItem("manager_auth") // "true" si autenticado
```
El frontend usa esto para intentar restaurar sesión al reconectar: si hay `"true"` en localStorage y el socket reconecta, emite `manager:getDashboard`.

**Expiración de sesión:**
- No hay JWT ni timeout automático
- La sesión expira si el servidor se reinicia (Map en memoria se pierde)
- El frontend detecta `manager:errorMessage` = "Manager authentication required" y limpia el estado local

### 9.2 Autenticación SSO/OIDC

Ver sección 4.8 para detalles. Resumen del flujo:

1. Manager navega (HTTP redirect) a `/auth/oidc/login?clientId=UUID&returnTo=/manager`
2. Servidor redirige al proveedor OIDC con PKCE
3. Proveedor redirige a `/auth/oidc/callback` con `code` y `state`
4. Servidor valida, obtiene tokens, crea/actualiza manager en BD
5. Almacena `LoginHandoff` en memoria (`loginHandoffs` Map, TTL 2 min)
6. Redirige a `/manager?oidc=success`
7. Frontend detecta query param, emite `manager:completeOidcLogin` por WebSocket
8. Servidor consume el handoff, guarda en `authenticatedManagers`, emite dashboard

### 9.3 Sesión de Jugadores

**Los jugadores pueden ser anónimos o estudiantes logueados:**

1. **`clientId`**: UUID v7 en `localStorage["client_id"]` — identifica el dispositivo
2. **`idEstudiante`** (opcional): ID del estudiante si inició sesión desde `/login` (contra PostgreSQL)
3. **Username**: elegido al unirse a la partida, o extraído automáticamente de la base de datos si es estudiante
4. **socket.id**: asignado por Socket.IO, cambia en cada reconexión

**Persistencia del jugador (Zustand persist):**
```typescript
// En localStorage["player-session"]:
{ gameId: string|null, player: {username, points, idEstudiante?}, status: Status|null }
```

Permite que el jugador recargue la página y reconecte automáticamente, o que un estudiante conserve su identidad a través de diferentes partidas.

### 9.4 Sin cookies — Todo en memoria + localStorage

| Dato | Dónde vive |
|------|-----------|
| Sesión de manager autenticado | `authenticatedManagers` Map en proceso Node.js |
| Estado de partida activa | `Registry` en memoria (clase Game) |
| Estados OIDC pendientes | Maps en memoria (`authorizationStates`, `loginHandoffs`) |
| clientId del navegador | `localStorage["client_id"]` |
| Flag de manager autenticado | `localStorage["manager_auth"]` |
| Estado del jugador | `localStorage["player-session"]` (Zustand persist) |
| Quizzes, historial, managers | SQLite `config/history.db` |
| Config OIDC | `config/auth.json` |
| Config de juego | `config/game.json` |

**No se usan cookies en ninguna parte del sistema.**

---

## 10. Base de Datos SQLite

### 10.1 Tablas

#### `managers`
```sql
CREATE TABLE managers (
  id           TEXT PRIMARY KEY,          -- UUID v4
  username     TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,            -- "salt:scrypthash"
  role         TEXT NOT NULL CHECK (role IN ('admin', 'manager')),
  disabled_at  TEXT,                      -- ISO timestamp o NULL
  created_at   TEXT NOT NULL,             -- ISO timestamp
  updated_at   TEXT NOT NULL
) STRICT
```

#### `manager_settings`
```sql
CREATE TABLE manager_settings (
  manager_id   TEXT PRIMARY KEY,
  default_audio TEXT,                    -- URL de audio o NULL
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE
) STRICT
```

#### `quizzes`
```sql
CREATE TABLE quizzes (
  id           TEXT PRIMARY KEY,           -- UUID v4
  manager_id   TEXT NOT NULL,
  subject      TEXT NOT NULL,
  payload_json TEXT NOT NULL,              -- JSON serializado del quiz completo
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE
) STRICT
```

#### `manager_oidc_identities`
```sql
CREATE TABLE manager_oidc_identities (
  id              TEXT PRIMARY KEY,        -- UUID v4
  manager_id      TEXT NOT NULL,
  issuer          TEXT NOT NULL,           -- URL del proveedor OIDC
  subject         TEXT NOT NULL,           -- "sub" claim del JWT
  email           TEXT,
  username_claim  TEXT,                    -- "preferred_username"
  last_login_at   TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES managers(id) ON DELETE CASCADE,
  UNIQUE (issuer, subject)
) STRICT
```

#### `quiz_runs`
```sql
CREATE TABLE quiz_runs (
  id             TEXT PRIMARY KEY,         -- UUID v4
  game_id        TEXT NOT NULL,            -- UUID de la partida
  quizz_id       TEXT NOT NULL,
  subject        TEXT NOT NULL,
  started_at     TEXT NOT NULL,
  ended_at       TEXT NOT NULL,
  total_players  INTEGER NOT NULL,
  question_count INTEGER NOT NULL,
  winner         TEXT,                     -- username del ganador o NULL
  payload_json   TEXT NOT NULL,            -- QuizRunHistoryDetail serializado
  manager_id     TEXT                      -- puede ser NULL (legacy)
) STRICT
```

**Índices:**
```sql
CREATE INDEX idx_quizzes_manager_id ON quizzes(manager_id)
CREATE INDEX idx_quiz_runs_manager_id ON quiz_runs(manager_id)
CREATE INDEX idx_manager_oidc_identities_manager_id ON manager_oidc_identities(manager_id)
```

### 10.2 Ubicación del archivo

| Entorno | Ruta |
|---------|------|
| Desarrollo (CWD = `packages/socket/`) | `../../config/history.db` → `config/history.db` |
| Producción Docker (`CONFIG_PATH=/app/config`) | `/app/config/history.db` |

---

## 11. Configuración del Sistema

### 11.1 `config/game.json`

```json
{
  "managerPassword": "PASSWORD",
  "defaultAudio": "/media/nombre.mp3"
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `managerPassword` | string | Contraseña legacy. Si existe y no es "PASSWORD", se crea admin automáticamente al arrancar. |
| `defaultAudio` | string? | URL de audio por defecto para las partidas. Opcional. |

### 11.2 `config/auth.json`

```json
{
  "oidc": {
    "enabled": false,
    "autoProvisionEnabled": false,
    "discoveryUrl": "https://accounts.google.com/.well-known/openid-configuration",
    "clientId": "tu-client-id",
    "clientSecret": "tu-client-secret",
    "scopes": ["openid", "profile", "email"],
    "roleClaimPath": "groups",
    "adminRoleValues": ["edullm-admin"],
    "managerRoleValues": ["edullm-manager"]
  }
}
```

| Campo | Descripción |
|-------|-------------|
| `enabled` | Activa el botón de SSO en la UI |
| `autoProvisionEnabled` | Si `true`, crea managers automáticamente al primer login SSO |
| `discoveryUrl` | URL del discovery document OIDC (`.well-known/openid-configuration`) |
| `clientId` | Client ID de la aplicación en el proveedor |
| `clientSecret` | Secret del cliente (almacenado en texto plano en JSON) |
| `scopes` | Scopes solicitados (default: `openid profile email`) |
| `roleClaimPath` | Path punteado al claim de roles en el JWT (ej: `"groups"`, `"realm_access.roles"`) |
| `adminRoleValues` | Valores del claim que mapean a rol `admin` |
| `managerRoleValues` | Valores del claim que mapean a rol `manager` |

### 11.3 `config/quizz/`

Directorio con archivos JSON de quizzes (formato legacy, aún usado para migración inicial).

```json
{
  "subject": "Nombre del Quiz",
  "questions": [
    {
      "question": "Texto de pregunta",
      "answers": ["Opción 1", "Opción 2", "Opción 3", "Opción 4"],
      "solutions": [1],
      "cooldown": 5,
      "time": 20,
      "image": "https://ejemplo.com/imagen.png",
      "video": "https://ejemplo.com/video.mp4",
      "audio": "/media/musica.mp3"
    }
  ]
}
```

### 11.4 Variables de entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `CONFIG_PATH` | Directorio raíz de configuración del servidor | `../../config` (relativo al CWD) |

El archivo `.env` en la raíz del proyecto es leído por `dotenv-cli` al correr `pnpm dev`.

---

## 12. Tiempos y Timeouts del Sistema

| Timeout | Valor | Dónde | Descripción |
|---------|-------|-------|-------------|
| `WS_PORT` | `3001` | `index.ts` | Puerto del servidor |
| `PLAYER_RECONNECT_GRACE_MS` | `60.000 ms` (1 min) | `game.ts` | Tiempo antes de eliminar jugador desconectado |
| `AUTH_STATE_TTL_MS` | `600.000 ms` (10 min) | `oidcAuth.ts` | Expiración de estado OIDC pendiente |
| `LOGIN_HANDOFF_TTL_MS` | `120.000 ms` (2 min) | `oidcAuth.ts` | Expiración de handoff post-callback |
| `EMPTY_GAME_TIMEOUT_MINUTES` | `5 min` | `registry.ts` | Limpieza de partidas sin manager |
| `CLEANUP_INTERVAL_MS` | `60.000 ms` (1 min) | `registry.ts` | Intervalo del cleanup de partidas vacías |
| `reconnectionDelay` | `1.000 ms` (1 s) | `socketProvider.tsx` | Delay entre intentos de reconexión socket |
| `Cache-Control media` | `max-age=3600` (1 h) | `index.ts` | Cache de archivos de audio |
| Inicio de partida | `3 s` | `game.ts` | Cuenta regresiva `SHOW_START` |
| Pausa pre-pregunta | `2 s` | `game.ts` | Duración de `SHOW_PREPARED` |
| Cooldown de pregunta | configurado en quiz | `game.ts` | Duración de `SHOW_QUESTION` (preview) |
| Tiempo de respuesta | configurado en quiz | `game.ts` | Duración de `SELECT_ANSWER` |

---

## 13. Archivos de Media

Los archivos de audio se almacenan en el directorio `media/` (en la raíz del proyecto o `/app/media` en Docker).

**Formatos soportados:**

| Extensión | MIME |
|-----------|------|
| `.aac` | `audio/aac` |
| `.mp3` | `audio/mpeg` |
| `.m4a` | `audio/mp4` |
| `.ogg` | `audio/ogg` |
| `.wav` | `audio/wav` |
| `.webm` | `audio/webm` |

**Cómo se sirven:** `GET /media/{filename}` → el servidor lee con `fs.createReadStream` y hace pipe a la response. Protegido contra path traversal (verifica `pathFromMediaRoot.startsWith("..")`).

**Cómo se suben:** Evento `manager:uploadMedia` con `{filename, content: base64}` → el servidor decodifica base64 y escribe en `media/`.

**URLs válidas de audio:**
- Local: `/media/archivo.mp3`
- Remote: `https://` o `http://` (cualquier URL válida)
- Cualquier otra URL es rechazada por `normalizeAudioUrl()`

---

## 14. Infraestructura y Despliegue

### 14.1 Desarrollo local

```bash
# Desde la raíz del monorepo
pnpm install
pnpm dev              # Corre web (puerto 3000) y socket (puerto 3001) en paralelo

# O por separado:
pnpm dev:web          # Solo frontend (Vite dev server, puerto 3000)
pnpm dev:socket       # Solo backend (tsx watch, puerto 3001)
```

**Proxy en desarrollo (Vite):**

Vite en dev mode proxia estas rutas al servidor del socket:

| Ruta | Target |
|------|--------|
| `/auth/*` | `http://localhost:3001` |
| `/media/*` | `http://localhost:3001` |
| `/ws` | `http://localhost:3001` (WebSocket) |

### 14.2 Producción con Docker

**Build multi-etapa:**

```dockerfile
# Stage 1: builder — instala deps y construye
FROM node:24-alpine AS builder
# ... pnpm install --frozen-lockfile && pnpm build ...

# Stage 2: runner — solo los artefactos finales
FROM node:24-alpine AS runner
# Instala nginx + supervisord
# Copia web dist → /app/web
# Copia socket dist/index.cjs → /app/socket/index.cjs
EXPOSE 3000
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
```

**Docker Compose:**

```yaml
services:
  edullm:
    image: kriziw/edullm:latest
    ports:
      - "3000:3000"
    volumes:
      - ./config:/app/config   # La config persiste fuera del contenedor
      - ./media:/app/media     # Los archivos de media persisten
```

### 14.3 Proxy inverso (Nginx en Docker)

En producción, Nginx (puerto 3000 dentro del contenedor) sirve la SPA estática y proxia al socket:

- `/*` → Servir archivos estáticos de `/app/web`
- `/ws` → Proxy WebSocket a Node.js (puerto 3001)
- `/auth` → Proxy HTTP a Node.js (puerto 3001)
- `/media` → Proxy HTTP a Node.js (puerto 3001)

---

## 15. Flujo del Juego — Paso a Paso

### Flujo del Manager

```
1. Navega a /manager
2. Si primer uso: crea admin (InitialAdminSetup)
3. Login (ManagerPassword o SSO)
4. Dashboard: ve tabs Quizzes / History / Settings
   - Quizzes: lista, crea, edita, borra
   - History: ve partidas pasadas, descarga CSV
   - Settings: audio por defecto, cambiar contraseña
   - [Admin] Managers: gestiona usuarios
   - [Admin] SSO: configura OIDC
5. Selecciona quiz → "Start" → game:create
6. Navega a /party/manager/:gameId (SHOW_ROOM)
   - Ve sala de espera con código QR y lista de jugadores
7. Cuando hay jugadores → "Start Game" → manager:startGame
8. Por cada pregunta:
   - SHOW_PREPARED (auto)
   - SHOW_QUESTION (auto)
   - SELECT_ANSWER: ve cuántos respondieron, puede "Skip"
   - SHOW_RESPONSES: ve distribución → "Next" (manager:showLeaderboard)
   - SHOW_LEADERBOARD: ve top 5 → "Next" (manager:nextQuestion)
9. Última pregunta → FINISHED (Podium)
10. "End Quiz" → regresa al dashboard
```

### Flujo del Jugador

```
1. Navega a /
2. Ingresa código de 6 dígitos (player:join → game:successRoom)
3. Ingresa username (player:login → game:successJoin)
4. Navega a /party/:gameId
5. Espera en WAIT hasta que manager inicia
6. Por cada pregunta:
   - SHOW_START: ve cuenta regresiva
   - SHOW_PREPARED: "Pregunta X se aproxima"
   - SHOW_QUESTION: ve texto/imagen
   - SELECT_ANSWER: elige respuesta → WAIT
   - SHOW_RESULT: ve si acertó, puntos, rank
7. FINISHED: ve podio
```

---

## 16. Sistema de Puntuación

**Fórmula (`packages/socket/src/utils/game.ts`):**

```typescript
export const timeToPoint = (startTime: number, segundos: number): number => {
  let points = 1000

  const tiempoTranscurrido = (Date.now() - startTime) / 1000  // en segundos
  points -= (1000 / segundos) * tiempoTranscurrido

  return Math.max(0, points)  // Mínimo 0 puntos
}
```

- **Máximo:** 1000 puntos (respuesta instantánea)
- **Mínimo:** 0 puntos (al agotar el tiempo o respuesta incorrecta)
- **Lineal:** se descuenta `(1000 / tiempo_total)` puntos por cada segundo transcurrido
- **Solo se suman puntos si la respuesta es correcta**
- Los puntos se calculan en el momento en que el servidor recibe el evento `player:selectedAnswer`

---

## 17. Mapa de Dónde Hacer Cambios

Esta sección guía a una IA u otro desarrollador sobre exactamente qué archivos tocar para cada tipo de cambio.

### Cambios de Lógica de Negocio

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Cambiar fórmula de puntuación | `packages/socket/src/utils/game.ts` → `timeToPoint()` |
| Cambiar duración de la cuenta regresiva inicial | `packages/socket/src/services/game.ts` → método `start()` (sleep(3)) |
| Cambiar duración entre estados del quiz | `packages/socket/src/services/game.ts` → método `newRound()` |
| Cambiar tiempo de gracia para reconexión de jugador | `packages/socket/src/services/game.ts` → constante `PLAYER_RECONNECT_GRACE_MS` |
| Cambiar tiempo de cleanup de partidas vacías | `packages/socket/src/services/registry.ts` → constantes `EMPTY_GAME_TIMEOUT_MINUTES` y `CLEANUP_INTERVAL_MS` |
| Validar más campos del username | `packages/common/src/validators/auth.ts` → `usernameValidator` |
| Cambiar longitud del código de invitación | `packages/socket/src/utils/game.ts` → `createInviteCode()` + `packages/common/src/validators/auth.ts` → `inviteCodeValidator` |

### Cambios en Quizzes

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Agregar campo a las preguntas | `packages/common/src/types/game/index.ts` → `QuizzQuestion`; luego `packages/socket/src/services/quizz.ts` → `normalizeQuizz()`; luego `packages/socket/src/services/game.ts` → `newRound()` y `selectAnswer()` |
| Cambiar límites (min/max respuestas, etc.) | `packages/socket/src/services/quizz.ts` → `normalizeQuizz()` |
| Cambiar el quiz de ejemplo | `packages/socket/src/services/config.ts` → método `init()` |

### Cambios en Autenticación

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Cambiar algoritmo de hashing | `packages/socket/src/services/accountStore.ts` → `hashPassword()` y `verifyPassword()` |
| Agregar roles | `packages/common/src/types/game/index.ts` → `ManagerRole`; luego `packages/socket/src/services/database.ts` → constraint CHECK; luego `packages/socket/src/index.ts` → `requireAdminManager()` |
| Configurar SSO diferente | `config/auth.json` (sin código); o UI en `/manager` tab SSO |
| Persistir sesiones de manager entre reinicios | `packages/socket/src/index.ts` → cambiar `authenticatedManagers` de `Map` a algo persistente |

### Nuevos Eventos WebSocket

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Agregar evento C → S | 1. `packages/common/src/types/game/socket.ts` → `ClientToServerEvents`; 2. `packages/socket/src/index.ts` → `socket.on(...)` |
| Agregar evento S → C | 1. `packages/common/src/types/game/socket.ts` → `ServerToClientEvents`; 2. Usar en el frontend con `useEvent()` |

### Cambios de Base de Datos

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Agregar columna a tabla | `packages/socket/src/services/database.ts` → `initializeSchema()` + agregar `ensureColumn()` para migración |
| Agregar tabla nueva | `packages/socket/src/services/database.ts` → `initializeSchema()` |
| Agregar CRUD de nueva tabla | Crear nuevo archivo en `packages/socket/src/services/` similar a `oidcStore.ts` |

### Cambios de UI (Frontend)

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Cambiar lo que ve el jugador durante SELECT_ANSWER | `packages/web/src/features/game/components/states/Answers.tsx` |
| Cambiar el podio final | `packages/web/src/features/game/components/states/Podium.tsx` |
| Agregar pantalla nueva al juego | 1. Crear componente en `states/`; 2. Agregar STATUS en `packages/common/src/types/game/status.ts`; 3. Mapear en `packages/web/src/features/game/utils/constants.ts` |
| Cambiar colores de las respuestas | `packages/web/src/features/game/utils/constants.ts` → `ANSWERS_COLORS` |
| Agregar tab al dashboard del manager | `packages/web/src/pages/game/auth/manager/page.tsx` → constantes `BASE_TABS` / `ADMIN_TAB` |
| Cambiar sonidos | `packages/web/src/features/game/utils/constants.ts` → `SFX_*`; archivos en `public/sounds/` |

### Cambios de Configuración / Infraestructura

| Si quieres... | Archivo(s) a modificar |
|--------------|----------------------|
| Cambiar puerto del backend | `packages/socket/src/index.ts` → `WS_PORT`; `packages/web/vite.config.ts` → targets del proxy |
| Cambiar puerto del frontend | `packages/web/vite.config.ts` → `server.port`; `Dockerfile` → `EXPOSE` |
| Agregar variable de entorno | `.env`; acceder en código con `process.env.VAR_NAME` |
| Cambiar la imagen Docker base | `Dockerfile` → `FROM node:24-alpine` |
| Agregar nuevo formato de audio soportado | `packages/socket/src/index.ts` → objeto `mimeTypes` |

---

_Fin de la documentación. Última actualización basada en análisis completo del código fuente del repositorio._
