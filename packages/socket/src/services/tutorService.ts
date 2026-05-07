import { Socket } from "@mindbuzz/common/types/game/socket"

class TutorService {
  private static instance: TutorService | null = null
  private readonly PROXY_URL = "http://localhost:5000"
  
  // Almacenamos las preguntas fallidas por sessionId
  private failedQuestions = new Map<string, any[]>()
  // Almacenamos la materia por sessionId
  private sessionSubjects = new Map<string, string>()

  static getInstance(): TutorService {
    if (!TutorService.instance) {
      TutorService.instance = new TutorService()
    }

    return TutorService.instance
  }

  setSessionSubject(sessionId: string, subject: string) {
    this.sessionSubjects.set(sessionId, subject)
  }

  addFailedQuestion(sessionId: string, questionData: any, subject?: string) {
    if (subject) {
      this.setSessionSubject(sessionId, subject)
    }
    const questions = this.failedQuestions.get(sessionId) || []
    // Evitar duplicados si la lógica del juego reintenta
    if (!questions.find(q => q.question === questionData.question)) {
      questions.push(questionData)
      this.failedQuestions.set(sessionId, questions)
      console.log(`[TutorService] Added failed question context for ${sessionId} (Subject: ${subject || 'N/A'})`)
    }
  }

  getFailedQuestions(sessionId: string) {
    return this.failedQuestions.get(sessionId) || []
  }

  getSessionSubject(sessionId: string) {
    return this.sessionSubjects.get(sessionId) || "General"
  }

  clearFailedQuestions(sessionId: string) {
    this.failedQuestions.delete(sessionId)
    this.sessionSubjects.delete(sessionId)
  }

  async askTutor(socket: Socket, sessionId: string, message: string, history: any[] = [], extraPreguntas?: any[], extraMateria?: string) {
    try {
      console.log(`[TutorService] Asking tutor for session ${sessionId}: ${message} (History: ${history.length} msgs)`)
      
      const failedQuestions = extraPreguntas || this.getFailedQuestions(sessionId)
      const materia = extraMateria || this.getSessionSubject(sessionId)

      const response = await fetch(`${this.PROXY_URL}/chat/${sessionId}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message,
          backend: "llamacpp",
          materia,
          preguntas: failedQuestions,
          history, // Enviamos el historial recibido del cliente
          options: {
            thinking: true
          }
        }),
      })

      if (!response.ok) {
        console.error(`[TutorService] Proxy returned error: ${response.status} ${response.statusText}`)
        throw new Error(`Proxy error: ${response.statusText}`)
      }

      console.log(`[TutorService] Proxy connection successful, starting stream...`)
      
      if (!response.body) {
        throw new Error("No response body from proxy")
      }

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ""

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })
        
        const lines = buffer.split("\n")
        buffer = lines.pop() || ""

        for (const line of lines) {
          if (line.startsWith("event: text_delta")) {
            continue
          }
          
          if (line.startsWith("data: ")) {
            try {
              const data = JSON.parse(line.slice(6))
              if (data.content) {
                socket.emit("tutor:chunk", { content: data.content })
              }
            } catch (e) {
              console.error("[TutorService] Error parsing chunk", e)
            }
          }

          if (line.startsWith("event: completed")) {
            socket.emit("tutor:completed", { status: "done" })
          }
        }
      }
    } catch (error) {
      console.error("[TutorService] Error:", error)
      socket.emit("tutor:error", {
        message: error instanceof Error ? error.message : "Error desconocido en el tutor",
      })
    }
  }
}

export default TutorService
