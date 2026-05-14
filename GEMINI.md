Todas nuestras conversaciones serán en español.
Sigamos los principios SOLID.
Mantengamos la documentacion actualizada ante cualquier cambio importante (Base de datos: BBDD_DOCUMENTATIOn.md, ts/js:  ./docs/*.md).
Primero consultar la documentacion antes de buscar informacion en el proyecto, cuando se requiera de modificaciones.
El backend usa PROCEDIMIENTOS ALMACENADOS para la persistencia de datos.
El backend usa FUNCIONES para traer datos.
El backend *no* debe usar DDL (Insert, Update, Create, Delete, Drop)
El agente no esta a cargo de crear/modificar/leer la base de datos, solo de usar los procedimientos almacenados.
Si se necesita agregar/modificar algun procedimiento, se debe hablar con el humano a cargo.
Si se cambia el backend, se debe actualizar la documentacion.
En cada cambio, pongamos un console.log en el codigo para saber que se esta haciendo, y poder trackear el cambio/funcionamiento.
No se debe hacer BORRADOS FISICOS en la base, sino borrados LOGICOS (alguna columna estado, o similar).
Adoptemos el principio de "nunca borres datos, solo cambia su visibilidad"
Creemos primero un plan de accion (resumido) y preguntar si algo no tienes claro primero.
