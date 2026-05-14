--
-- PostgreSQL database dump
--

\restrict Vy3S7dneHiR24qYUrN8N1ozLMFtPkIq54KR6wr5mIQrq3RaLcmAXcEOhL73pkFw

-- Dumped from database version 17.9 (Debian 17.9-0+deb13u1)
-- Dumped by pg_dump version 17.9 (Debian 17.9-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: admin; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA admin;


ALTER SCHEMA admin OWNER TO admin;

--
-- Name: comun; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA comun;


ALTER SCHEMA comun OWNER TO admin;

--
-- Name: estudiante; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA estudiante;


ALTER SCHEMA estudiante OWNER TO admin;

--
-- Name: profesor; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA profesor;


ALTER SCHEMA profesor OWNER TO admin;

--
-- Name: estudiantes_listar(character varying, integer); Type: PROCEDURE; Schema: admin; Owner: admin
--

CREATE PROCEDURE admin.estudiantes_listar(IN pv_nombre_busqueda character varying, IN pn_id_estado integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT u.id_usuario, u.cedula, u.username, u.primer_nombre, u.apellido_paterno, u.apellido_materno,
           e.codigo_estudiante, e.grado, e.grupo, est.nombre AS estado_nombre
    FROM comun.ADMIN_USUARIO u
    JOIN comun.ADMIN_ESTUDIANTE e ON e.id_usuario = u.id_usuario
    JOIN comun.ADMIN_ESTADO est ON est.id_estado = u.id_estado
    WHERE (Pv_nombre_busqueda IS NULL OR 
           u.primer_nombre ILIKE '%' || Pv_nombre_busqueda || '%' OR
           u.apellido_paterno ILIKE '%' || Pv_nombre_busqueda || '%')
      AND (Pn_id_estado IS NULL OR u.id_estado = Pn_id_estado);
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE admin.estudiantes_listar(IN pv_nombre_busqueda character varying, IN pn_id_estado integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: profesores_listar(character varying, integer); Type: PROCEDURE; Schema: admin; Owner: admin
--

CREATE PROCEDURE admin.profesores_listar(IN pv_nombre_busqueda character varying, IN pn_id_estado integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT u.id_usuario, u.cedula, u.username, u.primer_nombre, u.apellido_paterno, u.apellido_materno,
           u.id_rol, e.nombre AS estado_nombre, p.departamento
    FROM comun.ADMIN_USUARIO u
    JOIN comun.ADMIN_PROFESOR p ON p.id_usuario = u.id_usuario
    JOIN comun.ADMIN_ESTADO e ON e.id_estado = u.id_estado
    WHERE (Pv_nombre_busqueda IS NULL OR 
           u.primer_nombre ILIKE '%' || Pv_nombre_busqueda || '%' OR
           u.apellido_paterno ILIKE '%' || Pv_nombre_busqueda || '%')
      AND (Pn_id_estado IS NULL OR u.id_estado = Pn_id_estado);
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE admin.profesores_listar(IN pv_nombre_busqueda character varying, IN pn_id_estado integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: usuario_cambiar_estado(integer, character varying); Type: PROCEDURE; Schema: admin; Owner: admin
--

CREATE PROCEDURE admin.usuario_cambiar_estado(IN pn_id_usuario integer, IN pv_codigo_estado character varying, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado INT;
    Ln_id_estado_actual INT;
BEGIN
    SELECT id_estado INTO Ln_id_estado FROM comun.ADMIN_ESTADO WHERE codigo = Pv_codigo_estado;
    IF NOT FOUND THEN
        Pv_error := 'Estado no válido';
        RETURN;
    END IF;

    SELECT id_estado INTO Ln_id_estado_actual FROM comun.ADMIN_USUARIO WHERE id_usuario = Pn_id_usuario;
    IF NOT FOUND THEN
        Pv_error := 'Usuario no existe';
        RETURN;
    END IF;

    UPDATE comun.ADMIN_USUARIO
    SET id_estado = Ln_id_estado,
        fecha_modificacion = NOW(),
        usuario_modificacion = Pn_id_usuario  -- se asume que quien ejecuta es el admin logueado
    WHERE id_usuario = Pn_id_usuario;

    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE admin.usuario_cambiar_estado(IN pn_id_usuario integer, IN pv_codigo_estado character varying, OUT pv_error text) OWNER TO admin;

--
-- Name: usuarios_registrar(character varying, character varying, character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: admin; Owner: admin
--

CREATE PROCEDURE admin.usuarios_registrar(IN pv_cedula character varying, IN pv_primer_nombre character varying, IN pv_apellido_paterno character varying, IN pv_password_hash character varying, IN pn_id_rol integer, IN pv_apellido_materno character varying, OUT pn_id_usuario integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Lv_username_base VARCHAR;
    Lv_username_final VARCHAR;
    Ln_sufijo INT := 1;
    Ln_existe INT;
    Ln_id_estado_activo INT;
    Ln_id_usuario INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();

    IF EXISTS (SELECT 1 FROM comun.ADMIN_USUARIO WHERE cedula = Pv_cedula) THEN
        Pv_error := 'La cédula ya está registrada';
        RETURN;
    END IF;

    Lv_username_base := LOWER(
        LEFT(Pv_primer_nombre, 1) ||
        Pv_apellido_paterno ||
        LEFT(COALESCE(Pv_apellido_materno, ''), 1)
    );
    Lv_username_final := Lv_username_base;

    LOOP
        SELECT COUNT(*) INTO Ln_existe FROM comun.ADMIN_USUARIO WHERE username = Lv_username_final;
        IF Ln_existe = 0 THEN EXIT; END IF;
        Ln_sufijo := Ln_sufijo + 1;
        Lv_username_final := Lv_username_base || Ln_sufijo::TEXT;
    END LOOP;

    INSERT INTO comun.ADMIN_USUARIO (
        cedula, username, primer_nombre, apellido_paterno, apellido_materno,
        password_hash, id_rol, id_estado, usuario_creacion, fecha_modificacion
    ) VALUES (
        Pv_cedula, Lv_username_final, Pv_primer_nombre, Pv_apellido_paterno, Pv_apellido_materno,
        Pv_password_hash, Pn_id_rol, Ln_id_estado_activo,
        NULL, NULL
    ) RETURNING id_usuario INTO Ln_id_usuario;

    UPDATE comun.ADMIN_USUARIO SET usuario_creacion = Ln_id_usuario WHERE id_usuario = Ln_id_usuario;

    CASE Pn_id_rol
        WHEN (SELECT id_rol FROM comun.ADMIN_ROL WHERE nombre = 'estudiante') THEN
            INSERT INTO comun.ADMIN_ESTUDIANTE (id_usuario, id_estado, usuario_creacion)
            VALUES (Ln_id_usuario, Ln_id_estado_activo, Ln_id_usuario);
        WHEN (SELECT id_rol FROM comun.ADMIN_ROL WHERE nombre = 'profesor') THEN
            INSERT INTO comun.ADMIN_PROFESOR (id_usuario, id_estado, usuario_creacion)
            VALUES (Ln_id_usuario, Ln_id_estado_activo, Ln_id_usuario);
        WHEN (SELECT id_rol FROM comun.ADMIN_ROL WHERE nombre = 'administrador') THEN
            INSERT INTO comun.ADMIN_ADMINISTRADOR (id_usuario, id_estado, usuario_creacion)
            VALUES (Ln_id_usuario, Ln_id_estado_activo, Ln_id_usuario);
        ELSE
            Pv_error := 'Rol no válido';
            RETURN;
    END CASE;

    Pn_id_usuario := Ln_id_usuario;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pn_id_usuario := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE admin.usuarios_registrar(IN pv_cedula character varying, IN pv_primer_nombre character varying, IN pv_apellido_paterno character varying, IN pv_password_hash character varying, IN pn_id_rol integer, IN pv_apellido_materno character varying, OUT pn_id_usuario integer, OUT pv_error text) OWNER TO admin;

--
-- Name: fn_login(character varying); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.fn_login(pv_username character varying) RETURNS TABLE(id_usuario integer, password_hash character varying, id_rol integer, primer_nombre character varying, apellido_paterno character varying, apellido_materno character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT u.id_usuario, u.password_hash, u.id_rol,
           u.primer_nombre, u.apellido_paterno, u.apellido_materno
    FROM comun.ADMIN_USUARIO u
    WHERE u.username = pv_username
      AND u.id_estado = comun.obtener_id_estado_activo();
END;
$$;


ALTER FUNCTION comun.fn_login(pv_username character varying) OWNER TO admin;

--
-- Name: normalizar_texto(text); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.normalizar_texto(texto text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN lower(trim(regexp_replace(texto, '\s+', ' ', 'g')));
END;
$$;


ALTER FUNCTION comun.normalizar_texto(texto text) OWNER TO admin;

--
-- Name: obtener_id_estado_activo(); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.obtener_id_estado_activo() RETURNS integer
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
    SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ACT';
$$;


ALTER FUNCTION comun.obtener_id_estado_activo() OWNER TO admin;

--
-- Name: parametro_guardar(character varying, text, character varying, text, integer); Type: PROCEDURE; Schema: comun; Owner: admin
--

CREATE PROCEDURE comun.parametro_guardar(IN pv_clave character varying, IN pv_valor text, IN pv_tipo character varying, IN pv_descripcion text, IN pn_usuario_creacion integer, OUT pn_id_parametro integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado_activo INT;
    Ln_existente_id INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();
    
    -- Verificar si ya existe un parámetro activo con esa clave
    SELECT id_parametro INTO Ln_existente_id
    FROM comun.ADMIN_PARAMETRO
    WHERE clave = Pv_clave
      AND id_estado = Ln_id_estado_activo
    LIMIT 1;
    
    IF Ln_existente_id IS NOT NULL THEN
        -- Actualizar existente
        UPDATE comun.ADMIN_PARAMETRO
        SET valor = Pv_valor,
            tipo = COALESCE(Pv_tipo, tipo),
            descripcion = COALESCE(Pv_descripcion, descripcion),
            fecha_modificacion = NOW(),
            usuario_modificacion = Pn_usuario_creacion
        WHERE id_parametro = Ln_existente_id;
        
        Pn_id_parametro := Ln_existente_id;
    ELSE
        -- Insertar nuevo
        INSERT INTO comun.ADMIN_PARAMETRO (
            clave, valor, tipo, descripcion,
            id_estado, usuario_creacion, fecha_modificacion
        ) VALUES (
            Pv_clave, Pv_valor, COALESCE(Pv_tipo, 'string'), Pv_descripcion,
            Ln_id_estado_activo, Pn_usuario_creacion, NULL
        ) RETURNING id_parametro INTO Pn_id_parametro;
    END IF;
    
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pn_id_parametro := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE comun.parametro_guardar(IN pv_clave character varying, IN pv_valor text, IN pv_tipo character varying, IN pv_descripcion text, IN pn_usuario_creacion integer, OUT pn_id_parametro integer, OUT pv_error text) OWNER TO admin;

--
-- Name: parametro_listar_todos(); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.parametro_listar_todos() RETURNS TABLE(id_parametro integer, clave character varying, valor text, tipo character varying, descripcion text, id_estado integer)
    LANGUAGE sql
    AS $$
    SELECT id_parametro, clave, valor, tipo, descripcion, id_estado
    FROM comun.ADMIN_PARAMETRO
    WHERE id_estado = comun.obtener_id_estado_activo()
    ORDER BY clave;
$$;


ALTER FUNCTION comun.parametro_listar_todos() OWNER TO admin;

--
-- Name: parametro_obtener(character varying); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.parametro_obtener(pv_clave character varying) RETURNS TABLE(id_parametro integer, clave character varying, valor text, tipo character varying, descripcion text, id_estado integer)
    LANGUAGE sql
    AS $$
    SELECT id_parametro, clave, valor, tipo, descripcion, id_estado
    FROM comun.ADMIN_PARAMETRO
    WHERE clave = Pv_clave
      AND id_estado = comun.obtener_id_estado_activo()
    LIMIT 1;
$$;


ALTER FUNCTION comun.parametro_obtener(pv_clave character varying) OWNER TO admin;

--
-- Name: parametros_listar(); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.parametros_listar() RETURNS TABLE(id_parametro integer, clave character varying, valor text, tipo character varying, descripcion text, id_estado integer)
    LANGUAGE sql
    AS $$
    SELECT id_parametro, clave, valor, tipo, descripcion, id_estado
    FROM comun.ADMIN_PARAMETRO
    WHERE id_estado = comun.obtener_id_estado_activo()
    ORDER BY clave;
$$;


ALTER FUNCTION comun.parametros_listar() OWNER TO admin;

--
-- Name: trg_materia_normalizar(); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.trg_materia_normalizar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.nombre_normalizado := comun.normalizar_texto(NEW.nombre);
    RETURN NEW;
END;
$$;


ALTER FUNCTION comun.trg_materia_normalizar() OWNER TO admin;

--
-- Name: trg_proteger_estado_activo(); Type: FUNCTION; Schema: comun; Owner: admin
--

CREATE FUNCTION comun.trg_proteger_estado_activo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si se intenta cambiar el id_estado de la fila con codigo = 'ACT'
    IF OLD.codigo = 'ACT' AND (OLD.id_estado != NEW.id_estado) THEN
        RAISE EXCEPTION 'No se puede modificar el id_estado del estado activo (ACT)';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION comun.trg_proteger_estado_activo() OWNER TO admin;

--
-- Name: usuarios_obtener(character varying); Type: PROCEDURE; Schema: comun; Owner: admin
--

CREATE PROCEDURE comun.usuarios_obtener(IN pv_username character varying, OUT pn_id_usuario integer, OUT pv_password_hash character varying, OUT pn_id_rol integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT u.id_usuario, u.password_hash, u.id_rol
    INTO Pn_id_usuario, Pv_password_hash, Pn_id_rol
    FROM comun.ADMIN_USUARIO u
    WHERE u.username = Pv_username
      AND u.id_estado = comun.obtener_id_estado_activo();

    IF NOT FOUND THEN
        Pn_id_usuario := 0;
        Pv_password_hash := NULL;
        Pn_id_rol := NULL;
        Pv_error := 'Usuario no encontrado o inactivo';
    ELSE
        Pv_error := NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN
    Pn_id_usuario := 0;
    Pv_password_hash := NULL;
    Pn_id_rol := NULL;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE comun.usuarios_obtener(IN pv_username character varying, OUT pn_id_usuario integer, OUT pv_password_hash character varying, OUT pn_id_rol integer, OUT pv_error text) OWNER TO admin;

--
-- Name: feedback_guardar(integer, jsonb, text, text, character varying); Type: PROCEDURE; Schema: estudiante; Owner: admin
--

CREATE PROCEDURE estudiante.feedback_guardar(IN pn_id_partida_estudiante integer, IN pj_preguntas_falladas jsonb, IN pv_prompt_enviado text, IN pv_respuesta_llm text, IN pv_modelo_usado character varying, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_usuario_estudiante INT;
BEGIN
    SELECT u.id_usuario INTO Ln_id_usuario_estudiante
    FROM comun.INFO_PARTIDA_ESTUDIANTE pe
    JOIN comun.ADMIN_ESTUDIANTE e ON e.id_estudiante = pe.id_estudiante
    JOIN comun.ADMIN_USUARIO u ON u.id_usuario = e.id_usuario
    WHERE pe.id_partida_estudiante = Pn_id_partida_estudiante;

    INSERT INTO comun.INFO_RETROALIMENTACION_LLM (
        id_partida_estudiante, preguntas_falladas, prompt_enviado,
        respuesta_llm, modelo_usado, usuario_creacion
    ) VALUES (
        Pn_id_partida_estudiante, Pj_preguntas_falladas, Pv_prompt_enviado,
        Pv_respuesta_llm, Pv_modelo_usado, Ln_id_usuario_estudiante
    );

    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE estudiante.feedback_guardar(IN pn_id_partida_estudiante integer, IN pj_preguntas_falladas jsonb, IN pv_prompt_enviado text, IN pv_respuesta_llm text, IN pv_modelo_usado character varying, OUT pv_error text) OWNER TO admin;

--
-- Name: mis_partidas(integer); Type: PROCEDURE; Schema: estudiante; Owner: admin
--

CREATE PROCEDURE estudiante.mis_partidas(IN pn_id_estudiante integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT 
        p.id_partida,
        p.codigo_acceso,
        pr.titulo AS nombre_prueba,
        m.nombre AS materia,
        pe.puntaje_total,
        pe.respuestas_correctas,
        (SELECT COUNT(*) FROM comun.INFO_PREGUNTA WHERE id_prueba = pr.id_prueba) AS total_preguntas,
        p.finalizado_en,
        f.respuesta_llm AS feedback
    FROM comun.INFO_PARTIDA_ESTUDIANTE pe
    JOIN comun.INFO_PARTIDA p ON p.id_partida = pe.id_partida
    JOIN comun.INFO_PRUEBA pr ON pr.id_prueba = p.id_prueba
    JOIN comun.INFO_MATERIA m ON m.id_materia = pr.id_materia
    LEFT JOIN comun.INFO_RETROALIMENTACION_LLM f ON f.id_partida_estudiante = pe.id_partida_estudiante
    WHERE pe.id_estudiante = Pn_id_estudiante
      AND p.estado_partida = 'finalizada'
    ORDER BY p.finalizado_en DESC;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE estudiante.mis_partidas(IN pn_id_estudiante integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: partidas_unirse(character varying, integer, character varying); Type: PROCEDURE; Schema: estudiante; Owner: admin
--

CREATE PROCEDURE estudiante.partidas_unirse(IN pv_codigo_acceso character varying, IN pn_id_estudiante integer, IN pv_nickname_opcional character varying, OUT pn_id_partida integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_partida INT;
    Lv_estado_partida VARCHAR;
    Ln_id_estado_activo INT;
    Ln_id_usuario_creador INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();

    SELECT id_partida, estado_partida
    INTO Ln_id_partida, Lv_estado_partida
    FROM comun.INFO_PARTIDA
    WHERE codigo_acceso = Pv_codigo_acceso
      AND id_estado = Ln_id_estado_activo;

    IF Ln_id_partida IS NULL THEN
        Pv_error := 'Código de partida inválido';
        RETURN;
    END IF;

    IF Lv_estado_partida != 'esperando' THEN
        Pv_error := 'La partida ya comenzó o finalizó';
        RETURN;
    END IF;

    SELECT id_usuario INTO Ln_id_usuario_creador
    FROM comun.ADMIN_ESTUDIANTE WHERE id_estudiante = Pn_id_estudiante;

    INSERT INTO comun.INFO_PARTIDA_ESTUDIANTE (
        id_partida, id_estudiante, nickname_opcional,
        id_estado, usuario_creacion, fecha_modificacion
    ) VALUES (
        Ln_id_partida, Pn_id_estudiante, COALESCE(Pv_nickname_opcional, ''),
        Ln_id_estado_activo, Ln_id_usuario_creador, NULL
    ) ON CONFLICT (id_partida, id_estudiante) DO NOTHING;

    Pn_id_partida := Ln_id_partida;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pn_id_partida := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE estudiante.partidas_unirse(IN pv_codigo_acceso character varying, IN pn_id_estudiante integer, IN pv_nickname_opcional character varying, OUT pn_id_partida integer, OUT pv_error text) OWNER TO admin;

--
-- Name: respuestas_registrar(character varying, integer, integer, integer, integer); Type: PROCEDURE; Schema: estudiante; Owner: admin
--

CREATE PROCEDURE estudiante.respuestas_registrar(IN pv_codigo_acceso character varying, IN pn_id_estudiante integer, IN pn_id_pregunta integer, IN pn_id_opcion_seleccionada integer, IN pn_tiempo_ms integer, OUT pb_exito boolean, OUT pn_puntaje_obtenido integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_partida_estudiante INT;
    Lb_es_correcta BOOLEAN;
    Ln_puntaje_base INT;
    Ln_tiempo_limite INT;
    Ln_puntaje_calculado INT;
    Ln_id_estado_activo INT;
    Ln_id_usuario_estudiante INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();

    -- Obtener información de la partida y el estudiante (como antes)
    SELECT pe.id_partida_estudiante, u.id_usuario
    INTO Ln_id_partida_estudiante, Ln_id_usuario_estudiante
    FROM comun.INFO_PARTIDA_ESTUDIANTE pe
    JOIN comun.INFO_PARTIDA p ON p.id_partida = pe.id_partida
    JOIN comun.ADMIN_ESTUDIANTE e ON e.id_estudiante = pe.id_estudiante
    JOIN comun.ADMIN_USUARIO u ON u.id_usuario = e.id_usuario
    WHERE p.codigo_acceso = Pv_codigo_acceso
      AND pe.id_estudiante = Pn_id_estudiante
      AND pe.id_estado = Ln_id_estado_activo;

    IF NOT FOUND THEN
        Pb_exito := FALSE;
        Pn_puntaje_obtenido := 0;
        Pv_error := 'Estudiante no pertenece a esta partida o no existe';
        RETURN;
    END IF;

    -- Obtener si la opción es correcta, el puntaje y tiempo límite de la pregunta
    SELECT op.es_correcta, pr.puntaje, pr.tiempo_limite
    INTO Lb_es_correcta, Ln_puntaje_base, Ln_tiempo_limite
    FROM comun.INFO_PREGUNTA pr
    JOIN comun.INFO_OPCION op ON op.id_pregunta = pr.id_pregunta
    WHERE pr.id_pregunta = Pn_id_pregunta
      AND op.id_opcion = Pn_id_opcion_seleccionada;

    IF NOT FOUND THEN
        Pb_exito := FALSE;
        Pn_puntaje_obtenido := 0;
        Pv_error := 'Opción no válida para esta pregunta';
        RETURN;
    END IF;

    -- Calcular puntaje
    IF Lb_es_correcta THEN
        Ln_puntaje_calculado := GREATEST(
            ROUND(Ln_puntaje_base * (1.0 - LEAST(Pn_tiempo_ms::NUMERIC / (Ln_tiempo_limite * 1000), 0.8))),
            Ln_puntaje_base * 0.2
        );
    ELSE
        Ln_puntaje_calculado := 0;
    END IF;

    -- Insertar respuesta (sin es_correcta porque está implícita)
    INSERT INTO comun.INFO_RESPUESTA (
        id_partida_estudiante, id_pregunta, id_opcion_seleccionada,
        tiempo_ms, puntaje_obtenido,
        usuario_creacion, fecha_modificacion
    ) VALUES (
        Ln_id_partida_estudiante, Pn_id_pregunta, Pn_id_opcion_seleccionada,
        Pn_tiempo_ms, Ln_puntaje_calculado,
        Ln_id_usuario_estudiante, NULL
    );

    -- Actualizar puntaje total del estudiante en la partida
    UPDATE comun.INFO_PARTIDA_ESTUDIANTE
    SET puntaje_total = puntaje_total + Ln_puntaje_calculado,
        respuestas_correctas = respuestas_correctas + (Lb_es_correcta::INT),
        fecha_modificacion = NOW(),
        usuario_modificacion = Ln_id_usuario_estudiante
    WHERE id_partida_estudiante = Ln_id_partida_estudiante;

    Pb_exito := TRUE;
    Pn_puntaje_obtenido := Ln_puntaje_calculado;
    Pv_error := NULL;

EXCEPTION WHEN OTHERS THEN
    Pb_exito := FALSE;
    Pn_puntaje_obtenido := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE estudiante.respuestas_registrar(IN pv_codigo_acceso character varying, IN pn_id_estudiante integer, IN pn_id_pregunta integer, IN pn_id_opcion_seleccionada integer, IN pn_tiempo_ms integer, OUT pb_exito boolean, OUT pn_puntaje_obtenido integer, OUT pv_error text) OWNER TO admin;

--
-- Name: estudiante_respuestas_partida(integer, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.estudiante_respuestas_partida(IN pn_id_partida integer, IN pn_id_estudiante integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT 
        q.id_pregunta,
        q.texto AS pregunta,
        (SELECT jsonb_agg(op.texto ORDER BY op.orden) FROM comun.INFO_OPCION op WHERE op.id_pregunta = q.id_pregunta AND op.id_estado = comun.obtener_id_estado_activo()) AS opciones,
        (SELECT op.orden FROM comun.INFO_OPCION op WHERE op.id_pregunta = q.id_pregunta AND op.es_correcta = true LIMIT 1) AS respuesta_correcta,
        r.id_opcion_seleccionada,
        EXISTS (SELECT 1 FROM comun.INFO_OPCION op WHERE op.id_opcion = r.id_opcion_seleccionada AND op.es_correcta = true) AS es_correcta,
        r.puntaje_obtenido
    FROM comun.INFO_RESPUESTA r
    JOIN comun.INFO_PREGUNTA q ON q.id_pregunta = r.id_pregunta
    JOIN comun.INFO_PARTIDA_ESTUDIANTE pe ON pe.id_partida_estudiante = r.id_partida_estudiante
    WHERE pe.id_partida = Pn_id_partida AND pe.id_estudiante = Pn_id_estudiante
    ORDER BY q.id_pregunta;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.estudiante_respuestas_partida(IN pn_id_partida integer, IN pn_id_estudiante integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: estudiantes_dificultades(integer, integer, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.estudiantes_dificultades(IN pn_id_profesor integer, IN pn_id_materia integer, IN pn_porcentaje_umbral integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT 
        e.id_estudiante,
        u.primer_nombre || ' ' || u.apellido_paterno AS nombre,
        e.codigo_estudiante,
        AVG(pe.respuestas_correctas * 100.0 / (SELECT COUNT(*) FROM comun.INFO_PREGUNTA WHERE id_prueba = p.id_prueba)) AS porcentaje_aciertos
    FROM comun.INFO_PARTIDA_ESTUDIANTE pe
    JOIN comun.INFO_PARTIDA p ON p.id_partida = pe.id_partida
    JOIN comun.INFO_PRUEBA pr ON pr.id_prueba = p.id_prueba
    JOIN comun.ADMIN_ESTUDIANTE e ON e.id_estudiante = pe.id_estudiante
    JOIN comun.ADMIN_USUARIO u ON u.id_usuario = e.id_usuario
    WHERE p.id_profesor = Pn_id_profesor
      AND pr.id_materia = Pn_id_materia
      AND p.estado_partida = 'finalizada'
    GROUP BY e.id_estudiante, u.primer_nombre, u.apellido_paterno, e.codigo_estudiante
    HAVING AVG(pe.respuestas_correctas * 100.0 / (SELECT COUNT(*) FROM comun.INFO_PREGUNTA WHERE id_prueba = p.id_prueba)) < Pn_porcentaje_umbral
    ORDER BY porcentaje_aciertos ASC;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.estudiantes_dificultades(IN pn_id_profesor integer, IN pn_id_materia integer, IN pn_porcentaje_umbral integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: materias_crear(integer, character varying, text, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.materias_crear(IN p_id_profesor integer, IN p_nombre character varying, IN p_descripcion text, IN p_id_periodo_lectivo integer, OUT p_id_materia integer, OUT p_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado_activo INT;
    v_id_usuario_creador INT;
    v_normalized_name TEXT;
    v_existing_id INT;
BEGIN
    v_id_estado_activo := comun.obtener_id_estado_activo();
    
    SELECT id_usuario INTO v_id_usuario_creador
    FROM comun.ADMIN_PROFESOR WHERE id_profesor = p_id_profesor;

    v_normalized_name := comun.normalizar_texto(p_nombre);

    -- Buscar materia por nombre normalizado (sin importar período)
    SELECT id_materia INTO v_existing_id
    FROM comun.INFO_MATERIA
    WHERE nombre_normalizado = v_normalized_name
      AND id_estado = v_id_estado_activo
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        p_id_materia := v_existing_id;
    ELSE
        -- Crear nueva materia
        INSERT INTO comun.INFO_MATERIA (nombre, descripcion, id_estado, usuario_creacion)
        VALUES (trim(p_nombre), p_descripcion, v_id_estado_activo, v_id_usuario_creador)
        RETURNING id_materia INTO p_id_materia;
    END IF;

    -- Asignar al profesor en el período lectivo específico
    INSERT INTO comun.PROFESOR_MATERIA (id_profesor, id_materia, id_periodo_lectivo, id_estado, usuario_creacion)
    VALUES (p_id_profesor, p_id_materia, p_id_periodo_lectivo, v_id_estado_activo, v_id_usuario_creador)
    ON CONFLICT (id_profesor, id_materia, id_periodo_lectivo) DO NOTHING;

    p_error := NULL;
EXCEPTION
    WHEN OTHERS THEN
        p_id_materia := 0;
        p_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.materias_crear(IN p_id_profesor integer, IN p_nombre character varying, IN p_descripcion text, IN p_id_periodo_lectivo integer, OUT p_id_materia integer, OUT p_error text) OWNER TO admin;

--
-- Name: materias_listar(integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.materias_listar(IN pn_id_profesor integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT m.id_materia, m.nombre, m.descripcion, m.id_estado
    FROM comun.INFO_MATERIA m
    JOIN comun.PROFESOR_MATERIA pm ON pm.id_materia = m.id_materia
    WHERE pm.id_profesor = Pn_id_profesor;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.materias_listar(IN pn_id_profesor integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: materias_por_profesor(integer); Type: FUNCTION; Schema: profesor; Owner: admin
--

CREATE FUNCTION profesor.materias_por_profesor(p_id_profesor integer) RETURNS TABLE(id_materia integer, nombre character varying, descripcion text, id_estado integer)
    LANGUAGE sql
    AS $$
    SELECT m.id_materia, m.nombre, m.descripcion, m.id_estado
    FROM comun.INFO_MATERIA m
    JOIN comun.PROFESOR_MATERIA pm ON pm.id_materia = m.id_materia
    WHERE pm.id_profesor = p_id_profesor
      ;
$$;


ALTER FUNCTION profesor.materias_por_profesor(p_id_profesor integer) OWNER TO admin;

--
-- Name: materias_por_usuario(integer); Type: FUNCTION; Schema: profesor; Owner: admin
--

CREATE FUNCTION profesor.materias_por_usuario(p_id_usuario integer) RETURNS TABLE(id_materia integer, nombre character varying, descripcion text, id_estado integer)
    LANGUAGE sql
    AS $$
    SELECT m.id_materia, m.nombre, m.descripcion, m.id_estado
    FROM comun.INFO_MATERIA m
    JOIN comun.PROFESOR_MATERIA pm ON pm.id_materia = m.id_materia
    JOIN comun.ADMIN_PROFESOR ap ON ap.id_profesor = pm.id_profesor
    WHERE ap.id_usuario = p_id_usuario;
$$;


ALTER FUNCTION profesor.materias_por_usuario(p_id_usuario integer) OWNER TO admin;

--
-- Name: partida_progreso(integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.partida_progreso(IN pn_id_partida integer, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT 
        e.id_estudiante,
        u.primer_nombre || ' ' || u.apellido_paterno AS nombre_estudiante,
        pe.nickname_opcional,
        pe.puntaje_total,
        pe.respuestas_correctas,
        COUNT(r.id_respuesta) AS preguntas_respondidas,
        (SELECT COUNT(*) FROM comun.INFO_PREGUNTA WHERE id_prueba = (SELECT id_prueba FROM comun.INFO_PARTIDA WHERE id_partida = Pn_id_partida)) AS total_preguntas
    FROM comun.INFO_PARTIDA_ESTUDIANTE pe
    JOIN comun.ADMIN_ESTUDIANTE e ON e.id_estudiante = pe.id_estudiante
    JOIN comun.ADMIN_USUARIO u ON u.id_usuario = e.id_usuario
    LEFT JOIN comun.INFO_RESPUESTA r ON r.id_partida_estudiante = pe.id_partida_estudiante
    WHERE pe.id_partida = Pn_id_partida
      AND pe.id_estado = comun.obtener_id_estado_activo()
    GROUP BY e.id_estudiante, u.primer_nombre, u.apellido_paterno, pe.nickname_opcional, pe.puntaje_total, pe.respuestas_correctas
    ORDER BY pe.puntaje_total DESC;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.partida_progreso(IN pn_id_partida integer, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: partidas_finalizar(integer, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.partidas_finalizar(IN pn_id_partida integer, IN pn_id_profesor integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_profesor_valido INT;
    Ln_id_usuario_modificador INT;
BEGIN
    SELECT COUNT(*) INTO Ln_profesor_valido
    FROM comun.INFO_PARTIDA
    WHERE id_partida = Pn_id_partida AND id_profesor = Pn_id_profesor;

    IF Ln_profesor_valido = 0 THEN
        Pv_error := 'No autorizado para finalizar esta partida';
        RETURN;
    END IF;

    SELECT id_usuario INTO Ln_id_usuario_modificador
    FROM comun.ADMIN_PROFESOR WHERE id_profesor = Pn_id_profesor;

    UPDATE comun.INFO_PARTIDA
    SET estado_partida = 'Finalizado',
        finalizado_en = NOW(),
        fecha_modificacion = NOW(),
        usuario_modificacion = Ln_id_usuario_modificador
    WHERE id_partida = Pn_id_partida;

    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.partidas_finalizar(IN pn_id_partida integer, IN pn_id_profesor integer, OUT pv_error text) OWNER TO admin;

--
-- Name: partidas_finalizar_completo(integer, jsonb); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.partidas_finalizar_completo(IN pn_id_partida integer, IN pj_datos_finales jsonb, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado_activo INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();

    -- 1. Actualizar cabecera de la partida
    UPDATE comun.INFO_PARTIDA
    SET estado_partida = 'Finalizado',
        finalizado_en = NOW(),
        fecha_modificacion = NOW()
    WHERE id_partida = pn_id_partida;

    -- 2. Insertar/actualizar estudiantes en la partida
    INSERT INTO comun.INFO_PARTIDA_ESTUDIANTE (
        id_partida, id_estudiante, nickname_opcional, puntaje_total, respuestas_correctas, id_estado, usuario_creacion
    )
    SELECT 
        pn_id_partida, 
        ae.id_estudiante, 
        (elem->>'username'), 
        (elem->>'points')::INT, 
        (elem->>'correctAnswers')::INT,
        Ln_id_estado_activo,
        (elem->>'idUsuario')::INT
    FROM jsonb_array_elements(pj_datos_finales->'leaderboard') AS elem
    JOIN comun.ADMIN_ESTUDIANTE ae ON ae.id_usuario = (elem->>'idUsuario')::INT
    ON CONFLICT (id_partida, id_estudiante) DO UPDATE 
    SET puntaje_total = EXCLUDED.puntaje_total, 
        respuestas_correctas = EXCLUDED.respuestas_correctas,
        nickname_opcional = EXCLUDED.nickname_opcional;

    -- 3. Insertar respuestas individuales usando id_opcion_seleccionada
    INSERT INTO comun.INFO_RESPUESTA (
        id_partida_estudiante, id_pregunta, id_opcion_seleccionada, tiempo_ms, puntaje_obtenido, usuario_creacion
    )
    SELECT 
        ipe.id_partida_estudiante,
        (q->>'idPregunta')::INT,
        op.id_opcion,   -- <-- se obtiene de INFO_OPCION
        (r->>'time')::INT,
        (r->>'points')::INT,
        (r->>'idUsuario')::INT
    FROM jsonb_array_elements(pj_datos_finales->'questions') AS q
    CROSS JOIN jsonb_array_elements(q->'responses') AS r
    JOIN comun.ADMIN_ESTUDIANTE ae ON ae.id_usuario = (r->>'idUsuario')::INT
    JOIN comun.INFO_PARTIDA_ESTUDIANTE ipe ON ipe.id_estudiante = ae.id_estudiante AND ipe.id_partida = pn_id_partida
    JOIN comun.INFO_OPCION op ON op.id_pregunta = (q->>'idPregunta')::INT 
                             AND op.orden = (r->>'answerId')::INT   -- mapeo directo (ambos 0-based)
    WHERE op.id_estado = Ln_id_estado_activo;

EXCEPTION WHEN OTHERS THEN
    pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.partidas_finalizar_completo(IN pn_id_partida integer, IN pj_datos_finales jsonb, OUT pv_error text) OWNER TO admin;

--
-- Name: partidas_historial(integer, integer, timestamp with time zone, timestamp with time zone); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.partidas_historial(IN pn_id_profesor integer, IN pn_id_materia integer, IN pd_desde timestamp with time zone, IN pd_hasta timestamp with time zone, OUT refcursor refcursor, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN refcursor FOR
    SELECT 
        p.id_partida,
        p.codigo_acceso,
        p.estado_partida,
        p.iniciado_en,
        p.finalizado_en,
        pr.titulo AS nombre_prueba,
        m.nombre AS materia,
        COUNT(DISTINCT pe.id_estudiante) AS total_estudiantes,
        AVG(pe.puntaje_total) AS promedio_puntaje
    FROM comun.INFO_PARTIDA p
    JOIN comun.INFO_PRUEBA pr ON pr.id_prueba = p.id_prueba
    JOIN comun.INFO_MATERIA m ON m.id_materia = pr.id_materia
    LEFT JOIN comun.INFO_PARTIDA_ESTUDIANTE pe ON pe.id_partida = p.id_partida
    WHERE p.id_profesor = Pn_id_profesor
      AND p.estado_partida = 'finalizada'
      AND (Pn_id_materia IS NULL OR pr.id_materia = Pn_id_materia)
      AND (Pd_desde IS NULL OR p.finalizado_en >= Pd_desde)
      AND (Pd_hasta IS NULL OR p.finalizado_en <= Pd_hasta)
    GROUP BY p.id_partida, pr.titulo, m.nombre
    ORDER BY p.finalizado_en DESC;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.partidas_historial(IN pn_id_profesor integer, IN pn_id_materia integer, IN pd_desde timestamp with time zone, IN pd_hasta timestamp with time zone, OUT refcursor refcursor, OUT pv_error text) OWNER TO admin;

--
-- Name: partidas_iniciar(integer, integer, character varying); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.partidas_iniciar(IN pn_id_prueba integer, IN pn_id_usuario integer, IN pv_codigo_acceso character varying, OUT pn_id_partida integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_profesor INT;
    Ln_id_estado_activo INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();
    
    -- 1. Obtener id_profesor desde id_usuario
    -- Asumo que la tabla se llama ADMIN_PROFESOR y tiene id_usuario
    SELECT id_profesor INTO Ln_id_profesor
    FROM comun.ADMIN_PROFESOR 
    WHERE id_usuario = Pn_id_usuario;
    
    IF Ln_id_profesor IS NULL THEN
        Pv_error := 'El usuario no está registrado como profesor.';
        RETURN;
    END IF;

    -- 2. Insertar la partida
    INSERT INTO comun.INFO_PARTIDA (
        id_prueba, 
        codigo_acceso, 
        id_profesor, 
        estado_partida, 
        iniciado_en, 
        id_estado,
        usuario_creacion
    ) VALUES (
        Pn_id_prueba, 
        Pv_codigo_acceso, 
        Ln_id_profesor, 
        'esperando', 
        NOW(), 
        Ln_id_estado_activo,
        Pn_id_usuario
    ) RETURNING id_partida INTO Pn_id_partida;

EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.partidas_iniciar(IN pn_id_prueba integer, IN pn_id_usuario integer, IN pv_codigo_acceso character varying, OUT pn_id_partida integer, OUT pv_error text) OWNER TO admin;

--
-- Name: pregunta_eliminar_individual(integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.pregunta_eliminar_individual(IN p_id_pregunta integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE comun.INFO_PREGUNTA 
    SET id_estado = (SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ELI')
    WHERE id_pregunta = p_id_pregunta;
END;
$$;


ALTER PROCEDURE profesor.pregunta_eliminar_individual(IN p_id_pregunta integer) OWNER TO admin;

--
-- Name: preguntas_agregar(integer, text, jsonb, integer, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.preguntas_agregar(IN pn_id_prueba integer, IN pv_texto text, IN pj_opciones jsonb, IN pn_puntaje integer, IN pn_tiempo_limite integer, OUT pn_id_pregunta integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado_activo INT;
    Ln_id_usuario_creador INT;
    Ln_nueva_pregunta INT;
    Ln_puntaje_efectivo INT;
    Ln_tiempo_efectivo INT;
    opcion JSONB;
    orden INT := 0;   -- 0-based para coincidir con answerId del frontend
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();
    Ln_puntaje_efectivo := COALESCE(Pn_puntaje, 1000);
    Ln_tiempo_efectivo := COALESCE(Pn_tiempo_limite, 30);

    SELECT u.id_usuario INTO Ln_id_usuario_creador
    FROM comun.INFO_PRUEBA p
    JOIN comun.ADMIN_PROFESOR prof ON prof.id_profesor = p.id_profesor
    JOIN comun.ADMIN_USUARIO u ON u.id_usuario = prof.id_usuario
    WHERE p.id_prueba = Pn_id_prueba;

    -- Insertar pregunta (sin opciones ni respuesta_correcta)
    INSERT INTO comun.INFO_PREGUNTA (
        id_prueba, texto, puntaje, tiempo_limite,
        id_estado, usuario_creacion, fecha_modificacion
    ) VALUES (
        Pn_id_prueba, Pv_texto, Ln_puntaje_efectivo, Ln_tiempo_efectivo,
        Ln_id_estado_activo, Ln_id_usuario_creador, NULL
    ) RETURNING id_pregunta INTO Ln_nueva_pregunta;

    -- Insertar opciones
    FOR opcion IN SELECT * FROM jsonb_array_elements(Pj_opciones)
    LOOP
        INSERT INTO comun.INFO_OPCION (
            id_pregunta, texto, orden, es_correcta, id_estado, usuario_creacion
        ) VALUES (
            Ln_nueva_pregunta,
            opcion->>'texto',
            orden,
            (opcion->>'correcta')::boolean,
            Ln_id_estado_activo,
            Ln_id_usuario_creador
        );
        orden := orden + 1;
    END LOOP;

    Pn_id_pregunta := Ln_nueva_pregunta;
    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pn_id_pregunta := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.preguntas_agregar(IN pn_id_prueba integer, IN pv_texto text, IN pj_opciones jsonb, IN pn_puntaje integer, IN pn_tiempo_limite integer, OUT pn_id_pregunta integer, OUT pv_error text) OWNER TO admin;

--
-- Name: preguntas_editar(integer, text, jsonb, integer, integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.preguntas_editar(IN pn_id_pregunta integer, IN pv_texto text, IN pj_opciones jsonb, IN pn_puntaje integer, IN pn_tiempo_limite integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    opcion JSONB;
    orden INT := 0;
BEGIN
    -- 1. Actualizar datos básicos de la pregunta
    UPDATE comun.INFO_PREGUNTA
    SET texto = Pv_texto,
        puntaje = Pn_puntaje,
        tiempo_limite = Pn_tiempo_limite,
        fecha_modificacion = NOW()
    WHERE id_pregunta = Pn_id_pregunta;

    -- 2. Para las opciones, lo más limpio es borrar las antiguas de ESTA pregunta y re-insertarlas
    -- (Ya que el orden o los textos pueden haber cambiado drásticamente)
    DELETE FROM comun.INFO_OPCION WHERE id_pregunta = Pn_id_pregunta;
    
    FOR opcion IN SELECT * FROM jsonb_array_elements(Pj_opciones)
    LOOP
        INSERT INTO comun.INFO_OPCION (
            id_pregunta, texto, orden, es_correcta, id_estado, usuario_creacion
        ) VALUES (
            Pn_id_pregunta,
            opcion->>'texto',
            orden,
            (opcion->>'correcta')::boolean,
            comun.obtener_id_estado_activo(),
            (SELECT usuario_creacion FROM comun.INFO_PREGUNTA WHERE id_pregunta = Pn_id_pregunta)
        );
        orden := orden + 1;
    END LOOP;

    Pv_error := NULL;
EXCEPTION WHEN OTHERS THEN
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.preguntas_editar(IN pn_id_pregunta integer, IN pv_texto text, IN pj_opciones jsonb, IN pn_puntaje integer, IN pn_tiempo_limite integer, OUT pv_error text) OWNER TO admin;

--
-- Name: preguntas_eliminar(integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.preguntas_eliminar(IN p_id_pregunta integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado_eliminado INT;
BEGIN
    SELECT id_estado INTO Ln_id_estado_eliminado FROM comun.ADMIN_ESTADO WHERE codigo = 'ELI';
    UPDATE comun.INFO_PREGUNTA SET id_estado = Ln_id_estado_eliminado WHERE id_pregunta = p_id_pregunta;
    UPDATE comun.INFO_OPCION SET id_estado = Ln_id_estado_eliminado WHERE id_pregunta = p_id_pregunta;
END;
$$;


ALTER PROCEDURE profesor.preguntas_eliminar(IN p_id_pregunta integer) OWNER TO admin;

--
-- Name: preguntas_listar(integer); Type: FUNCTION; Schema: profesor; Owner: admin
--

CREATE FUNCTION profesor.preguntas_listar(p_id_prueba integer) RETURNS TABLE(id_pregunta integer, texto text, opciones jsonb, respuesta_correcta integer, cooldown integer, tiempo_limite integer, image_url text, audio_url text, video_url text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ip.id_pregunta,
        ip.texto,
        COALESCE(
            (SELECT jsonb_agg(op.texto ORDER BY op.orden)
             FROM comun.INFO_OPCION op
             WHERE op.id_pregunta = ip.id_pregunta
               AND op.id_estado = comun.obtener_id_estado_activo()
            ), '[]'::jsonb
        ) AS opciones,
        (SELECT op.orden
         FROM comun.INFO_OPCION op
         WHERE op.id_pregunta = ip.id_pregunta
           AND op.es_correcta = true
           AND op.id_estado = comun.obtener_id_estado_activo()
         LIMIT 1) AS respuesta_correcta,
        ip.cooldown,
        ip.tiempo_limite,
        ip.image_url,
        ip.audio_url,
        ip.video_url
    FROM comun.INFO_PREGUNTA ip
    WHERE ip.id_prueba = p_id_prueba
      AND ip.id_estado = comun.obtener_id_estado_activo();
END;
$$;


ALTER FUNCTION profesor.preguntas_listar(p_id_prueba integer) OWNER TO admin;

--
-- Name: pruebas_crear(character varying, text, integer, integer, jsonb); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.pruebas_crear(IN pv_titulo character varying, IN pv_descripcion text, IN pn_id_usuario integer, IN pn_id_materia integer, IN pj_configuracion jsonb, OUT pn_id_prueba integer, OUT pv_error text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    Ln_id_estado_activo INT;
    Ln_id_profesor INT;
    Ln_pertenece BOOLEAN;
    Ln_nueva_prueba INT;
BEGIN
    Ln_id_estado_activo := comun.obtener_id_estado_activo();

    -- Obtener id_profesor a partir del id_usuario
    SELECT id_profesor INTO Ln_id_profesor
    FROM comun.ADMIN_PROFESOR
    WHERE id_usuario = Pn_id_usuario;

    IF NOT FOUND THEN
        Pv_error := 'El usuario no es un profesor válido';
        RETURN;
    END IF;

    -- Verificar que el profesor tiene asignada esta materia (en algún período lectivo activo)
    SELECT EXISTS (
        SELECT 1 FROM comun.PROFESOR_MATERIA
        WHERE id_profesor = Ln_id_profesor 
          AND id_materia = Pn_id_materia
          AND id_estado = Ln_id_estado_activo
    ) INTO Ln_pertenece;

    IF NOT Ln_pertenece THEN
        Pv_error := 'El profesor no tiene asignada esta materia';
        RETURN;
    END IF;

    -- Insertar la nueva prueba
    INSERT INTO comun.INFO_PRUEBA (
        titulo, descripcion, id_profesor, id_materia, configuracion,
        id_estado, usuario_creacion, fecha_modificacion
    ) VALUES (
        Pv_titulo, Pv_descripcion, Ln_id_profesor, Pn_id_materia, Pj_configuracion,
        Ln_id_estado_activo, Pn_id_usuario, NULL
    ) RETURNING id_prueba INTO Ln_nueva_prueba;

    Pn_id_prueba := Ln_nueva_prueba;
    Pv_error := NULL;

EXCEPTION WHEN OTHERS THEN
    Pn_id_prueba := 0;
    Pv_error := SQLERRM;
END;
$$;


ALTER PROCEDURE profesor.pruebas_crear(IN pv_titulo character varying, IN pv_descripcion text, IN pn_id_usuario integer, IN pn_id_materia integer, IN pj_configuracion jsonb, OUT pn_id_prueba integer, OUT pv_error text) OWNER TO admin;

--
-- Name: pruebas_editar(integer, text, jsonb); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.pruebas_editar(IN p_id_prueba integer, IN p_titulo text, IN p_configuracion jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE comun.INFO_PRUEBA 
    SET titulo = p_titulo, 
        configuracion = p_configuracion
    WHERE id_prueba = p_id_prueba;
END;
$$;


ALTER PROCEDURE profesor.pruebas_editar(IN p_id_prueba integer, IN p_titulo text, IN p_configuracion jsonb) OWNER TO admin;

--
-- Name: pruebas_eliminar(integer); Type: PROCEDURE; Schema: profesor; Owner: admin
--

CREATE PROCEDURE profesor.pruebas_eliminar(IN p_id_prueba integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE comun.INFO_PRUEBA 
    SET id_estado = (SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ELI')
    WHERE id_prueba = p_id_prueba;
END;
$$;


ALTER PROCEDURE profesor.pruebas_eliminar(IN p_id_prueba integer) OWNER TO admin;

--
-- Name: pruebas_listar(integer); Type: FUNCTION; Schema: profesor; Owner: admin
--

CREATE FUNCTION profesor.pruebas_listar(p_id_usuario integer) RETURNS TABLE(id_prueba integer, titulo character varying, nombre_materia character varying, descripcion text, configuracion jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id_prueba,
        p.titulo,
        m.nombre AS nombre_materia,
        p.descripcion,
        p.configuracion
    FROM comun.INFO_PRUEBA p
    JOIN comun.ADMIN_PROFESOR ap ON ap.id_profesor = p.id_profesor
    LEFT JOIN comun.INFO_MATERIA m ON m.id_materia = p.id_materia
    WHERE ap.id_usuario = p_id_usuario 
      AND p.id_estado = (SELECT id_estado FROM comun.ADMIN_ESTADO WHERE codigo = 'ACT');
END;
$$;


ALTER FUNCTION profesor.pruebas_listar(p_id_usuario integer) OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ln_id_profesor; Type: TABLE; Schema: admin; Owner: admin
--

CREATE TABLE admin.ln_id_profesor (
    id_profesor integer
);


ALTER TABLE admin.ln_id_profesor OWNER TO admin;

--
-- Name: admin_administrador; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_administrador (
    id_administrador integer NOT NULL,
    id_usuario integer NOT NULL,
    nivel_acceso integer DEFAULT 1,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_administrador OWNER TO admin;

--
-- Name: admin_administrador_id_administrador_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_administrador_id_administrador_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_administrador_id_administrador_seq OWNER TO admin;

--
-- Name: admin_administrador_id_administrador_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_administrador_id_administrador_seq OWNED BY comun.admin_administrador.id_administrador;


--
-- Name: admin_estado; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_estado (
    id_estado integer NOT NULL,
    codigo character varying(3) NOT NULL,
    nombre character varying(50) NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer
);


ALTER TABLE comun.admin_estado OWNER TO admin;

--
-- Name: admin_estado_id_estado_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_estado_id_estado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_estado_id_estado_seq OWNER TO admin;

--
-- Name: admin_estado_id_estado_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_estado_id_estado_seq OWNED BY comun.admin_estado.id_estado;


--
-- Name: admin_estudiante; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_estudiante (
    id_estudiante integer NOT NULL,
    id_usuario integer NOT NULL,
    codigo_estudiante character varying(50),
    grado character varying(50),
    grupo character varying(20),
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_estudiante OWNER TO admin;

--
-- Name: admin_estudiante_id_estudiante_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_estudiante_id_estudiante_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_estudiante_id_estudiante_seq OWNER TO admin;

--
-- Name: admin_estudiante_id_estudiante_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_estudiante_id_estudiante_seq OWNED BY comun.admin_estudiante.id_estudiante;


--
-- Name: admin_parametro; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_parametro (
    id_parametro integer NOT NULL,
    clave character varying(100) NOT NULL,
    valor text NOT NULL,
    tipo character varying(20) DEFAULT 'string'::character varying,
    descripcion text,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL,
    CONSTRAINT check_tipo_valido CHECK (((tipo)::text = ANY ((ARRAY['TEXT'::character varying, 'NUMERIC'::character varying, 'BOOLEAN'::character varying, 'JSON'::character varying])::text[])))
);


ALTER TABLE comun.admin_parametro OWNER TO admin;

--
-- Name: admin_parametro_id_parametro_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_parametro_id_parametro_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_parametro_id_parametro_seq OWNER TO admin;

--
-- Name: admin_parametro_id_parametro_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_parametro_id_parametro_seq OWNED BY comun.admin_parametro.id_parametro;


--
-- Name: admin_periodo_lectivo; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_periodo_lectivo (
    id_periodo_lectivo integer NOT NULL,
    nombre character varying(100) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    es_activo boolean DEFAULT false,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_periodo_lectivo OWNER TO admin;

--
-- Name: admin_periodo_lectivo_id_periodo_lectivo_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_periodo_lectivo_id_periodo_lectivo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_periodo_lectivo_id_periodo_lectivo_seq OWNER TO admin;

--
-- Name: admin_periodo_lectivo_id_periodo_lectivo_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_periodo_lectivo_id_periodo_lectivo_seq OWNED BY comun.admin_periodo_lectivo.id_periodo_lectivo;


--
-- Name: admin_profesor; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_profesor (
    id_profesor integer NOT NULL,
    id_usuario integer NOT NULL,
    departamento character varying(100),
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_profesor OWNER TO admin;

--
-- Name: admin_profesor_id_profesor_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_profesor_id_profesor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_profesor_id_profesor_seq OWNER TO admin;

--
-- Name: admin_profesor_id_profesor_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_profesor_id_profesor_seq OWNED BY comun.admin_profesor.id_profesor;


--
-- Name: admin_rol; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_rol (
    id_rol integer NOT NULL,
    nombre character varying(50) NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_rol OWNER TO admin;

--
-- Name: admin_rol_id_rol_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_rol_id_rol_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_rol_id_rol_seq OWNER TO admin;

--
-- Name: admin_rol_id_rol_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_rol_id_rol_seq OWNED BY comun.admin_rol.id_rol;


--
-- Name: admin_usuario; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.admin_usuario (
    id_usuario integer NOT NULL,
    cedula character varying(20) NOT NULL,
    username character varying(100) NOT NULL,
    primer_nombre character varying(100) NOT NULL,
    apellido_paterno character varying(100) NOT NULL,
    apellido_materno character varying(100),
    password_hash character varying(255) NOT NULL,
    id_rol integer NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.admin_usuario OWNER TO admin;

--
-- Name: admin_usuario_id_usuario_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.admin_usuario_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.admin_usuario_id_usuario_seq OWNER TO admin;

--
-- Name: admin_usuario_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.admin_usuario_id_usuario_seq OWNED BY comun.admin_usuario.id_usuario;


--
-- Name: info_materia; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_materia (
    id_materia integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL,
    nombre_normalizado text
);


ALTER TABLE comun.info_materia OWNER TO admin;

--
-- Name: info_materia_id_materia_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_materia_id_materia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_materia_id_materia_seq OWNER TO admin;

--
-- Name: info_materia_id_materia_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_materia_id_materia_seq OWNED BY comun.info_materia.id_materia;


--
-- Name: info_opcion; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_opcion (
    id_opcion integer NOT NULL,
    id_pregunta integer NOT NULL,
    texto text NOT NULL,
    orden integer NOT NULL,
    es_correcta boolean DEFAULT false,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.info_opcion OWNER TO admin;

--
-- Name: info_opcion_id_opcion_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_opcion_id_opcion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_opcion_id_opcion_seq OWNER TO admin;

--
-- Name: info_opcion_id_opcion_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_opcion_id_opcion_seq OWNED BY comun.info_opcion.id_opcion;


--
-- Name: info_partida; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_partida (
    id_partida integer NOT NULL,
    id_prueba integer NOT NULL,
    codigo_acceso character varying(6) NOT NULL,
    id_profesor integer NOT NULL,
    estado_partida character varying(20) DEFAULT 'esperando'::character varying,
    iniciado_en timestamp with time zone,
    finalizado_en timestamp with time zone,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.info_partida OWNER TO admin;

--
-- Name: info_partida_estudiante; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_partida_estudiante (
    id_partida_estudiante integer NOT NULL,
    id_partida integer NOT NULL,
    id_estudiante integer NOT NULL,
    nickname_opcional character varying(100),
    puntaje_total integer DEFAULT 0,
    respuestas_correctas integer DEFAULT 0,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL
);


ALTER TABLE comun.info_partida_estudiante OWNER TO admin;

--
-- Name: info_partida_estudiante_id_partida_estudiante_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_partida_estudiante_id_partida_estudiante_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_partida_estudiante_id_partida_estudiante_seq OWNER TO admin;

--
-- Name: info_partida_estudiante_id_partida_estudiante_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_partida_estudiante_id_partida_estudiante_seq OWNED BY comun.info_partida_estudiante.id_partida_estudiante;


--
-- Name: info_partida_id_partida_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_partida_id_partida_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_partida_id_partida_seq OWNER TO admin;

--
-- Name: info_partida_id_partida_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_partida_id_partida_seq OWNED BY comun.info_partida.id_partida;


--
-- Name: info_pregunta; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_pregunta (
    id_pregunta integer NOT NULL,
    id_prueba integer NOT NULL,
    texto text NOT NULL,
    tipo character varying(20) DEFAULT 'single_choice'::character varying,
    cooldown integer DEFAULT 5,
    tiempo_limite integer DEFAULT 30,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL,
    image_url text,
    audio_url text,
    video_url text
);
ALTER TABLE ONLY comun.info_pregunta ALTER COLUMN image_url SET STORAGE PLAIN;


ALTER TABLE comun.info_pregunta OWNER TO admin;

--
-- Name: info_pregunta_id_pregunta_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_pregunta_id_pregunta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_pregunta_id_pregunta_seq OWNER TO admin;

--
-- Name: info_pregunta_id_pregunta_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_pregunta_id_pregunta_seq OWNED BY comun.info_pregunta.id_pregunta;


--
-- Name: info_prueba; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_prueba (
    id_prueba integer NOT NULL,
    titulo character varying(255) NOT NULL,
    descripcion text,
    id_profesor integer NOT NULL,
    configuracion jsonb,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL,
    id_materia integer
);


ALTER TABLE comun.info_prueba OWNER TO admin;

--
-- Name: info_prueba_id_prueba_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_prueba_id_prueba_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_prueba_id_prueba_seq OWNER TO admin;

--
-- Name: info_prueba_id_prueba_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_prueba_id_prueba_seq OWNED BY comun.info_prueba.id_prueba;


--
-- Name: info_respuesta; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_respuesta (
    id_respuesta integer NOT NULL,
    id_partida_estudiante integer NOT NULL,
    id_pregunta integer NOT NULL,
    respuesta_dada integer,
    tiempo_ms integer,
    puntaje_obtenido integer DEFAULT 0,
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_opcion_seleccionada integer
);


ALTER TABLE comun.info_respuesta OWNER TO admin;

--
-- Name: info_respuesta_id_respuesta_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_respuesta_id_respuesta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_respuesta_id_respuesta_seq OWNER TO admin;

--
-- Name: info_respuesta_id_respuesta_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_respuesta_id_respuesta_seq OWNED BY comun.info_respuesta.id_respuesta;


--
-- Name: info_retroalimentacion_llm; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.info_retroalimentacion_llm (
    id_retroalimentacion integer NOT NULL,
    id_partida_estudiante integer NOT NULL,
    preguntas_falladas jsonb,
    prompt_enviado text,
    respuesta_llm text,
    modelo_usado character varying(100),
    fecha_creacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer
);


ALTER TABLE comun.info_retroalimentacion_llm OWNER TO admin;

--
-- Name: info_retroalimentacion_llm_id_retroalimentacion_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.info_retroalimentacion_llm_id_retroalimentacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.info_retroalimentacion_llm_id_retroalimentacion_seq OWNER TO admin;

--
-- Name: info_retroalimentacion_llm_id_retroalimentacion_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.info_retroalimentacion_llm_id_retroalimentacion_seq OWNED BY comun.info_retroalimentacion_llm.id_retroalimentacion;


--
-- Name: profesor_materia; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.profesor_materia (
    id_profesor_materia integer NOT NULL,
    id_profesor integer NOT NULL,
    id_materia integer NOT NULL,
    fecha_asignacion timestamp with time zone DEFAULT now(),
    usuario_creacion integer,
    fecha_modificacion timestamp with time zone,
    usuario_modificacion integer,
    id_estado integer NOT NULL,
    id_periodo_lectivo integer NOT NULL
);


ALTER TABLE comun.profesor_materia OWNER TO admin;

--
-- Name: profesor_materia_id_profesor_materia_seq; Type: SEQUENCE; Schema: comun; Owner: admin
--

CREATE SEQUENCE comun.profesor_materia_id_profesor_materia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE comun.profesor_materia_id_profesor_materia_seq OWNER TO admin;

--
-- Name: profesor_materia_id_profesor_materia_seq; Type: SEQUENCE OWNED BY; Schema: comun; Owner: admin
--

ALTER SEQUENCE comun.profesor_materia_id_profesor_materia_seq OWNED BY comun.profesor_materia.id_profesor_materia;


--
-- Name: sessions; Type: TABLE; Schema: comun; Owner: admin
--

CREATE TABLE comun.sessions (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


ALTER TABLE comun.sessions OWNER TO admin;

--
-- Name: admin_administrador id_administrador; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_administrador ALTER COLUMN id_administrador SET DEFAULT nextval('comun.admin_administrador_id_administrador_seq'::regclass);


--
-- Name: admin_estado id_estado; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estado ALTER COLUMN id_estado SET DEFAULT nextval('comun.admin_estado_id_estado_seq'::regclass);


--
-- Name: admin_estudiante id_estudiante; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estudiante ALTER COLUMN id_estudiante SET DEFAULT nextval('comun.admin_estudiante_id_estudiante_seq'::regclass);


--
-- Name: admin_parametro id_parametro; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_parametro ALTER COLUMN id_parametro SET DEFAULT nextval('comun.admin_parametro_id_parametro_seq'::regclass);


--
-- Name: admin_periodo_lectivo id_periodo_lectivo; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_periodo_lectivo ALTER COLUMN id_periodo_lectivo SET DEFAULT nextval('comun.admin_periodo_lectivo_id_periodo_lectivo_seq'::regclass);


--
-- Name: admin_profesor id_profesor; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_profesor ALTER COLUMN id_profesor SET DEFAULT nextval('comun.admin_profesor_id_profesor_seq'::regclass);


--
-- Name: admin_rol id_rol; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_rol ALTER COLUMN id_rol SET DEFAULT nextval('comun.admin_rol_id_rol_seq'::regclass);


--
-- Name: admin_usuario id_usuario; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_usuario ALTER COLUMN id_usuario SET DEFAULT nextval('comun.admin_usuario_id_usuario_seq'::regclass);


--
-- Name: info_materia id_materia; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_materia ALTER COLUMN id_materia SET DEFAULT nextval('comun.info_materia_id_materia_seq'::regclass);


--
-- Name: info_opcion id_opcion; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_opcion ALTER COLUMN id_opcion SET DEFAULT nextval('comun.info_opcion_id_opcion_seq'::regclass);


--
-- Name: info_partida id_partida; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida ALTER COLUMN id_partida SET DEFAULT nextval('comun.info_partida_id_partida_seq'::regclass);


--
-- Name: info_partida_estudiante id_partida_estudiante; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante ALTER COLUMN id_partida_estudiante SET DEFAULT nextval('comun.info_partida_estudiante_id_partida_estudiante_seq'::regclass);


--
-- Name: info_pregunta id_pregunta; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_pregunta ALTER COLUMN id_pregunta SET DEFAULT nextval('comun.info_pregunta_id_pregunta_seq'::regclass);


--
-- Name: info_prueba id_prueba; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_prueba ALTER COLUMN id_prueba SET DEFAULT nextval('comun.info_prueba_id_prueba_seq'::regclass);


--
-- Name: info_respuesta id_respuesta; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_respuesta ALTER COLUMN id_respuesta SET DEFAULT nextval('comun.info_respuesta_id_respuesta_seq'::regclass);


--
-- Name: info_retroalimentacion_llm id_retroalimentacion; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_retroalimentacion_llm ALTER COLUMN id_retroalimentacion SET DEFAULT nextval('comun.info_retroalimentacion_llm_id_retroalimentacion_seq'::regclass);


--
-- Name: profesor_materia id_profesor_materia; Type: DEFAULT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia ALTER COLUMN id_profesor_materia SET DEFAULT nextval('comun.profesor_materia_id_profesor_materia_seq'::regclass);


--
-- Name: admin_administrador admin_administrador_id_usuario_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_administrador
    ADD CONSTRAINT admin_administrador_id_usuario_key UNIQUE (id_usuario);


--
-- Name: admin_administrador admin_administrador_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_administrador
    ADD CONSTRAINT admin_administrador_pkey PRIMARY KEY (id_administrador);


--
-- Name: admin_estado admin_estado_codigo_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estado
    ADD CONSTRAINT admin_estado_codigo_key UNIQUE (codigo);


--
-- Name: admin_estado admin_estado_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estado
    ADD CONSTRAINT admin_estado_pkey PRIMARY KEY (id_estado);


--
-- Name: admin_estudiante admin_estudiante_codigo_estudiante_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estudiante
    ADD CONSTRAINT admin_estudiante_codigo_estudiante_key UNIQUE (codigo_estudiante);


--
-- Name: admin_estudiante admin_estudiante_id_usuario_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estudiante
    ADD CONSTRAINT admin_estudiante_id_usuario_key UNIQUE (id_usuario);


--
-- Name: admin_estudiante admin_estudiante_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estudiante
    ADD CONSTRAINT admin_estudiante_pkey PRIMARY KEY (id_estudiante);


--
-- Name: admin_parametro admin_parametro_clave_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_parametro
    ADD CONSTRAINT admin_parametro_clave_key UNIQUE (clave);


--
-- Name: admin_parametro admin_parametro_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_parametro
    ADD CONSTRAINT admin_parametro_pkey PRIMARY KEY (id_parametro);


--
-- Name: admin_periodo_lectivo admin_periodo_lectivo_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_periodo_lectivo
    ADD CONSTRAINT admin_periodo_lectivo_pkey PRIMARY KEY (id_periodo_lectivo);


--
-- Name: admin_profesor admin_profesor_id_usuario_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_profesor
    ADD CONSTRAINT admin_profesor_id_usuario_key UNIQUE (id_usuario);


--
-- Name: admin_profesor admin_profesor_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_profesor
    ADD CONSTRAINT admin_profesor_pkey PRIMARY KEY (id_profesor);


--
-- Name: admin_rol admin_rol_nombre_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_rol
    ADD CONSTRAINT admin_rol_nombre_key UNIQUE (nombre);


--
-- Name: admin_rol admin_rol_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_rol
    ADD CONSTRAINT admin_rol_pkey PRIMARY KEY (id_rol);


--
-- Name: admin_usuario admin_usuario_cedula_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_usuario
    ADD CONSTRAINT admin_usuario_cedula_key UNIQUE (cedula);


--
-- Name: admin_usuario admin_usuario_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_usuario
    ADD CONSTRAINT admin_usuario_pkey PRIMARY KEY (id_usuario);


--
-- Name: admin_usuario admin_usuario_username_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_usuario
    ADD CONSTRAINT admin_usuario_username_key UNIQUE (username);


--
-- Name: info_materia info_materia_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_materia
    ADD CONSTRAINT info_materia_pkey PRIMARY KEY (id_materia);


--
-- Name: info_opcion info_opcion_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_opcion
    ADD CONSTRAINT info_opcion_pkey PRIMARY KEY (id_opcion);


--
-- Name: info_partida info_partida_codigo_acceso_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida
    ADD CONSTRAINT info_partida_codigo_acceso_key UNIQUE (codigo_acceso);


--
-- Name: info_partida_estudiante info_partida_estudiante_id_partida_id_estudiante_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante
    ADD CONSTRAINT info_partida_estudiante_id_partida_id_estudiante_key UNIQUE (id_partida, id_estudiante);


--
-- Name: info_partida_estudiante info_partida_estudiante_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante
    ADD CONSTRAINT info_partida_estudiante_pkey PRIMARY KEY (id_partida_estudiante);


--
-- Name: info_partida info_partida_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida
    ADD CONSTRAINT info_partida_pkey PRIMARY KEY (id_partida);


--
-- Name: info_pregunta info_pregunta_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_pregunta
    ADD CONSTRAINT info_pregunta_pkey PRIMARY KEY (id_pregunta);


--
-- Name: info_prueba info_prueba_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_prueba
    ADD CONSTRAINT info_prueba_pkey PRIMARY KEY (id_prueba);


--
-- Name: info_respuesta info_respuesta_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_respuesta
    ADD CONSTRAINT info_respuesta_pkey PRIMARY KEY (id_respuesta);


--
-- Name: info_retroalimentacion_llm info_retroalimentacion_llm_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_retroalimentacion_llm
    ADD CONSTRAINT info_retroalimentacion_llm_pkey PRIMARY KEY (id_retroalimentacion);


--
-- Name: profesor_materia profesor_materia_id_profesor_id_materia_key; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_id_profesor_id_materia_key UNIQUE (id_profesor, id_materia);


--
-- Name: profesor_materia profesor_materia_periodo_unique; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_periodo_unique UNIQUE (id_profesor, id_materia, id_periodo_lectivo);


--
-- Name: profesor_materia profesor_materia_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_pkey PRIMARY KEY (id_profesor_materia);


--
-- Name: sessions session_pkey; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.sessions
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


--
-- Name: info_partida uk_partida_codigo_acceso; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida
    ADD CONSTRAINT uk_partida_codigo_acceso UNIQUE (codigo_acceso);


--
-- Name: info_partida_estudiante uk_partida_estudiante; Type: CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante
    ADD CONSTRAINT uk_partida_estudiante UNIQUE (id_partida, id_estudiante);


--
-- Name: IDX_session_expire; Type: INDEX; Schema: comun; Owner: admin
--

CREATE INDEX "IDX_session_expire" ON comun.sessions USING btree (expire);


--
-- Name: idx_materia_nombre_normalizado; Type: INDEX; Schema: comun; Owner: admin
--

CREATE UNIQUE INDEX idx_materia_nombre_normalizado ON comun.info_materia USING btree (nombre_normalizado) WHERE (id_estado = comun.obtener_id_estado_activo());


--
-- Name: idx_opcion_pregunta_orden; Type: INDEX; Schema: comun; Owner: admin
--

CREATE UNIQUE INDEX idx_opcion_pregunta_orden ON comun.info_opcion USING btree (id_pregunta, orden) WHERE (id_estado = comun.obtener_id_estado_activo());


--
-- Name: info_materia trg_materia_normalizar; Type: TRIGGER; Schema: comun; Owner: admin
--

CREATE TRIGGER trg_materia_normalizar BEFORE INSERT OR UPDATE OF nombre ON comun.info_materia FOR EACH ROW EXECUTE FUNCTION comun.trg_materia_normalizar();


--
-- Name: admin_estado trg_proteger_estado_activo; Type: TRIGGER; Schema: comun; Owner: admin
--

CREATE TRIGGER trg_proteger_estado_activo BEFORE UPDATE ON comun.admin_estado FOR EACH ROW EXECUTE FUNCTION comun.trg_proteger_estado_activo();


--
-- Name: admin_parametro admin_parametro_id_estado_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_parametro
    ADD CONSTRAINT admin_parametro_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES comun.admin_estado(id_estado);


--
-- Name: admin_periodo_lectivo admin_periodo_lectivo_id_estado_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_periodo_lectivo
    ADD CONSTRAINT admin_periodo_lectivo_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES comun.admin_estado(id_estado);


--
-- Name: admin_administrador fk_administrador_usuario; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_administrador
    ADD CONSTRAINT fk_administrador_usuario FOREIGN KEY (id_usuario) REFERENCES comun.admin_usuario(id_usuario);


--
-- Name: admin_estudiante fk_estudiante_usuario; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_estudiante
    ADD CONSTRAINT fk_estudiante_usuario FOREIGN KEY (id_usuario) REFERENCES comun.admin_usuario(id_usuario);


--
-- Name: info_partida_estudiante fk_parte_estudiante; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante
    ADD CONSTRAINT fk_parte_estudiante FOREIGN KEY (id_estudiante) REFERENCES comun.admin_estudiante(id_estudiante);


--
-- Name: info_partida_estudiante fk_parte_partida; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida_estudiante
    ADD CONSTRAINT fk_parte_partida FOREIGN KEY (id_partida) REFERENCES comun.info_partida(id_partida);


--
-- Name: info_partida fk_partida_profesor; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida
    ADD CONSTRAINT fk_partida_profesor FOREIGN KEY (id_profesor) REFERENCES comun.admin_profesor(id_profesor);


--
-- Name: info_partida fk_partida_prueba; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_partida
    ADD CONSTRAINT fk_partida_prueba FOREIGN KEY (id_prueba) REFERENCES comun.info_prueba(id_prueba);


--
-- Name: info_pregunta fk_pregunta_prueba; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_pregunta
    ADD CONSTRAINT fk_pregunta_prueba FOREIGN KEY (id_prueba) REFERENCES comun.info_prueba(id_prueba);


--
-- Name: admin_profesor fk_profesor_usuario; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.admin_profesor
    ADD CONSTRAINT fk_profesor_usuario FOREIGN KEY (id_usuario) REFERENCES comun.admin_usuario(id_usuario);


--
-- Name: info_prueba fk_prueba_materia; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_prueba
    ADD CONSTRAINT fk_prueba_materia FOREIGN KEY (id_materia) REFERENCES comun.info_materia(id_materia);


--
-- Name: info_respuesta fk_respuesta_opcion; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_respuesta
    ADD CONSTRAINT fk_respuesta_opcion FOREIGN KEY (id_opcion_seleccionada) REFERENCES comun.info_opcion(id_opcion);


--
-- Name: info_respuesta fk_respuesta_partida_estudiante; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_respuesta
    ADD CONSTRAINT fk_respuesta_partida_estudiante FOREIGN KEY (id_partida_estudiante) REFERENCES comun.info_partida_estudiante(id_partida_estudiante);


--
-- Name: info_respuesta fk_respuesta_pregunta; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_respuesta
    ADD CONSTRAINT fk_respuesta_pregunta FOREIGN KEY (id_pregunta) REFERENCES comun.info_pregunta(id_pregunta);


--
-- Name: info_materia info_materia_id_estado_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_materia
    ADD CONSTRAINT info_materia_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES comun.admin_estado(id_estado);


--
-- Name: info_opcion info_opcion_id_estado_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_opcion
    ADD CONSTRAINT info_opcion_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES comun.admin_estado(id_estado);


--
-- Name: info_opcion info_opcion_id_pregunta_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_opcion
    ADD CONSTRAINT info_opcion_id_pregunta_fkey FOREIGN KEY (id_pregunta) REFERENCES comun.info_pregunta(id_pregunta);


--
-- Name: info_prueba info_prueba_id_materia_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.info_prueba
    ADD CONSTRAINT info_prueba_id_materia_fkey FOREIGN KEY (id_materia) REFERENCES comun.info_materia(id_materia);


--
-- Name: profesor_materia profesor_materia_id_estado_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES comun.admin_estado(id_estado);


--
-- Name: profesor_materia profesor_materia_id_materia_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_id_materia_fkey FOREIGN KEY (id_materia) REFERENCES comun.info_materia(id_materia);


--
-- Name: profesor_materia profesor_materia_id_periodo_lectivo_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_id_periodo_lectivo_fkey FOREIGN KEY (id_periodo_lectivo) REFERENCES comun.admin_periodo_lectivo(id_periodo_lectivo);


--
-- Name: profesor_materia profesor_materia_id_profesor_fkey; Type: FK CONSTRAINT; Schema: comun; Owner: admin
--

ALTER TABLE ONLY comun.profesor_materia
    ADD CONSTRAINT profesor_materia_id_profesor_fkey FOREIGN KEY (id_profesor) REFERENCES comun.admin_profesor(id_profesor);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO admin;


--
-- PostgreSQL database dump complete
--

\unrestrict Vy3S7dneHiR24qYUrN8N1ozLMFtPkIq54KR6wr5mIQrq3RaLcmAXcEOhL73pkFw

