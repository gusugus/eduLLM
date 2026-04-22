# Frontend — Componentes React

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:** `packages/web/src/features/game/components/`  
> **Relacionado con:** [10-frontend-router](./10-frontend-router.md) · [11-frontend-stores](./11-frontend-stores.md) · [14-game-flow](./14-game-flow.md)

---

## Organización de componentes

```
components/
├── GameWrapper.tsx        ← layout de partida activa
├── Button.tsx
├── Input.tsx
├── Form.tsx
├── AnswerButton.tsx
├── Loader.tsx
├── Toaster.tsx
│
├── states/                ← UN componente por STATUS del juego
│   ├── Room.tsx           → SHOW_ROOM (manager: sala de espera)
│   ├── Start.tsx          → SHOW_START
│   ├── Prepared.tsx       → SHOW_PREPARED
│   ├── Question.tsx       → SHOW_QUESTION
│   ├── Answers.tsx        → SELECT_ANSWER
│   ├── Wait.tsx           → WAIT
│   ├── Result.tsx         → SHOW_RESULT
│   ├── Responses.tsx      → SHOW_RESPONSES (solo manager)
│   ├── Leaderboard.tsx    → SHOW_LEADERBOARD (solo manager)
│   └── Podium.tsx         → FINISHED
│
├── create/                ← componentes del panel del manager
│   ├── InitialAdminSetup.tsx
│   ├── ManagerPassword.tsx
│   ├── SelectQuizz.tsx
│   ├── QuizzEditor.tsx
│   ├── HistoryPanel.tsx
│   ├── SettingsPanel.tsx
│   ├── SsoSettingsPanel.tsx
│   └── ManagersPanel.tsx
│
├── join/                  ← formularios de entrada del jugador
│   ├── Room.tsx
│   └── Username.tsx
│
└── icons/                 ← SVG como componentes React
    ├── Triangle.tsx       → respuesta 0 (rojo)
    ├── Rhombus.tsx        → respuesta 1 (azul)
    ├── Circle.tsx         → respuesta 2 (amarillo)
    ├── Square.tsx         → respuesta 3 (verde)
    ├── CricleCheck.tsx    → respuesta correcta
    ├── CricleXmark.tsx    → respuesta incorrecta
    └── Pentagon.tsx
```

---

## GameWrapper — Layout de partida

**Archivo:** `components/GameWrapper.tsx`

Wrapper compartido por `ManagerGamePage` y `PlayerGamePage`. Provee:

1. **Fondo fijo:** `background.webp` en posición `fixed` (siempre visible detrás del contenido)
2. **Indicador de progreso:** `X / N` en la esquina superior izquierda (cuando hay `questionStates`)
3. **Botón de acción del manager:** en la esquina superior derecha, condicional según STATUS
4. **Barra del jugador:** en la parte inferior, muestra username y puntos
5. **Spinner "Connecting...":** si no hay conexión y no hay status

```tsx
<GameWrapper statusName={status?.name} onNext={handleSkip} manager>
  <CurrentComponent data={status.data} />
</GameWrapper>
```

| Prop | Tipo | Descripción |
|------|------|-------------|
| `statusName` | `Status \| undefined` | Determina qué botón mostrar |
| `onNext` | `() => void` | Callback del botón de acción |
| `manager` | `boolean` | Si `true`: muestra botón, oculta barra de jugador |
| `children` | `ReactNode` | El componente de estado actual |

---

## Componentes de Estados del Juego (`states/`)

Cada componente recibe un prop `data` tipado por su STATUS correspondiente.

### `Room.tsx` — `SHOW_ROOM`

**Solo visible para el manager.** Sala de espera antes de iniciar.

**`data: { text: string, inviteCode?: string }`**

Muestra:
- Código QR generado con `react-qr-code` (URL completa del join)
- El código de 6 dígitos en texto grande
- Lista de jugadores conectados (escucha `manager:newPlayer`, `manager:removePlayer`, `game:totalPlayers`)

### `Start.tsx` — `SHOW_START`

**Visible para todos.** Cuenta regresiva de 3 segundos al iniciar.

**`data: { time: number, subject: string }`**

