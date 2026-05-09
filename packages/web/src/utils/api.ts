/**
 * Wrapper de fetch que inyecta automáticamente el token JWT
 */
export async function apiFetch(url: string, options: RequestInit = {}) {
  const token = localStorage.getItem("token");

  const headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
    ...options.headers,
  } as any;

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  // Si el servidor nos dice que el token ya no es válido (401)
  if (response.status === 401) {
    localStorage.removeItem("token");
    // Podrías redirigir a login aquí si fuera necesario
  }

  return response;
}
