# 20 - Buenas Prácticas y Trabajo en Equipo

Este documento consolida las directrices esenciales orientadas al desarrollo en equipos pequeños, asegurando que la arquitectura de MindBuzz se mantenga sólida y libre de regresiones.

## 1. Abierto a la Extensión, Cerrado a la Modificación (Open-Closed Principle)
**El código que ya ha sido escrito, probado y funciona, no debe ser alterado innecesariamente.**
Cuando te enfrentes a requerimientos de nuevos módulos orgánicos (como la adición de una gestión de alumnos), asume que es una *extensión* y no una reescritura. 
- **Bases de Datos:** Prefiere añadir tablas nuevas o usar campos flexibles no restrictivos (como los JSON) antes que reordenar todas las columnas existentes en tablas legacy e invalidar consultas anteriores.
- **Backend:** Añade nuevos servicios en archivos separados u orquestaciones encima del esquema actual, sin cargar de lógicas o condicionales ("if's") masivos las clases y archivos existentes.

## 2. Paradigma Híbrido (¿Es Orientado a Objetos?)
El repositorio no es un sistema de Programación Orientada a Objetos 100% clásico tradicional (como Java), pero sí sigue **Patrones OOP en el Backend y Funcionales en el Frontend**:
* **Backend:** Hace un amplio uso de encapsulamiento mediante Clases y Patrones Singleton, inyectando comportamientos orientados a objetos. Existen entidades como `class Game` (que abstrae los estados en memoria del juego y sus mutaciones) y servicios como el `AccountStore` o el `HistoryService` que actúan de proxies OOP en lugar de tener las lógicas desparramadas en funciones sueltas. En la adición de nuevas características, se espera preservar este encapsulamiento manteniendo cada clase unificada a una única responsabilidad.
* **Frontend:** Es completamente Funcional y Declarativo utilizando puramente _Hooks_ de React y arquitectura de _Stores_ de estado inmutables mediante Zustand. Se exhorta encarecidamente a conservar este patrón y no forzar POO tradicional (clases en React) donde está obsoleto.

## 3. Trabajo en Equipo de a Grupos
Para minimizar los conflictos en repositorios de grupo pequeño (`Merge Conflicts`), deben prevalecer las siguientes buenas prácticas en la dinámica diaria:

### 3.1 Dividir Tareas por Capas y Archivos
Distribuyan quién toca cada cosa de forma horizontal:
* Persona A aborda el Front y Componentes UI.
* Persona B administra la inyección asíncrona de los eventos *WebSocket* (Backend Server).
* Persona C maneja las consultas (Queries - Database) en los *Stores*. 
Al finalizar, establecen un canal estándar (JSON y APIs) mediante iteración constante.

### 3.2 Ramas (Branches) 
Nunca comitees directamente en `main`. Crea ramas cortas enfocadas en una característica única del TODO. Ejemplo:
- `feature/auth-alumnos` para la nueva pantalla.
- Antes de cada unión (`merge` o PR), asegúrate de hacer un `pull` con tu base y cerciórate de no quebrar código que no fue de tu autoría directa.

### 3.3 Nombrado y Arquitectura Intacta
Sigue la convención pre-existente. Unidades en inglés técnico al programar, y los archivos nuevos como `StudentStore` o configuraciones parecidas en las carpetas respectivas, logrando integración en lugar de reemplazo.

## 4. Análisis de Impacto de Código y Estrategia de Pruebas
Si bien el objetivo del equipo es sumar características sin quebrar la base (**Open-Closed Principle**), a veces un código nuevo choca indirectamente con dinámicas viejas. Como regla grupal, todo cambio debe pasar por las siguientes validaciones mentales y prácticas antes de mezclarse a la rama principal:

### 4.1 Mapa de Impacto (Preguntas antes de entregar código)
- **Cambios en Base de Datos (Backend):** *"¿Si añado este campo estricto (NOT NULL), provocaré que las bases viejas de mis compañeros fallen (crasheen) al arrancar el proyecto?"* -> *(Usa Nullable o provee valores predeterminados seguros para hacer transiciones retrocompatibles).*
- **WebSockets / Redes:** *"Al añadir o restringir este evento, ¿el frontend sabrá cómo reaccionar, o lo he dejado atrapado en una pantalla cargando?"* -> *(Todo fallo interno debe siempre emitir un `errorMessage` claro de vuelta por el WebSocket).*

### 4.2 Obligación de Probar y Demostrar (Testing Local)
Ningún compañero debe aceptar código ("Merge") si el autor no especifica **Qué modificó y Cómo se prueba**:
1. **Pruebas de Flujo Completo (End-to-End Trivial):** Si se codificó un cambio interactivo, arrancar 2 pestañas separadas (Modo normal como Profesor / Modo Incógnito simulando teléfono del Alumno). Realizar el flujo mínimo (Login -> Unirse -> Contestar -> Fin de partida) y confirmar que la nueva adición no estropeó el flujo.
2. **Pruebas Negativas:** No pruebes solo "el camino feliz". Cambia la configuración del `./config.json` apagando tus features (ej. pon `requireStudentLogin` a FALSE) y asegura que el sistema viejo resurja sin errores de forma transparente.
3. **Prueba Legal (Retrocompatibilidad de datos):** Obligatorio revisar que usuarios con historiales heredados (`legacy` u objetos antiguos sin las nuevas propiedades) puedan seguir utilizando el software y visualizando sus resultados sin que la app falle.
