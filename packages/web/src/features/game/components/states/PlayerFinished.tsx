import type { CommonStatusDataMap } from "@mindbuzz/common/types/game/status"
import Button from "@mindbuzz/web/features/game/components/Button"
import { usePlayerStore } from "@mindbuzz/web/features/game/stores/player"
import { useSocket } from "@mindbuzz/web/features/game/contexts/socketProvider"

type Props = {
  data: CommonStatusDataMap["FINISHED"]
}

const PlayerFinished = ({ data: { subject } }: Props) => {
  const { player } = usePlayerStore()
  const { clientId } = useSocket()

  const handleTalkToTutor = () => {
    // Abrir la página del tutor pasando el clientId
    window.open(`/tutor-test.html?clientId=${clientId}`, "_blank")
  }

  return (
    <section className="anim-show relative mx-auto flex w-full max-w-2xl flex-1 flex-col items-center justify-center px-4 text-center">
      <h2 className="mb-4 text-4xl font-bold text-white drop-shadow-lg sm:text-5xl">
        ¡Quiz Terminado!
      </h2>
      <div className="mb-8 w-full rounded-xl bg-black/40 p-8 shadow-2xl backdrop-blur-sm">
        <h3 className="mb-2 text-2xl font-bold text-amber-400 drop-shadow-md">
          {subject}
        </h3>
        <p className="text-xl text-white">
          Puntuación final: <span className="font-bold text-3xl ml-2">{player?.points || 0}</span>
        </p>
      </div>
      
      <Button
        className="w-full max-w-sm bg-indigo-500 hover:bg-indigo-600 !text-white shadow-lg transition-transform hover:scale-105"
        onClick={handleTalkToTutor}
      >
        Hablar con el Profesor IA
      </Button>
    </section>
  )
}

export default PlayerFinished
