import { Router } from "express";
import passport from "passport";
import jwt from "jsonwebtoken";
import { ExpressUser } from "../config/passport.js";
import { roleService } from "../services/roleService.js";
import { ensureAuthenticated, requireRole, requireAnyRole } from "../middlewares/authMiddleware.js";

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || "mindbuzz-jwt-secret-key-2026";

export { ensureAuthenticated, requireRole, requireAnyRole };

router.post("/login", (req, res, next) => {
  // Usamos la estrategia LOCAL para validar credenciales
  passport.authenticate("local", { session: false }, (err: any, user: ExpressUser, info: any) => {
    if (err) {
      return next(err);
    }
    if (!user) {
      return res.status(401).json({ success: false, error: info?.message || "Credenciales inválidas" });
    }

    // Generar el Token JWT
    const token = jwt.sign(
      { 
        id: user.id, 
        username: user.username, 
        id_rol: user.id_rol, 
        fullName: user.fullName 
      },
      JWT_SECRET,
      { expiresIn: "30d" } // El token expira en 30 días
    );

    // Devolvemos el token y los datos del usuario
    return res.json({ 
      success: true, 
      token: token,
      user: {
        id: user.id,
        username: user.username,
        id_rol: user.id_rol,
        fullName: user.fullName
      }
    });
  })(req, res, next);
});

router.get("/status", ensureAuthenticated, (req, res) => {
  res.json({ authenticated: true, user: req.user });
});

export default router;
