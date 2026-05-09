import { Request, Response, NextFunction } from "express";
import passport from "passport";

// 1. Guardia de autenticación por JWT
export function ensureAuthenticated(req: Request, res: Response, next: NextFunction) {
  passport.authenticate("jwt", { session: false }, (err: any, user: any, info: any) => {
    if (err) return next(err);
    
    if (!user) {
      return res.status(401).json({ 
        success: false, 
        error: "No autenticado o token inválido",
        details: info?.message 
      });
    }
    
    // Adjuntamos el usuario al request para los siguientes middlewares
    req.user = user;
    next();
  })(req, res, next);
}

// 2. Fábrica de guardias por rol
export function requireRole(roleId: number) {
  return (req: Request, res: Response, next: NextFunction) => {
    // Primero aseguramos que esté autenticado
    ensureAuthenticated(req, res, () => {
      const user = req.user as any;
      if (user && user.id_rol === roleId) {
        return next();
      }
      
      res.status(403).json({ 
        success: false, 
        error: "No tienes permisos suficientes (Rol requerido: " + roleId + ")" 
      });
    });
  };
}

// 3. Guardia para múltiples roles
export function requireAnyRole(roleIds: number[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    ensureAuthenticated(req, res, () => {
      const user = req.user as any;
      if (user && roleIds.includes(user.id_rol)) {
        return next();
      }
      
      res.status(403).json({ success: false, error: "No tienes permisos suficientes" });
    });
  };
}
