// RECARGA FORZADA - DEPURACION DE MATERIAS
import type { ManagerSession, Quizz } from "@mindbuzz/common/types/game"
import { Server, Socket } from "@mindbuzz/common/types/game/socket"
import { inviteCodeValidator } from "@mindbuzz/common/validators/auth"
import AccountStore from "@mindbuzz/socket/services/accountStore"
import Config from "@mindbuzz/socket/services/config"
import Game from "@mindbuzz/socket/services/game"
import History from "@mindbuzz/socket/services/history"
import OidcAuth from "@mindbuzz/socket/services/oidcAuth"
import Registry from "@mindbuzz/socket/services/registry"
import TutorService from "@mindbuzz/socket/services/tutorService"
import { withGame } from "@mindbuzz/socket/utils/game"
import flash from "connect-flash"
import pgSession from "connect-pg-simple"
import cookieParser from "cookie-parser"
import express from "express"
import session from "express-session"
import fs from "fs"
import { createServer } from "http"
import jwt from "jsonwebtoken"
import passport from "passport"
import { extname, relative, resolve } from "path"
import { Server as ServerIO } from "socket.io"
import { configurePassport } from "./config/passport.js"
import { materiaRepository } from "./repositories/materiaRepository.js"
import { quizzRepository } from "./repositories/quizzRepository.js"
import authRoutes from "./routes/auth.js"
import { initPg, pgPool } from "./services/pgDatabase.js"
import { roleService } from "./services/roleService.js"

const JWT_SECRET = process.env.JWT_SECRET || "mindbuzz-jwt-secret-key-2026";

const WS_PORT = 3001

const mimeTypes: Record<string, string> = {
  ".aac": "audio/aac",
  ".mp3": "audio/mpeg",
  ".m4a": "audio/mp4",
  ".ogg": "audio/ogg",
  ".wav": "audio/wav",
  ".webm": "audio/webm",
}

const getMimeType = (filename: string) =>
  mimeTypes[extname(filename).toLowerCase()] ?? "application/octet-stream"

const sendJson = (
  res: ServerResponse<IncomingMessage>,
  statusCode: number,
  body: unknown,
) => {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  })
  res.end(JSON.stringify(body))
}

const getRequestOrigin = (req: IncomingMessage) => {
  const forwardedProto = req.headers["x-forwarded-proto"]
  const protocol = Array.isArray(forwardedProto)
    ? forwardedProto[0]
    : forwardedProto ?? "http"
  const host = req.headers["x-forwarded-host"] ?? req.headers.host ?? "localhost"

  return `${protocol}://${host}`
}

const buildManagerRedirect = (
  origin: string,
  returnTo: string | undefined,
  params: Record<string, string>,
) => {
  const redirectTarget = new URL(returnTo && returnTo.startsWith("/") ? returnTo : "/manager", origin)

  Object.entries(params).forEach(([key, value]) => {
    redirectTarget.searchParams.set(key, value)
  })

  return redirectTarget.toString()
}

const app = express();
const httpServer = createServer(app);

// Configuración de Passport
configurePassport();

// Middlewares básicos
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Configuración de Sesiones en PostgreSQL
const PostgresStore = pgSession(session);
app.use(
  session({
    store: new PostgresStore({
      pool: pgPool,
      schemaName: "comun",
      tableName: "sessions",
      createTableIfMissing: true,
    }),
    secret: process.env.SESSION_SECRET || "mindbuzz-secret-key",
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 30 * 24 * 60 * 60 * 1000,
      secure: process.env.NODE_ENV === "production",
    },
  })
);

// Inicializar Passport
app.use(passport.initialize());
app.use(passport.session());
app.use(flash());

// CORS manual (puedes usar el paquete 'cors' si prefieres)
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") {
    return res.sendStatus(204);
  }
  next();
});

// Rutas de Autenticación
app.use("/auth", authRoutes);

// Rutas OIDC existentes (migradas a Express)
app.get("/auth/oidc/status", (req, res) => {
  res.json(OidcAuth.status());
});

