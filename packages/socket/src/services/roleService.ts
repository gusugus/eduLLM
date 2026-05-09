import { pgPool } from "./pgDatabase.js";

export interface Role {
  id: number;
  nombre: string;
}

class RoleService {
  private roles: Map<string, number> = new Map();
  private rolesById: Map<number, string> = new Map();

  async init() {
    try {
      const res = await pgPool.query("SELECT id_rol, nombre FROM comun.ADMIN_ROL");
      res.rows.forEach((row: any) => {
        // Normalizamos a mayúsculas para evitar errores (ESTUDIANTE, PROFESOR, ADMINISTRADOR)
        const nombre = row.nombre.toUpperCase();
        this.roles.set(nombre, row.id_rol);
        this.rolesById.set(row.id_rol, nombre);
      });
      console.log("Roles cargados desde la base de datos:", Object.fromEntries(this.roles));
    } catch (err) {
      console.error("Error al cargar roles desde la base de datos:", err);
    }
  }

  getRoleId(roleName: string): number | undefined {
    return this.roles.get(roleName.toUpperCase());
  }

  getRoleName(roleId: number): string | undefined {
    return this.rolesById.get(roleId);
  }

  // Helpers rápidos
  get ESTUDIANTE() { return this.getRoleId("ESTUDIANTE") || 1; }
  get PROFESOR() { return this.getRoleId("PROFESOR") || 2; }
  get ADMIN() { return this.getRoleId("ADMINISTRADOR") || 3; }
}

export const roleService = new RoleService();
