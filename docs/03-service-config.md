# Servicio Config

> **Parte de:** [Índice](./INDEX.md)  
> **Archivo fuente:** `packages/socket/src/services/config.ts` (545 líneas)  
> **Relacionado con:** [02-database](./02-database.md) · [04-service-accountstore](./04-service-accountstore.md) · [08-service-oidc](./08-service-oidc.md)

---

## Responsabilidad

`Config` lee y escribe los archivos de configuración del **filesystem**. No usa la base de datos. Gestiona:

- `config/game.json` — contraseña legacy y audio por defecto
- `config/auth.json` — configuración OIDC/SSO
- `config/quizz/*.json` — quizzes en formato archivo (sistema legacy)
- `media/` — directorio de archivos de audio subidos

---

## Resolución de rutas

```typescript
const inContainerPath = process.env.CONFIG_PATH

// Ruta a config/
const getPath = (path: string = "") =>
  inContainerPath
    ? resolve(inContainerPath, path)            // Docker: /app/config/...
    : resolve(process.cwd(), "../../config", path) // Dev: MindBuzz/config/...

// Ruta a media/
const getMediaPath = (path: string = "") =>
  inContainerPath
    ? resolve(inContainerPath, "..", "media", path) // Docker: /app/media/...
    : resolve(process.cwd(), "../../media", path)   // Dev: MindBuzz/media/...
```

**Variable de entorno `CONFIG_PATH`:** Si está definida, todas las rutas se calculan relativas a su valor. En Docker se configura como `/app/config`.

---

## Método `init()`

Se llama **una sola vez** al arrancar el servidor. Crea toda la estructura de archivos si no existe:

```
config/
├── game.json         ← crea con { "managerPassword": "PASSWORD" }
├── auth.json         ← crea con config OIDC deshabilitada por defecto
└── quizz/
    └── example.json  ← crea un quiz de ejemplo con 3 preguntas

media/               ← crea directorio vacío
```

---

## `config/game.json`

