<template>
    <div class="max-w-md mx-auto mt-10">
        <h2 class="text-xl font-bold mb-4">Login</h2>
        <form @submit.prevent="login">
            <input v-model="username" placeholder="Username" class="border w-full p-2 mb-4" />
            <input v-model="password" type="password" placeholder="Password" class="border w-full p-2 mb-4" />
            <button class="bg-blue-600 text-white px-4 py-2">Login</button>
        </form>
    </div>
</template>

<script setup>
import { useAuth } from '@/composables/useAuth'
import { ref } from 'vue'
import { useRouter } from 'vue-router'


const { fetchUser } = useAuth();

const username = ref('')
const password = ref('')
const router = useRouter()

async function login() {
    const res = await fetch('http://localhost:8081/login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({ username: username.value, password: password.value })
    })

    if (res.ok) {
        await fetchUser()

        // alert('Login successful')
        router.push('/dashboard')
    } else {
        alert('Login failed')
    }
}
</script>