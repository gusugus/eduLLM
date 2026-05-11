import type { QuizzWithId } from "@mindbuzz/common/types/game"
import Button from "@mindbuzz/web/features/game/components/Button"
import Input from "@mindbuzz/web/features/game/components/Input"
import clsx from "clsx"
import { type KeyboardEvent, useEffect, useMemo, useState } from "react"
import toast from "react-hot-toast"

type Props = {
  quizzList: QuizzWithId[]
  materiaList: { id: number; nombre: string }[]
  onSelect: (_id: string) => void
  onCreate: (_title: string, _subject: string, _materiaId?: number) => void
  onDelete: (_id: string) => void
  onEdit: (_id: string) => void
}

const SelectQuizz = ({
  quizzList,
  materiaList,
  onCreate,
  onDelete,
  onEdit,
  onSelect,
}: Props) => {
  const [selected, setSelected] = useState<string | null>(null)
  const [selectedMateria, setSelectedMateria] = useState<number | "">("")
  const [quizName, setQuizName] = useState("")

  // Seleccionar la primera materia por defecto cuando se carga la lista
  useEffect(() => {
    if (materiaList.length > 0 && selectedMateria === "") {
      setSelectedMateria(materiaList[0].id)
    }
  }, [materiaList, selectedMateria])

  console.log("[SelectQuizz] Materias recibidas:", materiaList.length);

  const sortedQuizzList = useMemo(
    () => [...quizzList].sort((a, b) => (a.title || "").localeCompare(b.title || "")),
    [quizzList],
  )

  const handleSelect = (id: string) => () => {
    if (selected === id) {
      setSelected(null)
    } else {
      setSelected(id)
    }
  }

  const handleSubmit = () => {
    if (!selected) {
      toast.error("Please select a quizz")

      return
    }

    onSelect(selected)
  }

  const handleCreate = () => {
    const trimmedTitle = quizName.trim()

    if (!trimmedTitle) {
      toast.error("Please enter a quiz name")

      return
    }

    const materia = materiaList.find(m => m.id === selectedMateria);
    const materiaName = materia ? materia.nombre : "General";

    onCreate(trimmedTitle, materiaName, materia?.id)
    setQuizName("")
  }

  const handleDelete = (id: string) => () => {
    const quizz = quizzList.find((item) => item.id === id)

    if (!quizz) {
      return
    }

    const confirmed = window.confirm(
      `Delete "${quizz.title}"? This removes it from your account.`,
    )

    if (!confirmed) {
      return
    }

    if (selected === id) {
      setSelected(null)
    }

    onDelete(id)
  }

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Enter") {
      handleCreate()
    }
  }

  return (
    <div className="z-10 flex w-full max-w-2xl flex-col gap-5 rounded-md bg-white p-4 shadow-sm md:p-6">
      <div className="flex flex-col gap-3">
        <h1 className="text-2xl font-bold">Manage quizzes</h1>
        
        <div className="flex flex-col gap-2">
          <label className="text-sm font-semibold text-gray-700">Seleccionar Materia:</label>
          <select 
            value={selectedMateria} 
            onChange={(e) => setSelectedMateria(e.target.value ? Number(e.target.value) : "")}
            className="w-full p-2 border rounded-md bg-gray-50 outline-primary text-black"
          >
            {materiaList.map(m => (
              <option key={m.id} value={m.id}>{m.nombre}</option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2 md:flex-row mt-2">
          <Input
            value={quizName}
            onChange={(e) => setQuizName(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="New quiz name"
            className="flex-1"
          />
          <Button onClick={handleCreate} className="px-4">
            Create quiz
          </Button>
        </div>
      </div>

      <div className="flex flex-col items-center justify-center">
        <div className="mb-2 flex w-full items-center justify-between gap-4">
          <h2 className="text-xl font-bold">Available quizzes</h2>
          <span className="text-sm font-semibold text-gray-500">
            {sortedQuizzList.length} total
          </span>
        </div>

        <div className="w-full space-y-2">
          {sortedQuizzList.length === 0 && (
            <div className="rounded-md border border-dashed border-gray-300 p-4 text-center text-gray-500">
              No quizzes yet. Create one to get started.
            </div>
          )}

          {sortedQuizzList.map((quizz) => (
            <div
              key={quizz.id}
              className={clsx(
                "flex w-full items-center gap-3 rounded-md p-3 text-left outline outline-gray-300",
              )}
              role="button"
              tabIndex={0}
              onClick={handleSelect(quizz.id)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault()
                  handleSelect(quizz.id)()
                }
              }}
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-lg font-semibold">{quizz.title}</p>
                <p className="text-sm text-gray-500">
                  {quizz.subject} • {quizz.questions.length} questions
                </p>
              </div>

              <div className="flex items-center gap-3">
                <Button
                  type="button"
                  className="bg-white px-3 py-1 text-sm !text-black"
                  onClick={(event) => {
                    event.stopPropagation()
                    onEdit(quizz.id)
                  }}
                >
                  Edit
                </Button>

                <div
                  className={clsx(
                    "h-5 w-5 shrink-0 rounded outline outline-offset-3 outline-gray-300",
                    selected === quizz.id &&
                      "bg-primary border-primary/80 shadow-inset",
                  )}
                ></div>

                <Button
                  type="button"
                  className="bg-red-500 px-3 py-1 text-sm"
                  onClick={(event) => {
                    event.stopPropagation()
                    handleDelete(quizz.id)()
                  }}
                >
                  Delete
                </Button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <Button onClick={handleSubmit}>Start selected quiz</Button>
    </div>
  )
}

export default SelectQuizz
