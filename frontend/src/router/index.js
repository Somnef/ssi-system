import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import { useAuth } from '@/composables/useAuth'

const { user } = useAuth();

const routes = [
    {
        path: '/',
        name: 'home',
        component: HomeView
    },
    {
        path: '/about',
        name: 'about',
        component: () => import('../views/AboutView.vue')
    },
    {
        path: '/register',
        name: 'register',
        component: () => import('../views/RegisterView.vue')
    },
    {
        path: '/login',
        name: 'login',
        component: () => import('../views/LoginView.vue')
    },
    {
        path: '/dashboard',
        name: 'dashboard',
        component: () => import('../views/DashboardView.vue'),
    },
    {
        path: '/admin',
        name: 'admin',
        component: () => import('../views/AdminView.vue')
    }
]

const router = createRouter({
    history: createWebHistory(),
    routes
})

router.beforeEach(async (to, from, next) => {
    const { user, fetchUser } = useAuth()

    if (user.value === null) {
        // Try fetching user if not loaded yet
        await fetchUser()
    }

    // Protect /dashboard and /admin

    
    if ((to.path === '/dashboard' || to.path === '/admin') && !user.value) {
        return next('/login')
    }

    if (to.path === '/dashboard' && user.value.role === 'admin') {
        return next('/admin')
    }

    if (to.path === '/admin' && !user.value.role === 'admin') {
        return next('/dashboard')
    }

    next()
})

export default router
