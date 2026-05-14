import Button from "@mindbuzz/web/features/game/components/Button"
import Input from "@mindbuzz/web/features/game/components/Input"
import Loader from "@mindbuzz/web/features/game/components/Loader"
import { useState } from "react"
import toast from "react-hot-toast"

const TOPICS = ["Bacterias", "Células"]

type Props = {
  managerId?: string
  materiaList: { id: number; nombre: string }[]
}

const QuestionGeneratorPanel = ({ managerId, materiaList }: Props) => {
  const [cantidad, setCantidad] = useState<number>(2)
  const [nombre, setNombre] = useState("")
  const [observaciones, setObservaciones] = useState("")
  const [selectedTopics, setSelectedTopics] = useState<string[]>([])
  const [selectedMateria, setSelectedMateria] = useState<number | "">(
    materiaList.length > 0 ? materiaList[0].id : ""
  )
  const [isLoading, setIsLoading] = useState(false)

  const handleToggleTopic = (topic: string) => {
    setSelectedTopics((current) =>
      current.includes(topic)
        ? current.filter((t) => t !== topic)
        : [...current, topic]
    )
  }

  const handleSubmit = async () => {
    console.log("[QuestionGeneratorPanel] Botón GENERAR presionado");
    
    if (!nombre.trim()) {
      toast.error("Por favor, ingresa un nombre para el cuestionario")
      return
    }

    if (selectedTopics.length === 0) {
      toast.error("Por favor, selecciona al menos un tema")
      return
    }

    setIsLoading(true)
    console.log("[QuestionGeneratorPanel] Enviando petición a la API externa...");

    try {
      const url = import.meta.env.VITE_URL_GENERATE_QUIZ || "http://localhost:5000/generate-quiz"

      console.log(`[QuestionGeneratorPanel] URL: ${url}`);

      const payload = {
        cantidad: cantidad,
        nombre: nombre,
        temas: selectedTopics,
        observaciones: observaciones,
        idUsuario: managerId ? parseInt(managerId) : null,
        materia: materiaList.find(m => m.id === selectedMateria)?.nombre || "General",
        idMateria: selectedMateria,
      };

      console.log("[QuestionGeneratorPanel] Payload a enviar:", payload);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      })

      if (!response.ok) {
        throw new Error("Error al generar el cuestionario")
      }

      const data = await response.json()
      console.log("[QuestionGeneratorPanel] Respuesta recibida:", data);
      toast.success("¡Cuestionario generado con éxito!")
    } catch (error) {
      console.error("[QuestionGeneratorPanel] Error en la petición:", error);
      toast.error("Hubo un error al generar el cuestionario. Verifica la consola.")
    } finally {
      setIsLoading(false)
      console.log("[QuestionGeneratorPanel] Proceso finalizado");
    }
  }

  return (
    <div className="z-10 flex w-full max-w-2xl flex-col gap-5 rounded-md bg-white p-4 shadow-sm md:p-6 anim-show">
      <h1 className="text-2xl font-bold">Generador de Preguntas</h1>

      {/* Cantidad de Preguntas */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-semibold text-gray-700 uppercase">Cantidad:</label>
        <div className="flex items-center gap-3">
          <Input
            type="number"
            value={cantidad}
            onChange={(e) => setCantidad(Number(e.target.value))}
            className="w-24 text-center"
            min={1}
          />
          <span className="text-xl font-bold text-gray-500 italic">PREGUNTAS</span>
        </div>
      </div>

      {/* Nombre del Cuestionario */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-semibold text-gray-700 uppercase text-left">Nombre:</label>
        <Input
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          placeholder="Ej: Quiz de Biología"
          className="w-full"
        />
      </div>

      {/* Selección de Materia */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-semibold text-gray-700 uppercase text-left">Materia:</label>
        <div className="relative group">
          <select 
            value={selectedMateria} 
            onChange={(e) => setSelectedMateria(e.target.value ? Number(e.target.value) : "")}
            className="w-full p-3 border-2 border-gray-100 rounded-lg bg-gray-50 outline-none focus:border-primary focus:bg-white transition-all appearance-none text-lg font-semibold text-gray-800 cursor-pointer shadow-sm hover:shadow-md"
          >
            {materiaList.map(m => (
              <option key={m.id} value={m.id}>{m.nombre}</option>
            ))}
          </select>
          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 group-hover:text-primary transition-colors">
            <svg className="h-6 w-6 fill-current" viewBox="0 0 20 20">
              <path d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
            </svg>
          </div>
        </div>
      </div>

      

      {/* Temas (Índice) */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-semibold text-gray-700 uppercase text-left">Temas:</label>
        <div className="rounded-md border-2 border-gray-100 bg-gray-50 p-4 shadow-inner">
          <h3 className="mb-4 text-center font-bold text-gray-400 uppercase tracking-[0.2em] border-b border-gray-200 pb-2">
            ÍNDICE
          </h3>
          <div className="flex flex-col gap-3">
            {TOPICS.map((topic) => (
              <label 
                key={topic} 
                className="flex items-center gap-3 cursor-pointer hover:bg-white p-2 rounded-md transition-all shadow-sm border border-transparent hover:border-gray-200"
              >
                <input
                  type="checkbox"
                  checked={selectedTopics.includes(topic)}
                  onChange={() => handleToggleTopic(topic)}
                  className="h-6 w-6 rounded border-gray-300 text-primary focus:ring-primary accent-primary"
                />
                <span className="text-lg font-semibold text-gray-700">{topic}</span>
              </label>
            ))}
          </div>
        </div>
      </div>


      {/* Observaciones */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-semibold text-gray-700 uppercase text-left">Observaciones:</label>
        <textarea
          value={observaciones}
          onChange={(e) => setObservaciones(e.target.value)}
          placeholder="Instrucciones adicionales para la IA..."
          className="min-h-[100px] rounded-sm p-3 text-lg font-semibold outline-2 outline-gray-300 focus:outline-primary transition-all"
        />
      </div>

      {/* Botón de Acción */}
      <Button
        onClick={handleSubmit}
        disabled={isLoading}
        className="relative flex items-center justify-center gap-3 mt-4 h-14 text-xl shadow-lg"
      >
        {isLoading ? (
          <>
            <Loader className="h-8 w-8 animate-spin" />
            <span className="animate-pulse">GENERANDO...</span>
          </>
        ) : (
          "GENERAR CUESTIONARIO"
        )}
      </Button>
    </div>
  )
}

export default QuestionGeneratorPanel