app.get("/auth/oidc/login", (req, res) => {
  const clientId = (req.query.clientId as string)?.trim() ?? "";
  const returnTo = (req.query.returnTo as string) ?? "/manager";

  if (!clientId) {
    return res.status(400).send("clientId is required");
  }

  const origin = `${req.protocol}://${req.get("host")}`;
  const redirectUri = new URL("/auth/oidc/callback", origin).toString();

  OidcAuth.buildAuthorizationUrl({ clientId, returnTo, redirectUri })
    .then((authorizationUrl) => {
      res.redirect(authorizationUrl);
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : "Failed to start SSO login";
      const redirectUrl = buildManagerRedirect(origin, returnTo, { oidc: "error", message });
      res.redirect(redirectUrl);
    });
});

app.get("/auth/oidc/callback", (req, res) => {
  const code = req.query.code as string;
  const state = req.query.state as string;
  const origin = `${req.protocol}://${req.get("host")}`;
  const redirectUri = new URL("/auth/oidc/callback", origin).toString();

  if (!code || !state) {
    const redirectUrl = buildManagerRedirect(origin, "/manager", {
      oidc: "error",
      message: "Missing OIDC callback parameters",
    });
    return res.redirect(redirectUrl);
  }

  OidcAuth.handleCallback({ code, state, redirectUri })
    .then((returnTo) => {
      const redirectUrl = buildManagerRedirect(origin, returnTo, { oidc: "success" });
      res.redirect(redirectUrl);
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : "Failed to complete SSO login";
      const redirectUrl = buildManagerRedirect(origin, "/manager", { oidc: "error", message });
      res.redirect(redirectUrl);
    });
});

// Servir archivos estáticos (media)
app.get("/media/*", (req, res) => {
  const mediaDirectory = Config.mediaDirectory();
  const relativePath = decodeURIComponent(req.path.slice("/media/".length));
  const filePath = resolve(mediaDirectory, relativePath);
  const pathFromMediaRoot = relative(mediaDirectory, filePath);

  if (
    !relativePath ||
    pathFromMediaRoot.startsWith("..") ||
    !fs.existsSync(filePath) ||
    !fs.statSync(filePath).isFile()
  ) {
    return res.status(404).send("Not found");
  }

  res.setHeader("Content-Type", getMimeType(filePath));
  res.setHeader("Cache-Control", "public, max-age=3600");
  fs.createReadStream(filePath).pipe(res);
});

// Manejador de errores global
app.use((err: any, req: any, res: any, next: any) => {
  console.error("Express Error:", err);
  res.status(500).json({ 
    success: false, 
    error: "Internal Server Error", 
    message: err.message
  });
});

const io: Server = new ServerIO(httpServer, {
  path: "/ws",
  maxHttpBufferSize: 25 * 1024 * 1024,
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
})

// Middleware de Socket.io para validar JWT
io.use((socket, next) => {
  try {
    // Intentamos obtener el token de auth.token o del header Authorization
    let token = socket.handshake.auth?.token;
    
    if (!token && socket.handshake.headers?.authorization) {
      const parts = socket.handshake.headers.authorization.split(" ");
      if (parts.length === 2 && parts[0] === "Bearer") {
        token = parts[1];
      }
    }

    if (!token) {
      return next();
    }

    jwt.verify(token, JWT_SECRET, (err: any, decoded: any) => {
      if (err) {
        console.error("JWT Verification Error:", err.message);
        return next(new Error("Authentication error"));
      }
      
      // Guardamos el usuario en data.user
      socket.data.user = decoded;
      (socket as any).user = decoded; 
      next();
    });
  } catch (error) {
    console.error("Socket Auth Middleware Error:", error);
    next(new Error("Internal Server Error during Auth"));
  }
});

Config.init()
AccountStore.init()
History.init()
initPg() 
roleService.init() 

httpServer.listen(WS_PORT, () => {
  console.log(`Socket server running on port ${WS_PORT}`)
})

