import {
  SocketProvider,
  useSocket,
} from "@mindbuzz/web/features/game/contexts/socketProvider"
import { useEffect } from "react"
import { Outlet, useLocation, useNavigate } from "react-router"
import { usePlayerStore } from "@mindbuzz/web/features/game/stores/player"
import Button from "@mindbuzz/web/features/game/components/Button"

const GameLayoutWrapped = () => {
  const { socket, isConnected, connect } = useSocket()
  const player = usePlayerStore((state) => state.player)
  const reset = usePlayerStore((state) => state.reset)
  const navigate = useNavigate()
  const { pathname } = useLocation()
  useEffect(() => {
    if (!isConnected) {
      connect()
    }
  }, [connect, isConnected])

  useEffect(() => {
    document.body.classList.add("bg-secondary")

    return () => {
      document.body.classList.remove("bg-secondary")
    }
  }, [])

  useEffect(() => {
    // Protección de rutas: si no es estudiante, forzar /login
    // Ignorar las rutas de manager o si ya estamos en /login
    if (
      !player?.idEstudiante &&
      pathname !== "/login" &&
      !pathname.startsWith("/manager") &&
      !pathname.startsWith("/party/manager")
    ) {
      navigate("/login")
    }
  }, [player?.idEstudiante, pathname, navigate])

  const handleLogout = () => {
    socket?.emit("player:leave")
    reset()
    navigate("/login")
  }

  return (
    <div className="antialiased bg-secondary relative min-h-dvh">
      <Outlet />
      {player?.idEstudiante && 
       pathname !== "/login" && 
       !pathname.startsWith("/manager") && 
       !pathname.startsWith("/party/manager") && (
        <div className="fixed top-6 right-6 z-[9999]">
          <Button 
            onClick={handleLogout} 
            className="!bg-red-600 hover:!bg-red-700 shadow-2xl px-8 py-3 text-xl uppercase tracking-wider"
          >
            Cerrar Sesión
          </Button>
        </div>
      )}
    </div>
  )
}

export const GameLayout = () => (
  <SocketProvider>
    <GameLayoutWrapped />
  </SocketProvider>
)