```json
{
  "managerPassword": "PASSWORD",
  "defaultAudio": "/media/nombre.mp3"
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `managerPassword` | string | Contraseña del admin legacy. Si existe y no es `"PASSWORD"`, el servidor crea automáticamente un admin al arrancar. |
| `defaultAudio` | string (opcional) | URL de audio reproducida por defecto en las partidas. |

**Métodos relacionados:**

| Método | Descripción |
|--------|-------------|
| `Config.game()` | Lee y parsea `game.json`. Lanza error si no existe. |
| `Config.managerSettings()` | Devuelve `{ defaultAudio }` desde `game.json` |
| `Config.updateManagerSettings(settings)` | Actualiza `game.json` con nueva contraseña y/o audio |

---

## `config/auth.json`

```json
{
  "oidc": {
    "enabled": false,
    "autoProvisionEnabled": false,
    "discoveryUrl": "",
    "clientId": "",
    "clientSecret": "",
    "scopes": ["openid", "profile", "email"],
    "roleClaimPath": "groups",
    "adminRoleValues": ["mindbuzz-admin"],
    "managerRoleValues": ["mindbuzz-manager"]
  }
}
```

| Campo | Descripción |
|-------|-------------|
| `enabled` | Activa el botón SSO en la UI del manager |
| `autoProvisionEnabled` | Si `true`, crea managers automáticamente en el primer login SSO |
| `discoveryUrl` | URL del discovery document OIDC (`.well-known/openid-configuration`) |
| `clientId` | Client ID registrado en el proveedor |
| `clientSecret` | Secret del cliente — se guarda en texto plano en el JSON |
| `scopes` | Scopes OIDC solicitados |
| `roleClaimPath` | Path punteado al claim de rol en el JWT (ej: `"groups"`, `"realm_access.roles"`) |
| `adminRoleValues` | Valores del claim que asignan rol `admin` |
| `managerRoleValues` | Valores del claim que asignan rol `manager` |

**Métodos relacionados:**

| Método | Descripción |
|--------|-------------|
| `Config.oidc()` | Devuelve `OidcConfig` (sin `clientSecret`, con `hasClientSecret: boolean`) |
| `Config.oidcSecret()` | Devuelve el `clientSecret` en crudo (usado solo por `OidcAuth`) |
| `Config.oidcStatus()` | Calcula si OIDC está `{ enabled, configured }` |
| `Config.updateOidc(settings)` | Valida y escribe `auth.json` |
| `Config.validateTestableOidcConfig(settings)` | Valida config sin requerir `clientSecret` |

**Cuándo OIDC está "configured":** Se considera configurado cuando `discoveryUrl`, `clientId`, `clientSecret`, `roleClaimPath` no están vacíos y hay al menos un valor en `adminRoleValues` o `managerRoleValues`.

---

## `config/quizz/*.json` (sistema legacy)

Directorio con archivos JSON de quizzes. **Este sistema es legacy**: en versiones nuevas los quizzes viven en SQLite. Sin embargo, se siguen leyendo para migración inicial.

**Formato de un archivo de quiz:**
```json
{
  "subject": "Nombre del Quiz",
  "questions": [
    {
      "question": "Texto de la pregunta",
      "answers": ["Op1", "Op2", "Op3", "Op4"],
      "solutions": [1],
      "cooldown": 5,
      "time": 20,
      "image": "https://...",
      "audio": "/media/audio.mp3",
      "video": "https://..."
    }
  ]
}
```

El `id` del quiz es el **nombre del archivo sin extensión** (ej: `ejemplo.json` → id `"ejemplo"`).

**Métodos legacy:**

| Método | Descripción |
|--------|-------------|
| `Config.quizz()` | Lee todos los `.json` del directorio, normaliza y devuelve array |
| `Config.createQuizz(subject)` | Crea archivo JSON (genera id desde el subject) |
| `Config.updateQuizz(quizzId, quizz)` | Actualiza archivo JSON |
| `Config.deleteQuizz(quizzId)` | Elimina archivo JSON |

> ⚠️ Estos métodos solo son llamados durante la **migración** al crear el primer admin (`AccountStore.migrateLegacyResources()`). Los quizzes nuevos se crean directamente en SQLite via `AccountStore`.

---

## Media — archivos de audio

**Métodos relacionados con media:**

| Método | Descripción |
|--------|-------------|
| `Config.mediaDirectory()` | Devuelve la ruta absoluta al directorio `media/` |
| `Config.uploadMedia(filename, content)` | Decodifica base64 y guarda en `media/`. Devuelve URL `/media/filename`. |

**Seguridad del upload:**
1. El filename pasa por sanitización: `replace(/[^a-zA-Z0-9._-]+/g, "-")`
2. Solo caracteres alfanuméricos, puntos, guiones

**Cómo se sirven:** El servidor HTTP de `index.ts` maneja `GET /media/*`. Ver [01-architecture](./01-architecture.md).

**Formatos de audio soportados:** `.aac`, `.mp3`, `.m4a`, `.ogg`, `.wav`, `.webm`

---

## Normalización y validación

`Config` normaliza todos los valores de configuración antes de escribirlos:

```typescript
private static normalizeStoredOidcConfig(config) {
  return {
    enabled: config?.enabled === true,
    discoveryUrl: config?.discoveryUrl?.trim() ?? "",
    clientId: config?.clientId?.trim() ?? "",
    // ...
    scopes: normalizeStringList(config?.scopes, DEFAULT_OIDC_SCOPES),
    adminRoleValues: normalizeStringList(config?.adminRoleValues, []),
  }
}
```

`normalizeStringList` deduplica, limpia espacios y filtra vacíos.

**Validación OIDC al guardar (cuando `enabled = true`):**
- `discoveryUrl` requerida
- `clientId` requerido
- `clientSecret` requerido
- `roleClaimPath` requerido
- Al menos un valor en `adminRoleValues` o `managerRoleValues`

---

## Flujo de uso durante el arranque

```
index.ts
  └── Config.init()
        ├── ¿Existe config/?      No → mkdir
        ├── ¿Existe game.json?    No → crea con password "PASSWORD"
        ├── ¿Existe auth.json?    No → crea con OIDC deshabilitado
        ├── ¿Existe quizz/?       No → mkdir + crea example.json
        └── ¿Existe media/?       No → mkdir
```

Después de `Config.init()`, el servidor llama a `AccountStore.init()` que puede usar `Config.game()` y `Config.quizz()` para migración legacy.
