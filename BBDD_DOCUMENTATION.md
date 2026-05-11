# Documentación de la Base de Datos (`edu_llm`)

Este documento describe la estructura y uso de la base de datos PostgreSQL diseñada para el proyecto. Para evitar escribir consultas SQL directamente desde el backend, toda interacción de persistencia debe realizarse mediante los **Procedimientos Almacenados (Stored Procedures)** y **Funciones** documentados aquí.

## 1. Esquemas (Schemas)

La base de datos se divide en cuatro esquemas principales para organizar lógicamente los permisos y el dominio:

- `comun`: Contiene las tablas del sistema, funciones auxiliares y procedimientos generales como el login.
- `admin`: Contiene los procedimientos exclusivos para tareas administrativas.
- `profesor`: Contiene los procedimientos operativos para profesores.
- `estudiante`: Contiene los procedimientos para el flujo de los estudiantes.

---

## 2. Estructura de Tablas (Esquema `comun`)

### Tablas Administrativas (`ADMIN_`)
Gestionan usuarios, roles, estados y periodos.

- `ADMIN_ESTADO`: Catálogo de estados genéricos (ej. `ACT` = Activo, `INA` = Inactivo). **Protegido:** El estado 'ACT' no puede ser modificado.
- `ADMIN_ROL`: Roles de usuario (`administrador`, `profesor`, `estudiante`).
- `ADMIN_USUARIO`: Tabla central de usuarios del sistema.
- `ADMIN_PERIODO_LECTIVO`: **[NUEVO]** Gestiona los períodos (ej. "2024-2025"). Incluye fechas de inicio/fin y bandera `es_activo`.

### Tablas Transaccionales e Información (`INFO_` y Relacionales)
- `INFO_MATERIA`: Catálogo de materias. **[NUEVO]** Incluye `nombre_normalizado` generado automáticamente para evitar duplicados por tildes o espacios.
- `PROFESOR_MATERIA`: Relación entre profesores y materias. **[NUEVO]** Es única por combinación de `id_profesor`, `id_materia` e `id_periodo_lectivo`.
- `INFO_PRUEBA`: Definición de un cuestionario/quiz.
- `INFO_PREGUNTA`: Preguntas individuales pertenecientes a una prueba.
- `INFO_PARTIDA`: Instancia activa de una prueba.
- `ADMIN_PARAMETRO`: **[NUEVO]** Almacena configuraciones globales del sistema (claves/valores).

---

## 3. Procedimientos Almacenados y Funciones

### Funciones Auxiliares (`comun`)

| Función | Descripción |
|---|---|
| **`comun.obtener_id_estado_activo()`** | Retorna el ID numérico del estado 'ACT'. |
| **`comun.normalizar_texto(texto)`** | Limpia espacios, recortes y convierte a minúsculas para comparaciones consistentes. |
| **`comun.parametro_guardar`** | (PROCEDURE) Crea o actualiza un parámetro global. | `Pv_clave`, `Pv_valor`, `Pv_tipo`, `Pv_descripcion`, `Pn_usuario_creacion` | `Pn_id_parametro`, `Pv_error` |
| **`comun.parametro_listar_todos`** | (FUNCTION) Lista todos los parámetros activos. | *(ninguno)* | TABLE(`id_parametro`, `clave`, `valor`, `tipo`, `descripcion`, `id_estado`) |
| **`comun.parametro_obtener`** | (FUNCTION) Obtiene un parámetro específico por su clave. | `Pv_clave` | TABLE(`id_parametro`, `clave`, `valor`, `tipo`, `descripcion`, `id_estado`) |

### Profesores (Esquema `profesor`)

| Procedimiento/Función | Tipo | IN Parameters | OUT Parameters / Retornos |
|---|---|---|---|
| **`profesor.materias_crear`** | PROCEDURE | `p_id_profesor`, `p_nombre`, `p_descripcion`, `p_id_periodo_lectivo` | `p_id_materia`, `p_error` |
| **`profesor.materias_listar`** | PROCEDURE | `Pn_id_profesor` | `refcursor`, `Pv_error` |
| **`profesor.materias_por_usuario`** | FUNCTION | `p_id_usuario INT` | TABLE(`id_materia`, `nombre`, `descripcion`, `id_estado`) |
| **`profesor.pruebas_crear`** | PROCEDURE | `p_materia`, `p_titulo`, `p_id_usuario`, `p_id_materia`, `p_configuracion` | `pn_id_prueba`, `pv_error` |
| **`profesor.pruebas_listar`** | FUNCTION | `p_id_usuario INT` | TABLE(...) - Filtra por estado 'ACT'. |
| **`profesor.pruebas_editar`** | PROCEDURE | `p_id_prueba INT`, `p_titulo TEXT`, `p_configuracion JSONB` | *(sin OUT)* |
| **`profesor.pruebas_eliminar`** | PROCEDURE | `p_id_prueba INT` | *(sin OUT)* - Marca como 'ELI'. |
| **`profesor.preguntas_agregar`** | PROCEDURE | `Pn_id_prueba`, `Pv_texto`, `Pj_opciones`, `Pn_respuesta_correcta`, `Pn_puntaje`, `Pn_tiempo_limite` | `Pn_id_pregunta`, `Pv_error` |
| **`profesor.preguntas_listar`** | FUNCTION | `p_id_prueba INT` | TABLE(...) - Filtra por estado 'ACT'. |
| **`profesor.preguntas_eliminar`** | PROCEDURE | `p_id_prueba INT` | *(sin OUT)* - Marca como 'ELI'. |
| **`profesor.partidas_iniciar`** | PROCEDURE | `Pn_id_prueba`, `Pn_id_profesor` | `Pn_id_partida`, `Pv_codigo_acceso`, `Pv_error` |

---

## 4. Lógica de Normalización de Materias
El sistema ahora impide que se creen materias con nombres similares (ej. "Matemática" y "matematica ").
1. Se utiliza un trigger `trg_materia_normalizar` en la tabla `INFO_MATERIA`.
2. Se mantiene un índice único `idx_materia_nombre_normalizado`.
3. El procedimiento `profesor.materias_crear` verifica si la materia ya existe y, si es así, simplemente crea la relación con el profesor para el período lectivo actual en lugar de duplicar la materia.
