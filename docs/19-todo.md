# 19 - Tareas Pendientes (ToDo General)

Este documento centraliza todas las tareas, ideas y planes de implementación a futuro para la plataforma, organizado como una bitácora y especificación técnica.

## 1. Autenticación de Estudiantes e Historial

- [ ] **Capa de Base de Datos**
  - [ ] Crear una nueva tabla `students` para almacenar la información de los estudiantes. Esta tabla incluir campos como `id` (UUID), `manager_id` (FOREIGN KEY a `managers`), `username`, `first_name`, `last_name`, `password_hash`, `external_id`, `created_at`, `updated_at`.
    - **💡 Propósito:** Permitir que los estudiantes tengan una identidad propia en el sistema para poder loguearse y guardar su progreso.
  - [ ] Crear una tabla de relación `manager_students` (si la relación es 1:N y un estudiante pertenece exclusivamente a un manager, el `manager_id` en la tabla `students` sería suficiente).
    - **💡 Propósito:** Cumplir el requerimiento de que cada estudiante tenga un manager (profesor) asignado, permitiendo al profesor ver exclusivamente a sus alumnos.
  - [ ] Añadir `student_id` como columna referencial (nullable) al esquema de historiales `quiz_runs` y a la tabla de respuestas individuales dentro del `payload_json` de `quiz_runs`.
    - **💡 Propósito:** Poder identificar qué estudiante en particular respondió el cuestionario para mostrar su nombre en el historial.
  - **📍 Archivos Afectados:** `packages/socket/src/services/database.ts`
  - **⚠️ Impacto:** Modificación del esquema principal de SQLite. Una mala sintaxis corromperá el inicio y causará que otros servicios base fallen.
  - **🧪 Pruebas:** Eliminar el archivo de base de datos local y dejar que arranque desde cero; verificar en un visor SQLite que las nuevas tablas y columnas aparezcan.

- [ ] **Servicio de Gestión de Estudiantes (`StudentStore`)**
  - [ ] Crear un nuevo servicio `StudentStore` (similar a `AccountStore` para managers) que encapsule la lógica CRUD para la tabla `students`.
    - **💡 Propósito:** Tener un lugar centralizado en el código para crear, listar, editar o eliminar estudiantes.
  - [ ] Implementar métodos para `listStudents(managerId)`, `createStudent(managerId, studentData)`, `getStudentById(studentId)`, `updateStudent(studentId, studentData)`, `deleteStudent(studentId)`, `updatePassword(studentId, newPassword)`.
    - **💡 Propósito:** Darle las herramientas al backend para que el profesor pueda gestionar la lista de sus alumnos y que los alumnos puedan cambiar su propia contraseña.
  - [ ] Si se requiere autenticación de estudiantes, implementar `authenticateStudent(username, password)` y `getStudentByExternalId(externalId)`.
    - **💡 Propósito:** Habilitar el proceso seguro de inicio de sesión para los estudiantes.
  - **📍 Archivos Afectados:** Nuevo archivo `packages/socket/src/services/studentStore.ts`, `packages/socket/src/index.ts`.
  - **⚠️ Impacto:** Introducción de una nueva capa de lógica de negocio.
  - **🧪 Pruebas:** Pruebas unitarias para cada método CRUD y de autenticación del `StudentStore`.

- [ ] **Configuración e Ingesta Inicial**
  - [ ] Añadir una característica de configuración, por ejemplo, `requireStudentLogin`, en `config/game.json` para controlar si los estudiantes deben autenticarse.
    - **💡 Propósito:** Que el login de los estudiantes sea opcional, mediante una bandera que indica si es necesario loguearse para participar en un juego.
  - [ ] Implementar un mecanismo para cargar estudiantes desde un archivo JSON hacia la nueva tabla `students` en la base de datos.
    - **💡 Propósito:** Facilitar la carga masiva inicial de estudiantes si ya se cuenta con una lista preexistente.
  - **📍 Archivos Afectados:** `packages/socket/src/services/config.ts`, `packages/socket/src/services/accountStore.ts`.
  - **⚠️ Impacto:** Modifica la validación estricta Zod en el arranque.
  - **🧪 Pruebas:** Modificar `config/game.json` manualmente a `true` y `false`.

- [ ] **WebSocket y Lógica de Autenticación/Juego**
  - [ ] Crear nuevos eventos WebSocket para la gestión de estudiantes por parte del manager (ej. `manager:listStudents`, `manager:createStudent`, `manager:deleteStudent`).
    - **💡 Propósito:** Permitir que la interfaz del profesor se comunique en tiempo real con el servidor para administrar a sus estudiantes (creación por parte del profesor).
  - [ ] Crear eventos `player:auth` o `player:loginStudent` y `player:updatePassword` para que los estudiantes se autentiquen y gestionen su seguridad.
    - **💡 Propósito:** Habilitar el canal para que el alumno envíe sus credenciales y pueda modificar su contraseña por su cuenta.
  - [ ] Modificar el evento `player:join` y la lógica en `services/game.ts` para que, si la configuración exige login de estudiantes, se valide la autenticación del estudiante antes de permitirle unirse a la partida.
    - **💡 Propósito:** Bloquear el acceso a usuarios no identificados cuando el login obligatorio esté activado (Seguridad Web Básica).
  - [ ] Asegurar que el `student_id` del estudiante autenticado se asocie a su `Player` en la instancia `Game` y que su nombre real se use para los registros, permitiendo un nickname diferente en pantalla.
    - **💡 Propósito:** Garantizar que en el historial se use el nombre registrado, mientras que en el juego se pueda usar un apodo personalizado si se desea.
  - **📍 Archivos Afectados:** `packages/socket/src/index.ts`, `packages/socket/src/services/game.ts`, `packages/common/src/types/game/socket.ts`.
  - **⚠️ Impacto:** Afecta directamente el flujo de unirse a una partida (`14-game-flow.md`). Posible bloqueo de jugadores legítimos.
  - **🧪 Pruebas:** Lanzar una partida de prueba. Intentar unirse forzando la negación; asegurar que la conexión envíe un `"errorMessage"`.

