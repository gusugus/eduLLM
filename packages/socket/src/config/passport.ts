import passport from "passport";
import { Strategy as LocalStrategy } from "passport-local";
import { Strategy as JwtStrategy, ExtractJwt } from "passport-jwt";
import bcrypt from "bcryptjs";
import { pgPool } from "../services/pgDatabase.js";

// Definimos el tipo de usuario para TypeScript
export interface ExpressUser {
  id: number;
  username: string;
  id_rol: number;
  fullName: string;
}

const JWT_SECRET = process.env.JWT_SECRET || "mindbuzz-jwt-secret-key-2026";

export function configurePassport() {
  // 1. ESTRATEGIA LOCAL: Para el login inicial (intercambio de credenciales por token)
  passport.use(
    new LocalStrategy(
      {
        usernameField: "username",
        passwordField: "password",
      },
      async (username, password, done) => {
        try {
          // Llamar a la función fn_login de la base de datos
          const res = await pgPool.query("SELECT * FROM comun.fn_login($1)", [username]);

          if (res.rowCount === 0 || !res.rows[0]) {
            return done(null, false, { message: "Usuario o contraseña incorrectos" });
          }

          const dbUser = res.rows[0];

          // Verificación de la contraseña usando bcrypt
          const isValid = await bcrypt.compare(password || "", dbUser.password_hash);

          if (!isValid) {
            return done(null, false, { message: "Usuario o contraseña incorrectos" });
          }

          // Calculamos el nombre completo
          const partesNombre = [
            dbUser.primer_nombre,
            dbUser.apellido_paterno,
            dbUser.apellido_materno
          ].filter(Boolean);
          
          const fullName = partesNombre.length > 0 ? partesNombre.join(" ") : username;

          const user: ExpressUser = {
            id: dbUser.id_usuario,
            username: username,
            id_rol: dbUser.id_rol,
            fullName: fullName
          };

          return done(null, user);
        } catch (err) {
          return done(err);
        }
      }
    )
  );

  // 2. ESTRATEGIA JWT: Para validar todas las peticiones subsiguientes
  passport.use(
    new JwtStrategy(
      {
        jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
        secretOrKey: JWT_SECRET,
      },
      async (jwtPayload, done) => {
        try {
          // El payload contiene los datos que firmamos en el token
          if (jwtPayload && jwtPayload.id) {
            return done(null, jwtPayload);
          }
          return done(null, false);
        } catch (error) {
          return done(error, false);
        }
      }
    )
  );

  // NOTA: Con JWT ya no necesitamos serializeUser/deserializeUser si somos totalmente stateless,
  // pero los mantenemos por si alguna parte del sistema aún usa sesiones de Express temporalmente.
  passport.serializeUser((user: any, done) => {
    done(null, user);
  });

  passport.deserializeUser((user: any, done) => {
    done(null, user);
  });
}
