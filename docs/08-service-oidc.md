# Servicio OidcAuth + OidcStore (SSO)

> **Parte de:** [Índice](./INDEX.md)  
> **Archivos fuente:**  
> - `packages/socket/src/services/oidcAuth.ts` (449 líneas)  
> - `packages/socket/src/services/oidcStore.ts` (140 líneas)  
> **Relacionado con:** [03-service-config](./03-service-config.md) · [04-service-accountstore](./04-service-accountstore.md) · [13-auth-sessions](./13-auth-sessions.md)

---

## ¿Qué es OIDC?

OpenID Connect (OIDC) permite que los managers se autentiquen usando un proveedor externo (Google, Azure AD, Okta, Keycloak, etc.) en lugar de una contraseña local.

MindBuzz implementa el flujo **Authorization Code con PKCE** — el estándar recomendado para aplicaciones server-side.

---

## Estructuras en memoria

```typescript
// Estado de autorización pendiente (mientras el usuario se autentica con el proveedor)
const authorizationStates = new Map<string, AuthorizationState>()

// Handoff post-callback (para pasar la sesión al socket del manager)
const loginHandoffs = new Map<string, LoginHandoff>()
```

**Estas estructuras NO persisten.** Si el servidor se reinicia durante un login SSO en curso, el flujo falla.

---

## TTLs (tiempos de vida)

| Estructura | TTL | Descripción |
|-----------|-----|-------------|
| `authorizationStates` | `10 minutos` | El usuario tiene 10 min para completar el login en el proveedor |
| `loginHandoffs` | `2 minutos` | El browser tiene 2 min para reconectar al socket y reclamar la sesión |

`cleanupExpiredEntries()` se llama al inicio de `buildAuthorizationUrl()` y `handleCallback()` para limpiar entradas expiradas.

---

## Flujo completo paso a paso

```
1. Manager → click "Login SSO"
   └── Frontend navega a /auth/oidc/login?clientId=UUID&returnTo=/manager

2. Servidor (/auth/oidc/login)
   ├── Genera state token (24 bytes aleatorios en base64url)
   ├── Genera nonce (24 bytes aleatorios en base64url)
   ├── Genera codeVerifier (48 bytes aleatorios)
   ├── Calcula codeChallenge = SHA-256(codeVerifier) en base64url
   ├── Guarda en authorizationStates[state] = { clientId, returnTo, codeVerifier, nonce }
   └── Redirige al authorization_endpoint del proveedor con:
         client_id, redirect_uri, response_type=code,
         scope, state, nonce, code_challenge, code_challenge_method=S256

3. Proveedor OIDC
   └── El usuario se autentica y autoriza
   └── Proveedor redirige a /auth/oidc/callback?code=...&state=...

4. Servidor (/auth/oidc/callback)
   ├── Valida state → busca en authorizationStates
   ├── Intercambia code por tokens en token_endpoint:
   │     grant_type=authorization_code, code, redirect_uri,
   │     client_id, client_secret, code_verifier
   ├── Recibe { access_token, id_token }
   ├── Valida id_token:
   │     ├── Decodifica payload JWT (sin verificar firma criptográfica)
   │     ├── Verifica iss === discovery.issuer
   │     ├── Verifica aud incluye clientId
   │     ├── Verifica nonce
   │     └── Verifica exp no expirado
   ├── Obtiene userinfo desde userinfo_endpoint (si existe)
   ├── Combina claims del id_token + userinfo
   ├── Mapea rol desde claims (roleClaimPath + adminRoleValues/managerRoleValues)
   ├── Busca identidad existente en BD (por issuer + subject)
   ├── Si no existe identidad:
   │     └── ¿autoProvisionEnabled?
   │           SI → AccountStore.createOidcManager(username, role)
   │           NO → error "SSO account is not provisioned"
   ├── Si existe → actualiza rol si cambió
   ├── OidcStore.upsertIdentity(...) → actualiza last_login_at
   ├── Guarda en loginHandoffs[clientId] = { manager, returnTo }
   └── Redirige a /manager?oidc=success

5. Frontend detecta ?oidc=success
   └── Cuando socket conecta → socket.emit("manager:completeOidcLogin")

6. Servidor (evento manager:completeOidcLogin)
   └── OidcAuth.consumeLoginHandoff(clientId) → devuelve { manager, returnTo }
   └── authenticatedManagers.set(clientId, manager)
   └── emitManagerDashboard(socket, manager)
```

---

## PKCE: Por qué y cómo

