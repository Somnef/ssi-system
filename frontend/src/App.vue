<template>
    <nav class="bg-gray-800 text-white p-4 flex justify-between">
        <div class="flex space-x-4">
            <router-link to="/">Home</router-link>
            <router-link v-if="user && user.role === 'admin'" to="/admin">Admin</router-link>
            <router-link v-if="user && user.role !== 'admin'" to="/dashboard">Dashboard</router-link>
        </div>
        <div class="flex space-x-4">
            <router-link v-if="!user" to="/login">Login</router-link>
            <span v-else>
                {{ user.username }}
                <span v-if="user.role === 'student'"> (Student)</span>
                <span v-if="user.role === 'employer'"> (Employer)</span>
                <span v-if="user.role === 'university'"> (University)</span>
                <span v-if="user.role === 'admin'"> (Admin)</span>
            </span>
            
            <router-link v-if="!user" to="/register">Register</router-link>
            <button v-else @click="handleLogout" class="hover:cursor-pointer">Logout</button>
        </div>
    </nav>

    <router-view />
</template>

<script setup>
import { useAuth } from '@/composables/useAuth'
import { ref, onMounted } from "vue";
import { useRouter } from 'vue-router'


const { user, fetchUser, logout } = useAuth()

const router = useRouter();

function handleLogout() {
    logout(router);
}

onMounted(async () => {
    await fetchUser();
});

</script>
