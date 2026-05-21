import Button from "@mindbuzz/web/features/game/components/Button"
import Form from "@mindbuzz/web/features/game/components/Form"
import Input from "@mindbuzz/web/features/game/components/Input"
import { usePlayerStore } from "@mindbuzz/web/features/game/stores/player"
import { useState } from "react"
import toast from "react-hot-toast"
import { useNavigate } from "react-router"
import { useSocket } from "@mindbuzz/web/features/game/contexts/socketProvider"

const StudentLoginPage = () => {
  const [username, setUsername] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const { login } = usePlayerStore()
  const { reconnect } = useSocket()

  const handleLogin = async (e?: React.FormEvent) => {
    e?.preventDefault()
    if (!username || !password) {
      toast.error("Por favor, ingresa tu usuario y contraseña")
      return
    }

    setLoading(true)
    try {
      const response = await fetch("/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({ username, password }),
      })

      const data = await response.json()

      if (!response.ok || !data.success) {
        toast.error(data.error || "Credenciales incorrectas")
      } else {
        toast.success("¡Bienvenido!")
        
        // GUARDAR TOKEN
        localStorage.setItem("token", data.token)
        reconnect()

        // Passport devuelve los datos dentro de data.user
        login({ 
          ...data.user, 
          idEstudiante: data.user.id,
          success: true 
        })

        // Redirección inteligente por rol
        if (data.user.id_rol === 1) {
          navigate("/") // Estudiante
        } else if (data.user.id_rol === 2 || data.user.id_rol === 3) {
          navigate("/manager") // Profesor o Admin
        }
      }
    } catch (err) {
      console.error(err)
      toast.error("Error al conectar con el servidor .")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex w-full max-w-sm flex-col items-center justify-center space-y-6">
      <div className="text-center">
        <h2 className="text-3xl font-bold text-purple-300 mb-2">Panel de Login</h2>
        <p className="text-purple/80">Ingrese</p>
      </div>
      
      <Form onSubmit={handleLogin}>
        <Input
          placeholder="Usuario"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          disabled={loading}
        />
        <Input
          type="password"
          placeholder="Contraseña"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={loading}
        />
        <Button onClick={handleLogin} disabled={loading}>
          {loading ? "Cargando..." : "Entrar"}
        </Button>
      </Form>
    </div>
  )
}

export default StudentLoginPage