const registry = Registry.getInstance()
const authenticatedManagers = new Map<string, ManagerSession>()

const getSocketClientId = (socket: { handshake: { auth: { clientId?: string } } }) =>
  socket.handshake.auth.clientId ?? ""

const getAuthenticatedManager = (socket: Socket) => {
  const user = socket.data.user as any;
  // Verificamos que sea profesor (rol 2) o admin (rol 3)
  if (user && (user.id_rol === roleService.PROFESOR || user.id_rol === roleService.ADMIN)) {
    return user;
  }
  return null;
}

const requireAuthenticatedManager = (socket: Socket) => {
  const manager = getAuthenticatedManager(socket)

  if (!manager) {
    console.log(`[Auth] Intento de acceso sin autenticación desde socket: ${socket.id}`);
    socket.emit("manager:errorMessage", "Manager authentication required")
  } else {
    console.log(`[Auth] Manager autenticado detectado: ${manager.username} (ID: ${manager.id})`);
  }

  return manager
}

const requireAdminManager = (socket: Socket) => {
  const manager = requireAuthenticatedManager(socket)

  if (!manager) {
    return null
  }

  if (manager.role !== "admin") {
    socket.emit("manager:errorMessage", "Admin access required")

    return null
  }

  return manager
}

const emitBootstrapState = (socket: Socket) => {
  socket.emit("manager:bootstrapState", {
    requiresSetup: AccountStore.isBootstrapRequired(),
  })
}

const emitManagerDashboard = async (socket: Socket, manager: any) => {
  const clientId = getSocketClientId(socket)
  const activeGame = registry.getGameByManagerAccountId(manager.id)

  try {
    console.log(`[Dashboard] Cargando datos para manager: ${manager.username} (ID: ${manager.id})`);

    // Emitir autenticación primero
    socket.emit("manager:authSuccess", { manager })
    socket.emit("manager:historyList", History.listRuns(manager.id))
    socket.emit("manager:settings", AccountStore.getManagerSettings(manager.id))
    socket.emit(
      "manager:activeGame",
      activeGame ? activeGame.getActiveManagerGame(clientId) : null,
    )
    socket.emit("manager:oidcStatus", OidcAuth.status())

    // Cargar y emitir materias
    try {
      const materias = await materiaRepository.listByProfessor(manager.id)
      console.log(`[Dashboard] Materias encontradas: ${materias.length}`);
      socket.emit("manager:materiaList", materias)
    } catch (errorMaterias) {
      console.error("[Dashboard] Error cargando materias:", errorMaterias)
      socket.emit("manager:materiaList", [])
    }

    // Cargar y emitir quizzes
    try {
      const quizzes = await quizzRepository.listByProfessor(manager.id)
      console.log(`[Dashboard] Quizzes encontrados: ${quizzes.length}`);
      socket.emit("manager:quizzList", quizzes)
    } catch (errorQuizzes) {
      console.error("[Dashboard] Error cargando quizzes:", errorQuizzes)
      socket.emit("manager:quizzList", [])
    }

  } catch (error) {
    console.error("[Dashboard] Error general:", error)
    socket.emit("manager:errorMessage", "Error al cargar datos del profesor")
  }

  if (manager.id_rol === 3) { // Admin role check
    socket.emit("manager:managersList", AccountStore.listManagers())
  } else {
    socket.emit("manager:managersList", [])
  }
}

const revokeControlledGameForClient = (clientId: string, reason: string) => {
  const game = registry
    .getAllGames()
    .find((item) => item.manager.clientId === clientId)

  if (!game) {
    return
  }

  if (!game.started) {
    game.abortCooldown()
    game.clearPendingPlayerRemovals()
    io.to(game.gameId).emit("game:reset", reason)
    registry.removeGame(game.gameId)

    return
  }

  game.revokeManagerControl(reason)
  registry.markGameAsEmpty(game)
}

