import { Navigate, useLocation } from "react-router";
import { useEffect, useState } from "react";

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedRoles?: number[];
}

const ProtectedRoute = ({ children, allowedRoles }: ProtectedRouteProps) => {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [userRole, setUserRole] = useState<number | null>(null);
  const location = useLocation();

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem("token");
      if (!token) {
        setIsAuthenticated(false);
        setIsLoading(false);
        return;
      }

      try {
        const response = await fetch("/auth/status", {
          headers: {
            "Authorization": `Bearer ${token}`,
            "Accept": "application/json"
          }
        });

        if (response.ok) {
          const data = await response.json();
          setIsAuthenticated(true);
          setUserRole(data.user.id_rol);
        } else {
          localStorage.removeItem("token");
          setIsAuthenticated(false);
        }
      } catch (error) {
        console.error("Auth check failed", error);
        setIsAuthenticated(false);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, [location]);

  if (isLoading) {
    return <div className="flex min-h-screen items-center justify-center text-white">Cargando...</div>;
  }

  if (!isAuthenticated) {
    // Guardamos la intención original para volver tras el login
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles && userRole !== null && !allowedRoles.includes(userRole)) {
    // Si está logueado pero no tiene el rol, mandarlo a su página principal
    return <Navigate to={userRole === 1 ? "/" : "/manager"} replace />;
  }

  return <>{children}</>;
};

export default ProtectedRoute;
