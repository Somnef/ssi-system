import { ref } from 'vue'

const user = ref(null)

export function useAuth() {
  async function fetchUser() {
    try {
      const res = await fetch('http://localhost:8081/me', {
        credentials: 'include'
      })
      if (res.ok) {
        user.value = await res.json()
      } else {
        user.value = null
      }
    } catch {
      user.value = null
    }
  }

  async function logout(router) {
    const res = await fetch('http://localhost:8081/logout', {
      method: 'POST',
      credentials: 'include'
    })
    if (res.ok) {
      user.value = null
      router.push('/login')
    }
  }

  return { user, fetchUser, logout }
}
