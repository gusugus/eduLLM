# Registro de Cambios: Login de Estudiantes (PostgreSQL)

## ¿Qué se cambió?

1. **Integración con base de datos PostgreSQL:** 
   - Se añadió el paquete `pg` al servidor (`@edullm/socket`).
   - Se creó el `pgDatabase.ts` para gestionar el pool de conexiones hacia `edu_llm` local.
2. **Repositorio de estudiantes y Controller:**
   - Se expuso el endpoint `POST /api/students/login`.
   - El controlador interactúa con `comun.fn_login` (Stored Function) para validar credenciales delegando la seguridad a la base de datos y manteniendo la validación de contraseñas de formato *scrypt*.
3. **Frontend: Gestión del estado stateful (`player.tsx`):**
   - El store global de Zustand ahora guarda el `idEstudiante`.
   - Se añadió la página `StudentLoginPage` bajo la ruta `/login`.
   - Si un estudiante está logueado y provee un PIN válido en `/`, se une automáticamente a la partida omitiendo la pantalla de ingresar el *username* (flujo sin interrupciones).
4. **Proxy de Vite:**
   - Se añadió el enrutamiento al backend local bajo la ruta proxy `/api` en `vite.config.ts`.

## ¿Por qué se cambió?

El requerimiento principal era implementar la persistencia y login para los estudiantes sin modificar o romper el estado en vivo del juego (`Game`).

Para llevar un control adecuado a lo largo del tiempo de los estudiantes recurrentes y poder vincular sus progresos (ya que luego se conectará la persistencia post-partida a Postgres), es vital mantener la autenticación separada de la "sesión anónima temporal" que provee Socket.IO.

Este cambio obedece a las indicaciones de que **toda la interacción de datos debe utilizar procedimientos almacenados** y **la comunicación de BBDD no maneja SQL crudo**. Así, se consumen eficientemente las funciones y se mantiene el diseño de la aplicación.