- [ ] **Historial y Reportes (CSV)**
  - [ ] Modificar la lógica de `Game.persistHistory()` para que, al guardar una partida, se almacene el `student_id` real en el `payload_json` de `quiz_runs`.
    - **💡 Propósito:** Guardar permanentemente la participación del alumno registrado en la base de datos.
  - [ ] Modificar `History.exportCsv()` para que, al generar el CSV, pueda incluir información adicional del estudiante (ej. nombre completo, ID externo) obteniéndola de la tabla `students` mediante un `JOIN` SQL.
    - **💡 Propósito:** Que en el historial se vea el nombre del estudiante, en lugar de solo un apodo temporal.
  - **📍 Archivos Afectados:** `packages/socket/src/services/game.ts`, `packages/socket/src/services/history.ts`.
  - **⚠️ Impacto:** Modifica la lectura y visualización directa de los maestros.
  - **🧪 Pruebas:** Descargar el CSV desde la UI de un manager y verificar que las columnas nuevas salgan correctamente tabuladas.

- [ ] **Frontend & UI (Manejo de Interfaces)**
  - [ ] **Interfaz de Jugador:** Modificar la interfaz de pre-ingreso del jugador para que, si `requireStudentLogin` está activo, se pida un identificador de estudiante y contraseña.
    - **💡 Propósito:** Crear el formulario donde el estudiante se podrá loguear.
  - [ ] **Interfaz de Manager/Admin:** Crear un nuevo componente de panel para la gestión de estudiantes dentro de `packages/web/src/features/game/components/create/`.
    - **💡 Propósito:** Darle al profesor una vista donde pueda ver su lista de estudiantes asignados y gestionarlos.
  - [ ] Integrar el nuevo panel de estudiantes en el dashboard del manager (`packages/web/src/pages/game/auth/manager/page.tsx`) como una nueva pestaña.
    - **💡 Propósito:** Facilitar al profesor el acceso a la sección de estudiantes desde su panel principal.
  - **📍 Archivos Afectados:** `packages/web/src/pages/game/auth/page.tsx`, `packages/web/src/pages/game/auth/manager/page.tsx`.
  - **⚠️ Impacto:** La experiencia central del estudiante y del manager.
  - **🧪 Pruebas:** Navegar al frontend simulando un estudiante; correr ambas vías globales y asegurar la renderización.

---

## 2. Base de Conocimientos y Generación Automática

- [ ] **Repositorio de Preguntas (Ciencias Naturales)**
  - [ ] Crear una base de datos de conocimiento inicial para la materia de Ciencias Naturales, organizada por temas y subtemas.
    - **💡 Propósito:** Servir como fuente de datos para la generación automática de cuestionarios.
  - [ ] Implementar un motor de selección aleatoria/inteligente de preguntas basado en un tema específico seleccionado por el profesor.
    - **💡 Propósito:** Permitir que el profesor elija un tema y el sistema cree el cuestionario automáticamente.
  - [ ] Diseñar el modelo de "Análisis de Situación" para procesar las estadísticas de los estudiantes por tema.
    - **💡 Propósito:** Ayudar al profesor a identificar qué temas requieren refuerzo basándose en el desempeño grupal e individual.
  - **📍 Archivos Afectados:** `packages/socket/src/services/knowledgeBase.ts` (nuevo), `packages/socket/src/services/quizGenerator.ts` (nuevo).
  - **⚠️ Impacto:** Requiere una curación de contenido previa y un algoritmo de selección balanceado.
  - **🧪 Pruebas:** Generar 10 cuestionarios del mismo tema y verificar que las preguntas varíen y correspondan al tema elegido.

---

---

## 3. Tutor Personalizado por Transparencia (TPT)

- [x] **Módulo de IA y Retroalimentación**
  - [x] Implementar el servicio `TutorService` para la integración con LLM (ChatGPT/OpenAI) pero implementado inicialmente con un modelo local Gemma4 E2B.
    - **💡 Propósito:** Gestionar la comunicación con la IA para generar las explicaciones de los errores.
    - **✅ Logro:** Se creó `packages/socket/src/services/tutorService.ts` que consume SSE desde el puerto 5000 y se integra con el servidor de sockets en el puerto 3001. Se creó un laboratorio de pruebas en el puerto 3002.
  - [/] Desarrollar el "Módulo Guardián" (Restricción Temática) mediante System Prompts.
    - **💡 Propósito:** Asegurar que el tutor no se desvíe del tema académico de la pregunta fallada durante la interacción libre.
    - **🚧 En progreso:** Integrando el envío de preguntas fallidas como contexto al modelo de IA.
  - [x] Crear la interfaz de Chat de Tutoría Post-Test en el frontend del estudiante.
    - **💡 Propósito:** Permitir al alumno interactuar con el tutor 1:1 después de ver sus resultados.
    - **✅ Logro:** Se implementó una interfaz premium de prueba en `scratch/tutor-test/index.html`.
  - **📍 Archivos Afectados:** `packages/socket/src/services/tutorService.ts` (nuevo), `packages/socket/src/index.ts` (modificado), `scratch/tutor-test/` (nuevo).
  - **⚠️ Impacto:** La comunicación es asíncrona y mediante streaming, optimizando la percepción de velocidad.
  - **🧪 Pruebas:** Verificación manual exitosa mediante el puerto 3002 enviando mensajes al modelo local.

---

## 4. Ideas futuras

- [ ] ...
