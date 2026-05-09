import AuthLayout from "@mindbuzz/web/pages/game/auth/layout"
import PlayerAuthPage from "@mindbuzz/web/pages/game/auth/page"
import StudentLoginPage from "@mindbuzz/web/pages/game/auth/studentLogin/page"
import { GameLayout } from "@mindbuzz/web/pages/game/layout"
import { createBrowserRouter, RouterProvider } from "react-router"
import AuthManagerPage from "./pages/game/auth/manager/page"
import ManagerGamePage from "./pages/game/party/manager/page"
import PlayerGamePage from "./pages/game/party/page"
import ProtectedRoute from "./features/game/components/ProtectedRoute"

const router = createBrowserRouter([
  {
    path: "/",
    element: <GameLayout />,
    children: [
      {
        path: "/",
        element: <AuthLayout />,
        children: [
          {
            path: "/",
            element: <PlayerAuthPage />,
          },
          {
            path: "/login",
            element: <StudentLoginPage />,
          },
          {
            path: "/manager",
            element: (
              <ProtectedRoute allowedRoles={[2, 3]}>
                <AuthManagerPage />
              </ProtectedRoute>
            ),
          },
        ],
      },
      {
        path: "/party/:gameId",
        element: <PlayerGamePage />,
      },
      {
        path: "/party/manager/:gameId",
        element: <ManagerGamePage />,
      },
    ],
  },
])

const Router = () => <RouterProvider router={router} />

export default Router

