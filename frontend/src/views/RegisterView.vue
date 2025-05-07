<template>
    <div class="max-w-md mx-auto mt-10">
      <h2 class="text-xl font-bold mb-4">Register</h2>
      <form @submit.prevent="register">
        <input v-model="email" placeholder="Email" class="border w-full p-2 mb-4" />
        <input v-model="password" type="password" placeholder="Password" class="border w-full p-2 mb-4" />
        <button class="bg-blue-600 text-white px-4 py-2">Register</button>
      </form>
    </div>
  </template>
  
  <script setup>
  import { ref } from 'vue'
  
  const email = ref('')
  const password = ref('')
  
  function register() {
    console.log('Send to backend:', { email: email.value, password: password.value })
    // TODO: POST to /api/register
  }
  </script>
  