**PKCE** (Proof Key for Code Exchange) previene ataques de intercepción del `code`:

```typescript
// codeVerifier: secreto que solo el servidor conoce
const codeVerifier = toBase64Url(randomBytes(48))

// codeChallenge: hash del verifier enviado al proveedor
const codeChallenge = toBase64Url(createHash("sha256").update(codeVerifier).digest())

// En el callback, envía el codeVerifier original al proveedor
// El proveedor verifica que SHA-256(codeVerifier) === codeChallenge
```

Si un atacante intercepta el `code`, no puede canjearlo porque no tiene el `codeVerifier`.

---

## Mapeo de roles desde claims JWT

```typescript
// Config: roleClaimPath = "groups"
//         adminRoleValues = ["mindbuzz-admin"]
//         managerRoleValues = ["mindbuzz-manager"]

// El claim en el JWT: { groups: ["mindbuzz-admin", "devs"] }

const claimValue = getNestedClaim(claims, "groups")
// → ["mindbuzz-admin", "devs"]

const normalizedRoleValues = normalizeRoleValues(claimValue)
// → ["mindbuzz-admin", "devs"]

// ¿Alguno de los valores está en adminRoleValues?
→ "admin"
// ¿Alguno está en managerRoleValues?
→ "manager"
// Ninguno
→ null → error "Your account does not have a mapped MindBuzz role"
```

`getNestedClaim` permite paths anidados: `"realm_access.roles"` accede a `jwt.realm_access.roles`.

`normalizeRoleValues` acepta:
- Array: `["admin", "user"]`
- String CSV: `"admin, user"` → `["admin", "user"]`

---

## Derivación de username para managers SSO

```typescript
const deriveUsername = (claims) => {
  const preferredUsername = claims.preferred_username?.trim() ?? ""
  const email = claims.email?.trim() ?? ""
  const emailUsername = email.includes("@") ? email.split("@")[0] : email

  return preferredUsername
    || emailUsername
    || `oidc-user-${randomBytes(4).toString("hex")}`
}
```

Prioridad: `preferred_username` → parte local del `email` → `oidc-user-XXXXXXXX`

---

## OidcStore — Identidades en BD

**Archivo:** `packages/socket/src/services/oidcStore.ts`

CRUD de la tabla `manager_oidc_identities`.

| Método | Descripción |
|--------|-------------|
| `getIdentityByIssuerSubject(issuer, subject)` | Busca por la combinación única `(issuer, subject)` |
| `listIdentitiesForManager(managerId)` | Lista las identidades SSO de un manager |
| `upsertIdentity(input)` | Insert si no existe, Update si existe. Actualiza `last_login_at`, `email`, `username_claim`. |

Una identidad OIDC vincula:
- `manager_id` → UUID del manager en la BD local
- `issuer` → URL del proveedor (`https://accounts.google.com`)
- `subject` → `sub` claim del JWT (identificador único en el proveedor)

Un manager puede tener **múltiples identidades** (diferentes proveedores).

---

## Validación del ID Token

```typescript
// IMPORTANTE: MindBuzz NO verifica la firma criptográfica del JWT
// Confía en el TLS del canal y en que solo el proveedor conoce el client_secret

private static validateIdToken(idToken, discovery, nonce) {
  const claims = parseJwtClaims(idToken)  // decodifica base64 del payload
  
  if (claims.iss !== discovery.issuer) throw new Error("Invalid token issuer")
  if (!audiences.includes(config.clientId)) throw new Error("Invalid token audience")
  if (claims.nonce !== nonce) throw new Error("Invalid token nonce")
  if (claims.exp * 1000 < Date.now()) throw new Error("Expired ID token")
  
  return claims
}
```

No verifica la firma RS256/ES256 del JWT. En entornos de alta seguridad, considerar agregar verificación de firma.

---

## Cómo configurar SSO

1. Registrar la aplicación en el proveedor (Google/Azure/Okta/Keycloak)
2. Configurar `redirect_uri` en el proveedor: `https://tu-dominio.com/auth/oidc/callback`
3. Copiar `client_id` y `client_secret`
4. En el dashboard del manager (tab SSO, requiere rol admin):
   - Pegar `discoveryUrl` (ej: `https://accounts.google.com/.well-known/openid-configuration`)
   - Pegar `clientId` y `clientSecret`
   - Configurar `roleClaimPath` según el proveedor
   - Configurar los valores de rol esperados
   - Activar si se desea auto-provisión
5. Habilitar y guardar