Muestra:
- Nombre del quiz (`subject`)
- Cuenta regresiva animada

### `Prepared.tsx` — `SHOW_PREPARED`

**Visible para todos.** "La pregunta X se acerca".

**`data: { totalAnswers: number, questionNumber: number }`**

Muestra:
- Número de pregunta
- Total de opciones de respuesta

### `Question.tsx` — `SHOW_QUESTION`

**Visible para todos.** Preview de la pregunta antes de mostrar opciones.

**`data: { question: string, image?: string, cooldown: number }`**

Muestra:
- Texto de la pregunta
- Imagen (si existe)
- Temporizador de countdown visual (basado en `cooldown`)

### `Answers.tsx` — `SELECT_ANSWER`

**Visible para todos.** El momento de responder.

**`data: { question, answers[], multipleCorrect, image?, video?, audio?, time, totalPlayer }`**

Muestra:
- Texto + imagen de la pregunta
- Video (si existe) con autoplay
- Botones de respuesta con colores e íconos (rojo/triángulo, azul/rombo, amarillo/círculo, verde/cuadrado)
- Temporizador de countdown (basado en `time`)

Al presionar un botón:
```typescript
socket.emit("player:selectedAnswer", { gameId, data: { answerKey: index } })
```

Si `multipleCorrect === true`, muestra una indicación visual (la pregunta tiene varias respuestas correctas).

**Audio:** Si hay `audio` en los datos, reproduce automáticamente con `use-sound`. Si no, usa el `defaultAudio` del manager.

### `Wait.tsx` — `WAIT`

**Visible para jugadores que ya respondieron.**

**`data: { text: string }`**

Muestra solo el texto de espera (ej: "Waiting for other players...").

### `Result.tsx` — `SHOW_RESULT`

**Visible para cada jugador individualmente.** Resultado propio.

**`data: { correct, message, points, myPoints, rank, aheadOfMe }`**

Muestra:
- ¿Correcto o incorrecto? (con ícono animado)
- Puntos ganados en esta ronda
- Total de puntos acumulados
- Posición actual en el ranking
- Nombre del jugador justo delante (`aheadOfMe`)

### `Responses.tsx` — `SHOW_RESPONSES`

**Solo visible para el manager.** Estadísticas de la ronda.

**`data: { question, responses: Record<number,number>, correct[], answers[], image? }`**

`responses` es un diccionario `{ [answerId]: count }` — cuántos jugadores eligieron cada opción.

Muestra:
- Texto de la pregunta + imagen
- Barras de progreso por cada respuesta con recuento de jugadores
- Las respuestas correctas resaltadas en verde

### `Leaderboard.tsx` — `SHOW_LEADERBOARD`

**Solo visible para el manager.** Tabla de líderes entre preguntas.

**`data: { oldLeaderboard: Player[], leaderboard: Player[] }`**

Muestra el top 5. Anima los cambios de posición comparando `oldLeaderboard` vs `leaderboard`.

### `Podium.tsx` — `FINISHED`

**Visible para todos.** Pantalla final con los ganadores.

**`data: { subject: string, top: Player[], runId: string }`**

Muestra:
- Top 3 en formato podio (2do → 1ro → 3ro para el efecto visual)
- Animación de confetti (con `react-confetti`)
- Efectos de sonido (redoble + anuncio de 3º, 2º, 1º)

---

## Componentes del Panel Manager (`create/`)

### `InitialAdminSetup.tsx`
Formulario de creación del primer admin. Campos: username y contraseña. Validación igual que el login.

### `ManagerPassword.tsx`
Formulario de login. Campos: username, contraseña.  
Muestra botón "Sign in with SSO" si `oidcStatus.enabled && oidcStatus.configured`.

### `SelectQuizz.tsx`
Lista de quizzes del manager. Acciones por quiz:
- **Editar** → abre `QuizzEditor`
- **Borrar** → confirma y emite `manager:deleteQuizz`
- **Iniciar** → emite `game:create quizzId`
Botón "New Quiz" → emite `manager:createQuizz { subject }` con un input de nombre.

