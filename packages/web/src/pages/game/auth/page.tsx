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
    if (player?.username && !player?.idEstudiante) {
      reset()
    } else if (player?.idEstudiante && gameId) {
      // Limpiamos el gameId para que ingrese un nuevo PIN
      usePlayerStore.setState({ gameId: null, status: null })
    }
  }, [])

  useEffect(() => {
    // Si tenemos el estado de 'player' pero no hay gameId,
    // y NO es un estudiante, es un estado inconsistente.
    if (player && !player.idEstudiante && !gameId) {
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

