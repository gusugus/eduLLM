import { STATUS } from "@mindbuzz/common/types/game/status"
import Button from "@mindbuzz/web/features/game/components/Button"
import Form from "@mindbuzz/web/features/game/components/Form"
import Input from "@mindbuzz/web/features/game/components/Input"
import {
  useEvent,
  useSocket,
} from "@mindbuzz/web/features/game/contexts/socketProvider"
import { usePlayerStore } from "@mindbuzz/web/features/game/stores/player"

import { type KeyboardEvent, useState, useEffect } from "react"
import { useNavigate } from "react-router"
import Loader from "@mindbuzz/web/features/game/components/Loader"

const Username = () => {
  const { socket } = useSocket()
  const { gameId, login, setStatus, player } = usePlayerStore()
  const navigate = useNavigate()
  const [username, setUsername] = useState(player?.fullName || player?.username || "")

  const handleLogin = (e?: React.FormEvent) => {
    e?.preventDefault()
    if (!gameId) {
      return
    }

    socket?.emit("player:login", { gameId, data: { username } })
  }

  useEvent("game:successJoin", (gameId) => {
    setStatus(STATUS.WAIT, { text: "Waiting for the players" })
    login(username, player?.idEstudiante)

    navigate(`/party/${gameId}`)
  })

  return (
    <Form onSubmit={handleLogin}>
      <Input
        value={username}
        onChange={(e) => setUsername(e.target.value)}
        placeholder="Username here"
      />
      <Button onClick={handleLogin}>Submit</Button>
    </Form>
  )
}

export default Username