### `QuizzEditor.tsx`
Editor completo de quiz. Permite:
- Editar el nombre (subject) del quiz
- Agregar/eliminar preguntas
- Por pregunta: texto, imagen (URL), video (URL), audio (URL o local), respuestas (2-4), soluciones, cooldown, time
- Mover preguntas de orden
- Guardar (`manager:updateQuizz`) o volver sin guardar

### `HistoryPanel.tsx`
Lista de partidas pasadas. Para cada partida:
- Subject, fecha, duración, total jugadores, ganador
- Botón "Download CSV" → emite `manager:downloadHistory { runId }`

### `SettingsPanel.tsx`
Configuración personal del manager:
- Audio por defecto: URL externa o subir archivo local
  - Subir local: emite `manager:uploadMedia { filename, content: base64 }`
- Cambiar contraseña: emite `manager:updateSettings { password }`

### `ManagersPanel.tsx`
(Solo admin) Lista todos los managers:
- Crear nuevo manager: emite `manager:createManager`
- Resetear contraseña: emite `manager:resetManagerPassword`
- Habilitar/deshabilitar: emite `manager:setManagerDisabled`

### `SsoSettingsPanel.tsx`
(Solo admin) Configuración OIDC:
- Campos: enabled, autoProvisionEnabled, discoveryUrl, clientId, clientSecret, scopes, roleClaimPath, adminRoleValues, managerRoleValues
- Botón "Test Connection" → emite `manager:testOidcConfig` — muestra resultado de discovery
- Botón "Save" → emite `manager:updateOidcConfig`

---

## Componentes de Join (`join/`)

### `Room.tsx`
Input de código de sala: 6 dígitos.  
Validación: Zod `inviteCodeValidator` (exactamente 6 chars).  
Al enviar: emite `player:join inviteCode`.

### `Username.tsx`
Input de username.  
Validación: Zod `usernameValidator` (4-20 chars).  
Al enviar: emite `player:login { gameId, data: { username } }`.

---

## Constantes de UI

**Archivo:** `packages/web/src/features/game/utils/constants.ts`

### Colores e íconos de respuestas

```typescript
export const ANSWERS_COLORS = ["bg-red-500", "bg-blue-500", "bg-yellow-500", "bg-green-500"]
export const ANSWERS_ICONS  = [Triangle, Rhombus, Circle, Square]
```

El índice 0 = rojo/triángulo, 1 = azul/rombo, 2 = amarillo/círculo, 3 = verde/cuadrado.

### Mapas de STATUS → Componente

```typescript
// Para jugadores
export const GAME_STATE_COMPONENTS = {
  [STATUS.SELECT_ANSWER]: Answers,
  [STATUS.SHOW_QUESTION]: Question,
  [STATUS.WAIT]: Wait,
  [STATUS.SHOW_START]: Start,
  [STATUS.SHOW_RESULT]: Result,
  [STATUS.SHOW_PREPARED]: Prepared,
}

// Para manager (todos los anteriores + más)
export const GAME_STATE_COMPONENTS_MANAGER = {
  ...GAME_STATE_COMPONENTS,
  [STATUS.SHOW_ROOM]: Room,
  [STATUS.SHOW_RESPONSES]: Responses,
  [STATUS.SHOW_LEADERBOARD]: Leaderboard,
  [STATUS.FINISHED]: Podium,
}
```

### Archivos de sonido

```typescript
export const SFX_ANSWERS_MUSIC = "/sounds/answersMusic.mp3"
export const SFX_ANSWERS_SOUND = "/sounds/answersSound.mp3"
export const SFX_RESULTS_SOUND = "/sounds/results.mp3"
export const SFX_SHOW_SOUND    = "/sounds/show.mp3"
export const SFX_BOUMP_SOUND   = "/sounds/boump.mp3"
export const SFX_PODIUM_THREE  = "/sounds/three.mp3"
export const SFX_PODIUM_SECOND = "/sounds/second.mp3"
export const SFX_PODIUM_FIRST  = "/sounds/first.mp3"
export const SFX_SNEAR_ROOL    = "/sounds/snearRoll.mp3"
```

Los archivos están en `packages/web/public/sounds/`.
