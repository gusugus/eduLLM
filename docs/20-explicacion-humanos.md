# Explicación de las Nuevas Funcionalidades: Gestión y Autenticación de Estudiantes

Este documento explica de forma sencilla y con palabras humanas los cambios que se van a implementar en la plataforma para mejorar la experiencia de los profesores y estudiantes.

## ¿Qué estamos cambiando?

Actualmente, cuando los jugadores entran a una partida, solo colocan un apodo (nickname) temporal. Esto hace difícil que el profesor sepa exactamente quién es quién a la hora de revisar las calificaciones y el historial.

Para solucionar esto, estamos agregando **Cuentas de Estudiantes**. 

Los principales cambios que se están haciendo en el sistema son:
1. **Asignación a un Profesor:** Ahora, cada estudiante estará ligado a un profesor (Manager). De esta forma, el profesor tendrá su propia "clase" o lista de alumnos y podrá ver exclusivamente sus resultados y progresos.
2. **Creación de Cuentas por el Profesor:** El profesor será el encargado de crear los usuarios para sus alumnos desde su propio panel de control, asegurando que todos estén correctamente registrados.
3. **Inicio de Sesión y Autonomía para Estudiantes:** Los alumnos tendrán la posibilidad de loguearse y, muy importante, **podrán cambiar su propia contraseña** para mantener su cuenta segura.
4. **Historial con Nombres Reales y Apodos en el Juego:** Aunque los estudiantes pueden elegir un "nickname" divertido para que aparezca en la pantalla durante el juego, el sistema usará internamente su **nombre real registrado** para todos los reportes y el historial.
5. **Seguridad Web Básica:** El sistema recordará la sesión del alumno en su computadora. Si el profesor decide que el login es obligatorio, nadie podrá entrar a jugar si no ha iniciado sesión correctamente.
6. **Base de Conocimientos (Ciencias Naturales):** Estamos creando un "cerebro" de preguntas sobre Ciencias Naturales. El profesor solo tendrá que elegir un tema (por ejemplo, "La Célula") y el sistema seleccionará automáticamente las preguntas para crear un test al instante.
8. **Tutor Personalizado por Transparencia (TPT):** ¡Este es el cambio más innovador! Ahora, cuando un estudiante termine un test y cometa errores, una Inteligencia Artificial (IA) actuará como un tutor privado 24/7. Le explicará exactamente por qué se equivocó y permitirá que el alumno le haga preguntas para profundizar, asegurándose de que siempre se mantengan hablando del tema de la clase.

---

## ¿Cuáles son los beneficios de hacer esta implementación?

Implementar estas mejoras trae múltiples ventajas tanto para la administración de las clases como para la experiencia de los participantes:

- **Mejor Control y Organización:** Los profesores ya no tendrán que adivinar a quién pertenece un apodo gracioso ("Juanito123"). Al tener cuentas registradas, la evaluación es precisa y profesional.
- **Privacidad y Seguridad:** Al vincular a los estudiantes con **1 solo manager**, se asegura que la información y las calificaciones de esos alumnos solo sean vistas por el docente autorizado a cargo de ellos. Además, el inicio de sesión persistente facilita que el alumno no tenga que escribir sus datos cada vez.
- **Trazabilidad a lo Largo del Tiempo:** Al usar el nombre real para los registros internos, el profesor tiene un historial impecable, sin importar si el alumno cambia su apodo en cada partida.
- **Ahorro de Tiempo con Automatización:** Con la nueva base de conocimientos de Ciencias Naturales, el profesor ya no tiene que escribir pregunta por pregunta. El sistema lo hace por él, permitiéndole enfocarse en el **análisis del desempeño** de sus alumnos.
- **Análisis de Situación:** Al tener datos organizados por temas, el profesor podrá ver rápidamente qué conceptos de Ciencias Naturales no han quedado claros en el grupo y reforzarlos.
- **Aprendizaje del Error (Tutor IA):** Con el TPT, el estudiante no se va a casa con la duda. El tutor de IA cierra la brecha entre "sacar una nota" y "aprender de verdad", convirtiendo cada respuesta incorrecta en una lección personalizada y segura.
- **Flexibilidad Total (Login Opcional):** El hecho de que el inicio de sesión sea "opcional" garantiza que la plataforma no pierda su agilidad.
