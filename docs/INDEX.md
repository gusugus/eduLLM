# MindBuzz — Índice de Documentación

> Proyecto: quiz en tiempo real estilo Kahoot · Versión `1.10.2`  
> Cada archivo de este directorio documenta **una sola capa o componente** del sistema.  
> Léelos por separado según lo que necesites modificar o entender.

---

## Archivos disponibles

| # | Archivo | Qué contiene |
|---|---------|-------------|
| 1 | [01-architecture.md](./01-architecture.md) | Visión general, stack, estructura de directorios, infraestructura y despliegue |
| 2 | [02-database.md](./02-database.md) | Esquema SQLite completo: tablas, columnas, índices, migraciones |
| 3 | [03-service-config.md](./03-service-config.md) | Servicio Config: archivos JSON de configuración del filesystem |
| 4 | [04-service-accountstore.md](./04-service-accountstore.md) | Servicio AccountStore: CRUD de managers, quizzes y configuraciones |
| 5 | [05-service-game.md](./05-service-game.md) | Clase Game: lógica completa de una partida en memoria |
| 6 | [06-service-registry.md](./06-service-registry.md) | Servicio Registry: registro en memoria de partidas activas |
| 7 | [07-service-history.md](./07-service-history.md) | Servicio History: persistencia y exportación de historial de partidas |
| 8 | [08-service-oidc.md](./08-service-oidc.md) | OidcAuth + OidcStore: flujo SSO/PKCE completo |
| 9 | [09-websocket-events.md](./09-websocket-events.md) | Todos los eventos Socket.IO (cliente↔servidor), con payloads |
| 10 | [10-frontend-router.md](./10-frontend-router.md) | Rutas React, páginas, layouts y navegación |
| 11 | [11-frontend-stores.md](./11-frontend-stores.md) | Zustand stores, SocketProvider y gestión de estado global |
| 12 | [12-frontend-components.md](./12-frontend-components.md) | Componentes React: estados del juego, panel manager, UI general |
| 13 | [13-auth-sessions.md](./13-auth-sessions.md) | Autenticación, sesiones, localStorage y flujo OIDC desde el cliente |
| 14 | [14-game-flow.md](./14-game-flow.md) | Flujo completo del juego paso a paso, STATUS y transiciones |
| 15 | [15-scoring-timings.md](./15-scoring-timings.md) | Sistema de puntuación y todos los tiempos/timeouts del sistema |
| 16 | [16-common-types.md](./16-common-types.md) | Tipos TypeScript compartidos, validadores y utils comunes |
| 17 | [17-where-to-change.md](./17-where-to-change.md) | Guía práctica: dónde tocar el código para cada tipo de cambio |
| 18 | [18-common-questions.md](./18-common-questions.md) | Preguntas frecuentes y dudas comunes sobre la plataforma |
| 19 | [19-todo.md](./19-todo.md) | ToDo General: Registro de tareas pendientes y seguimiento |
| 20 | [20-team-guidelines.md](./20-team-guidelines.md) | Buenas prácticas de desarrollo, metodología y patrones de trabajo en grupo |

---

## Cómo se entrelazan los archivos

El sistema tiene tres capas principales y un paquete de tipos compartidos. El siguiente diagrama muestra qué depende de qué:

```
┌─────────────────────────────────────────────────────────────────┐
│                    @mindbuzz/common                             │
│              [16-common-types.md]                               │
│   Tipos TypeScript + Validadores Zod + Utils de audio          │
│   ← Todo el backend y frontend importa de aquí                 │
└────────────────────────┬────────────────────────────────────────┘
                         │ importa tipos
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌────────────────────┐       ┌──────────────────────────────────┐
│  @mindbuzz/socket  │       │        @mindbuzz/web              │
│  (Backend Node.js) │       │       (Frontend React)            │
│                    │       │                                   │
│  [03] Config       │       │  [10] Router + Páginas            │
│  [04] AccountStore │       │  [11] Stores + SocketProvider     │
│  [05] Game         │       │  [12] Componentes                 │
│  [06] Registry     │       │  [13] Auth desde cliente          │
│  [07] History      │       │                                   │
│  [08] OidcAuth     │       │                                   │
│       + OidcStore  │       │                                   │
│                    │       │                                   │
│  ← todos usan →   │       │                                   │
│  [02] Database     │       │                                   │
└────────┬───────────┘       └──────────────┬───────────────────┘
         │                                  │
         │   [09] WebSocket Events           │
         └──────────────WebSocket───────────┘
                    (Socket.IO /ws)

[01] Architecture — visión global de todo
[14] Game Flow    — secuencia temporal entre backend y frontend
[15] Scoring      — detalles de tiempos dentro de Game
[17] Where to change — guía de modificaciones
```

### Relaciones clave entre servicios del backend

```
index.ts (servidor principal)
  ├── usa Config          → lee archivos JSON del filesystem
  ├── usa AccountStore    → gestiona managers/quizzes en SQLite
  │     └── usa Database  → conexión SQLite singleton
  │     └── usa History   → para migración legacy
  │     └── usa Config    → para migración legacy
  ├── usa Registry        → partidas en memoria
  ├── usa History         → historial SQLite
  │     └── usa Database
  ├── usa OidcAuth        → flujo SSO
  │     └── usa Config    → config OIDC
  │     └── usa AccountStore → crear/actualizar managers
  │     └── usa OidcStore → identidades OIDC en SQLite
  │           └── usa Database
  └── crea instancias de Game
        └── usa Registry  → para registrar/eliminar
        └── usa History   → para persistir al terminar
```

### Relaciones clave en el frontend

```
main.tsx
  └── Router
        └── GameLayout
              └── SocketProvider  [11]
                    └── (todas las páginas y componentes usan useSocket/useEvent)
              └── Páginas [10]
                    ├── ManagerAuthPage  → usa useManagerStore, useQuestionStore
                    ├── ManagerGamePage  → usa useManagerStore, useQuestionStore
                    └── PlayerGamePage   → usa usePlayerStore, useQuestionStore
                          └── GameWrapper [12]
                                └── Componentes de estado [12]
                                      (Room, Start, Prepared, Question,
                                       Answers, Wait, Result, Responses,
                                       Leaderboard, Podium)
```

---

## Por dónde empezar según tu tarea

| Tarea | Lee primero | Lee después |
|-------|------------|-------------|
| Entender el sistema desde cero | [01-architecture](./01-architecture.md) | [14-game-flow](./14-game-flow.md) |
| Modificar la lógica del quiz/partida | [05-service-game](./05-service-game.md) | [15-scoring-timings](./15-scoring-timings.md) |
| Agregar o cambiar eventos WebSocket | [09-websocket-events](./09-websocket-events.md) | [05-service-game](./05-service-game.md) |
| Cambiar la base de datos | [02-database](./02-database.md) | [04-service-accountstore](./04-service-accountstore.md) |
| Modificar la UI del juego | [12-frontend-components](./12-frontend-components.md) | [14-game-flow](./14-game-flow.md) |
| Cambiar autenticación | [13-auth-sessions](./13-auth-sessions.md) | [08-service-oidc](./08-service-oidc.md) |
| Agregar un campo a los quizzes | [16-common-types](./16-common-types.md) | [17-where-to-change](./17-where-to-change.md) |
| No sé qué tocar | [17-where-to-change](./17-where-to-change.md) | — |
| Dudas y conceptos clave | [18-common-questions](./18-common-questions.md) | — |
| Lista de tareas general | [19-todo](./19-todo.md) | — |
| Metodología de equipo | [20-team-guidelines](./20-team-guidelines.md) | — |