const revokeManagerAccountAccess = (managerId: string, reason: string) => {
  authenticatedManagers.forEach((manager, clientId) => {
    if (manager.id === managerId) {
      authenticatedManagers.delete(clientId)
    }
  })

  const activeGame = registry.getGameByManagerAccountId(managerId)

  if (!activeGame) {
    return
  }

  if (!activeGame.started) {
    activeGame.abortCooldown()
    activeGame.clearPendingPlayerRemovals()
    io.to(activeGame.gameId).emit("game:reset", reason)
    registry.removeGame(activeGame.gameId)

    return
  }

  activeGame.terminate(reason)
}

io.on("connection", (socket) => {
  const user = socket.data.user;
  console.log(
    `A user connected: socketId: ${socket.id}, clientId: ${socket.handshake.auth.clientId}, User: ${user ? user.username : 'Guest'}`,
  )

  socket.on("manager:getBootstrapState", () => {
    emitBootstrapState(socket)
  })

  // ELIMINADO: manager:auth (Ahora se hace por HTTP /auth/login)
  
  socket.on("manager:completeOidcLogin", () => {
    const clientId = getSocketClientId(socket)
    const handoff = OidcAuth.consumeLoginHandoff(clientId)

    if (!handoff) {
      socket.emit("manager:errorMessage", "No pending SSO login was found")

      return
    }

    authenticatedManagers.set(clientId, handoff.manager)
    emitManagerDashboard(socket, handoff.manager)
  })

  socket.on("manager:getDashboard", async () => {
    console.log(`[Socket] Recibido manager:getDashboard de ${socket.id}`);
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    await emitManagerDashboard(socket, manager)
  })

  socket.on("manager:logout", () => {
    const clientId = getSocketClientId(socket)

    // Con JWT el logout es simplemente descartar el token en el cliente.
    // Aquí solo revocamos el control del juego si existe.
    revokeControlledGameForClient(clientId, "Manager logged out")
  })

  socket.on("manager:listManagers", () => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    socket.emit("manager:managersList", AccountStore.listManagers())
  })

  socket.on("manager:getOidcConfig", () => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    socket.emit("manager:oidcConfig", Config.oidc())
    socket.emit("manager:oidcStatus", OidcAuth.status())
  })

  socket.on("manager:updateOidcConfig", (settings) => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    try {
      const nextConfig = Config.updateOidc(settings)

      socket.emit("manager:oidcConfig", nextConfig)
      socket.emit("manager:oidcConfigSaved", nextConfig)
      socket.emit("manager:oidcStatus", OidcAuth.status())
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to update SSO settings",
      )
    }
  })

  socket.on("manager:testOidcConfig", (settings) => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    OidcAuth.testConfiguration(settings)
      .then((result) => {
        socket.emit("manager:oidcConfigTested", result)
      })
      .catch((error) => {
        socket.emit(
          "manager:errorMessage",
          error instanceof Error ? error.message : "Failed to test SSO settings",
        )
      })
  })

  socket.on("manager:createManager", ({ username, password }) => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    try {
      const createdManager = AccountStore.createManager(username, password)

      socket.emit("manager:managerCreated", createdManager)
      socket.emit("manager:managersList", AccountStore.listManagers())
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to create manager",
      )
    }
  })

  socket.on("manager:resetManagerPassword", ({ managerId, password }) => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    try {
      const updatedManager = AccountStore.resetManagerPassword(managerId, password)

      socket.emit("manager:managerUpdated", updatedManager)
      socket.emit("manager:managersList", AccountStore.listManagers())
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to reset password",
      )
    }
  })

  socket.on("manager:setManagerDisabled", ({ managerId, disabled }) => {
    const manager = requireAdminManager(socket)

    if (!manager) {
      return
    }

    if (manager.id === managerId) {
      socket.emit("manager:errorMessage", "You cannot disable your own account")

      return
    }

    try {
      const updatedManager = AccountStore.setManagerDisabled(managerId, disabled)

      if (disabled) {
        revokeManagerAccountAccess(managerId, "Your account has been disabled")
      }

      socket.emit("manager:managerUpdated", updatedManager)
      socket.emit("manager:managersList", AccountStore.listManagers())
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to update manager",
      )
    }
  })

  socket.on("game:create", async (quizzId) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    const activeGame = registry.getGameByManagerAccountId(manager.id)

    if (activeGame) {
      socket.emit("manager:errorMessage", "You already have an active game")
      socket.emit(
        "manager:activeGame",
        activeGame.getActiveManagerGame(getSocketClientId(socket)),
      )

      return
    }

    try {
      const quizzes = await quizzRepository.listByProfessor(manager.id)
      const quizz = quizzes.find(q => q.id === quizzId)

      if (!quizz) {
        socket.emit("game:errorMessage", "Quiz not found")
        return
      }

      const game = new Game(
        io,
        socket,
        manager,
        quizz,
        AccountStore.getManagerSettings(manager.id),
      )

      registry.addGame(game)
      socket.emit(
        "manager:activeGame",
        game.getActiveManagerGame(getSocketClientId(socket)),
      )
    } catch (error) {
      socket.emit("game:errorMessage", "Error al crear partida")
    }
  })

  socket.on("manager:createQuizz", async ({ title, subject, materiaId }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      const quizz: Quizz = { title, subject, materiaId, questions: [] }
      console.log("CREANDO QUIZ", quizz);
      const id = await quizzRepository.create(quizz, manager.id)
      const quizzWithId = { ...quizz, id }
      
      socket.emit("manager:quizzCreated", quizzWithId)
      const quizzes = await quizzRepository.listByProfessor(manager.id)
      socket.emit("manager:quizzList", quizzes)
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to create quiz",
      )
    }
  })

  socket.on("manager:updateQuizz", async ({ quizzId, quizz }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      await quizzRepository.update(quizzId, quizz)
      socket.emit("manager:quizzUpdated", { ...quizz, id: quizzId })
      const quizzes = await quizzRepository.listByProfessor(manager.id)
      socket.emit("manager:quizzList", quizzes)
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to update quiz",
      )
    }
  })

  socket.on("manager:deleteQuizz", async ({ quizzId }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      await quizzRepository.delete(quizzId)
      socket.emit("manager:quizzDeleted", quizzId)
      const quizzes = await quizzRepository.listByProfessor(manager.id)
      socket.emit("manager:quizzList", quizzes)
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to delete quiz",
      )
    }
  })

  socket.on("manager:updateSettings", (settings) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      const nextSettings = AccountStore.updateManagerSettings(manager.id, settings)
      socket.emit("manager:settings", nextSettings)
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to update settings",
      )
    }
  })

  socket.on("manager:uploadMedia", ({ filename, content }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      const url = Config.uploadMedia(filename, content)
      socket.emit("manager:mediaUploaded", { url })
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to upload audio file",
      )
    }
  })

  socket.on("manager:downloadHistory", ({ runId }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    try {
      socket.emit(
        "manager:historyExportReady",
        History.exportCsv(manager.id, runId),
      )
    } catch (error) {
      socket.emit(
        "manager:errorMessage",
        error instanceof Error ? error.message : "Failed to export history",
      )
    }
  })

  socket.on("manager:reconnect", ({ gameId }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      socket.emit("game:reset", "Manager authentication required")

      return
    }

    const game = registry.getGameById(gameId)

    if (!game || !game.isOwnedByManager(manager.id)) {
      socket.emit("game:reset", "Game expired")

      return
    }

    game.reconnect(socket)
  })

  socket.on("manager:takeOverGame", ({ gameId }) => {
    const manager = requireAuthenticatedManager(socket)

    if (!manager) {
      return
    }

    const game = registry.getGameById(gameId)

    if (!game || !game.isOwnedByManager(manager.id)) {
      socket.emit("manager:errorMessage", "Game not found")

      return
    }

    game.takeOverManager(socket)
    socket.emit(
      "manager:activeGame",
      game.getActiveManagerGame(getSocketClientId(socket)),
    )
  })

  socket.on("player:reconnect", ({ gameId }) => {
    const game = registry.getPlayerGame(gameId, socket.handshake.auth.clientId)

    if (game) {
      game.reconnect(socket)

      return
    }

    socket.emit("game:reset", "Game not found")
  })

  socket.on("player:join", (inviteCode) => {
    const result = inviteCodeValidator.safeParse(inviteCode)

    if (!result.success) {
      socket.emit("game:errorMessage", result.error.issues[0].message)

      return
    }

    const game = registry.getGameByInviteCode(inviteCode)

    if (!game) {
      socket.emit("game:errorMessage", "Game not found")

      return
    }

    socket.emit("game:successRoom", game.gameId)
  })

  socket.on("player:login", ({ gameId, data }) =>
    withGame(gameId, socket, (game) => game.join(socket, data.username)),
  )

  socket.on("player:leave", () => {
    const game = registry.getGameByPlayerSocketId(socket.id)
    if (game) {
      game.leave(socket)
    }
  })

  socket.on("manager:kickPlayer", ({ gameId, playerId }) =>
    withGame(gameId, socket, (game) => game.kickPlayer(socket, playerId)),
  )

  socket.on("manager:startGame", ({ gameId }) =>
    withGame(gameId, socket, (game) => game.start(socket)),
  )

  socket.on("player:selectedAnswer", ({ gameId, data }) =>
    withGame(gameId, socket, (game) =>
      game.selectAnswer(socket, data.answerKey),
    ),
  )

  socket.on("tutor:ask", ({ sessionId, message, history, preguntas, materia }) => {
    TutorService.getInstance().askTutor(socket, sessionId, message, history, preguntas, materia)
  })

  socket.on("tutor:getFailedQuestions", ({ sessionId }) => {
    const failedQuestions = TutorService.getInstance().getFailedQuestions(sessionId)
    socket.emit("tutor:failedQuestions", { questions: failedQuestions })
  })

  socket.on("manager:abortQuiz", ({ gameId }) =>
    withGame(gameId, socket, (game) => game.abortRound(socket)),
  )

  socket.on("manager:nextQuestion", ({ gameId }) =>
    withGame(gameId, socket, (game) => game.nextRound(socket)),
  )

  socket.on("manager:showLeaderboard", ({ gameId }) =>
    withGame(gameId, socket, (game) => game.showLeaderboard()),
  )

  socket.on("manager:endGame", ({ gameId }) =>
    withGame(gameId, socket, (game) => {
      game.endGame(socket)

      const manager = getAuthenticatedManager(socket)

      if (manager) {
        socket.emit("manager:activeGame", null)
      }
    }),
  )

  socket.on("disconnect", () => {
    console.log(`A user disconnected : ${socket.id}`)

    const managerGame = registry.getGameByManagerSocketId(socket.id)

    if (managerGame) {
      managerGame.manager.connected = false
      registry.markGameAsEmpty(managerGame)

      if (!managerGame.started) {
        console.log("Reset game (manager disconnected)")
        managerGame.abortCooldown()
        managerGame.clearPendingPlayerRemovals()
        io.to(managerGame.gameId).emit("game:reset", "Manager disconnected")
        registry.removeGame(managerGame.gameId)

        return
      }
    }

    const game = registry.getGameByPlayerSocketId(socket.id)

    if (!game) {
      return
    }

    const player = game.players.find((item) => item.id === socket.id)

    if (!player) {
      return
    }

    if (!game.started) {
      player.connected = false
      game.schedulePlayerRemoval(player.id)
      io.to(game.gameId).emit("game:totalPlayers", game.players.length)

      console.log(
        `Marked player ${player.username} as disconnected in game ${game.gameId}`,
      )

      return
    }

    player.connected = false
    io.to(game.gameId).emit("game:totalPlayers", game.players.length)
  })
})

process.on("SIGINT", () => {
  Registry.getInstance().cleanup()
  process.exit(0)
})

process.on("SIGTERM", () => {
  Registry.getInstance().cleanup()
  process.exit(0)
})
