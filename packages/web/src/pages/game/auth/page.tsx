import Room from "@mindbuzz/web/features/game/components/join/Room"
import Username from "@mindbuzz/web/features/game/components/join/Username"
import {
  useEvent,
  useSocket,
} from "@mindbuzz/web/features/game/contexts/socketProvider"
import { usePlayerStore } from "@mindbuzz/web/features/game/stores/player"
import { useEffect } from "react"
import toast from "react-hot-toast"

const PlayerAuthPage = () => {
  const { isConnected, connect } = useSocket()
  const { player, gameId, reset } = usePlayerStore()

  useEffect(() => {
    // Si al cargar esta página detectamos que ya hay un username guardado,
    // es una sesión de una partida anterior. La limpiamos para pedir el PIN de nuevo.
    if (player?.username) {
      reset()
    }
  }, [])

  useEffect(() => {
    // Si tenemos el estado de 'player' pero no hay gameId, es un estado inconsistente.
    if (player && !gameId) {
      reset()
    }
  }, [player, gameId, reset])

  useEffect(() => {
    if (!isConnected) {
      connect()
    }
  }, [connect, isConnected])

  useEvent("game:errorMessage", (message) => {
    toast.error(message)
  })

  // Solo muestra Username si hay gameId, asegurando que pasó por el PIN primero.
  if (player && gameId) {
    return <Username />
  }

  return <Room />
}

export default PlayerAuthPage

