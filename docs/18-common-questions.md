# 18 - Preguntas Frecuentes (Common Questions)

Este documento recopila dudas comunes sobre la arquitectura, el modelo de datos y el funcionamiento general de la plataforma eduLLM.

## ¿Cuál es la diferencia entre un `admin` y un `manager`?

Tanto el **admin** como el **manager** son roles dentro de la plataforma (definidos conceptualmente como `ManagerRole = "admin" | "manager"`), pero tienen distintos niveles de acceso:

**1. Administrador (Admin):**
Es un rol con privilegios elevados que, además de las funciones básicas del sistema, tiene acceso exclusivo a la configuración y gestión global de la plataforma. Específicamente, solo un admin puede:
- **Gestión de Usuarios:** Acceder al panel de managers (`ManagersPanel`) para listar, crear o modificar otros usuarios de la plataforma.
- **Configuración de SSO/OIDC:** Acceder al panel de configuración OIDC (`SsoSettingsPanel`), donde puede establecer parámetros de validación externa, tokens, secretos, y mapeo de claims para grupos de roles.
- **Bootstrapping Inicial:** El primer usuario creado para arrancar el sistema en una base de datos vacía toma obligatoriamente el rol de `admin`.
- **Acceso a Funciones Ocultas:** Tienen las vistas y pestañas exclusivas habilitadas como `ADMIN_TAB` o `ADMIN_SSO_TAB`.

**2. Manager:**
Es el usuario regular u operador en el sistema (por ejemplo, el encargado de ejecutar y presentar quizzes). 
- Tiene acceso únicamente a las pestañas y vistas base (`BASE_TABS`).
- Puede administrar sus Quizzes, iniciar sesiones, y llevar el control del juego.
- No puede modificar perfiles de otros managers, por lo que su gestión se limita a sus propios contenidos.
- No puede alterar la configuración de autenticación del sistema (SSO).

En resumen, la principal diferencia radica en que el **admin tiene permisos exclusivos para gestionar a otros usuarios y configurar el inicio de sesión centralizado (SSO)**, mientras que el **manager es un usuario altamente operativo** enfocado a utilizar la aplicación dentro de sus límites normales.

## ¿Cómo se crea el primer admin/manager?
El primer usuario del sistema se crea mediante un proceso llamado **bootstrapping**. Si al iniciar la aplicación la base de datos de usuarios (`AccountStore`) está completamente vacía, la interfaz web mostrará una pantalla de inicialización especial (`InitialAdminSetup.tsx`). En este formulario se solicitan unas credenciales iniciales de nombre de usuario y contraseña y, al guardarlas, este primer usuario recibe obligatoriamente el rol de `admin`.
*Nota: Si el sistema detecta contraseñas antiguas definidas directamente en el archivo `config.json` (Legacy Mode), las migrará automáticamente creando un primer administrador al levantar el servicio.*

## ¿Cómo se crean las demás cuentas de admin/manager y cómo se asignan sus roles?
La forma en la que se crean las cuentas y se asignan sus roles depende del método de autenticación configurado:

**1. Cuentas Locales (Manuales):**
Únicamente si ya eres `admin`, tendrás acceso a la pestaña "Panel de Managers" (`ManagersPanel`). Desde esa pantalla, el administrador puede crear nuevas cuentas rellenando un formulario con el *Username*, la *Contraseña*, y decidiendo explícitamente a través de un menú si el rol será `admin` o `manager`.

**2. Cuentas OIDC / SSO (Automáticas):**
Si la integración con Single Sign-On (como LDAP, Keycloak o Google Workspace) está habilitada y la directiva `autoProvisionEnabled` está activa en la configuración, **las cuentas se crearán automáticamente on-the-fly** cuando cada usuario intente ingresar por primera vez.
* **Asignación de Roles en OIDC:** El rol del usuario `admin` o `manager` **se calcula dinámicamente**. El backend examina el Token JWT entregado por tu proveedor para buscar la variable de grupos (definida en el `roleClaimPath` de la configuración). Si el valor coincide con los permisos requeridos (lo que hayas listado en `adminRoleValues`), el usuario se guarda como `admin`. Si no, y concuerda con un `managerRoleValues`, se establece como `manager`. ¡Con cada nuevo inicio de sesión el sistema actualizará sus roles en base a los datos provenientes del proveedor!

## ¿Cómo se loguea un admin o un manager?
No importa si eres administrador o manager, el ingreso siempre es desde la misma página de autenticación principal de administradores (`ManagerAuthPage`).
- **Autenticación Local:** Introducen su *Username* y *Contraseña* directamente en el formulario.
- **Autenticación OIDC/SSO:** Cuentan con un botón especial (ej. "Iniciar Sesión Integrado") que los redirecciona al portal de login de la empresa. Al identificarse allí, son redirigidos de nuevo a la aplicación y el backend autentica la sesión.
 
En ambos casos el estado de sesión y los tokens se gestionan de manera idéntica en el navegador (Zustand Stores y WebSockets).

## ¿Los cuestionarios están abiertos y un administrador puede ver los de todos los maestros?
**No.** Los cuestionarios (subjects) son completamente **privados y aislados por cuenta**. 

En la base de datos, cada cuestionario está fuertemente enlazado al `manager_id` de la persona que lo creó. Ni siquiera un usuario con el rol de `admin` puede ver, modificar o acceder a los cuestionarios creados por otros maestros o managers.
- El rol de `admin` solo otorga permisos superiores para **gestionar usuarios** (añadirlos o borrarlos) y modificar **configuraciones del sistema** (como SSO/OIDC).
- **Los contenidos (quizzes) siguen siendo 100% aislados:** "Cada usuario (ya sea Admin o Manager) solo ve sus propios cuestionarios".

## ¿Qué es el `cooldown` en una pregunta y en qué se diferencia del `time`?

En la configuración de cada pregunta dentro de un cuestionario, existen dos parámetros de tiempo fundamentales:

1. **Cooldown (Tiempo de lectura):** Es el tiempo (en segundos) que se muestra el texto de la pregunta en pantalla **antes** de que aparezcan las opciones de respuesta. Su propósito es dar a los estudiantes un momento para leer y procesar la pregunta sin la presión de las opciones, asegurando que todos empiecen a responder al mismo tiempo.
2. **Time (Tiempo de respuesta):** Es el tiempo límite (en segundos) que tienen los estudiantes para elegir una respuesta una vez que las opciones han aparecido en pantalla.

En resumen: **Cooldown** es para leer la pregunta y **Time** es para seleccionar la respuesta.
