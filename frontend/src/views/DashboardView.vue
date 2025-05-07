<template>
    <div class="max-w-xl mx-auto mt-12 bg-white p-6 shadow rounded">
        <h2 class="text-2xl font-semibold mb-6">Dashboard</h2>

        <div v-if="user && !user.has_requested">
            <h3 class="text-lg font-semibold mb-2">Request an Agent</h3>
            <form @submit.prevent="submitRequest" class="space-y-4">
                <div>
                    <label class="block mb-1 font-medium">Agent Role</label>
                    <select v-model="role" class="w-full border p-2 rounded">
                        <option disabled value="">Select a role</option>
                        <option value="student">Student</option>
                        <option value="employer">Employer</option>
                        <option value="university">University</option>
                    </select>
                </div>

                <div>
                    <label class="block mb-1 font-medium">Upload Justification</label>
                    <input type="file" @change="handleFileUpload" />
                </div>

                <button class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded">
                    Submit Request
                </button>
            </form>
        </div>

        <div v-else class="text-green-700 font-semibold mt-6">
            <span v-if="user && user.role !== ''">
                ✅ Your request has been approved. You can now access the agent.
            </span>
            <span v-else>
                ✅ You've already submitted an agent request. Please wait for admin approval.
            </span>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useAuth } from '@/composables/useAuth'

const { user, fetchUser } = useAuth();
const file = ref(null);
const role = ref("");

function handleFileUpload(e) {
    file.value = e.target.files[0];
}

async function submitRequest() {
    const formData = new FormData();
    formData.append("role", role.value);
    formData.append("file", file.value);

    const res = await fetch("http://localhost:8081/request-agent", {
        method: "POST",
        credentials: "include",
        body: formData
    });
    
    if (res.ok) {
        alert("Request submitted successfully!");
    } else {
        alert("Failed to submit request.");
    }

    // Reload the user data to reflect the new state
    await fetchUser();

    // Reset the form
    role.value = "";
    file.value = null;
    document.querySelector("input[type='file']").value = "";
    
}

onMounted(async () => {
    const res = await fetch("http://localhost:8081/me", {
        credentials: "include",
    });
    if (res.ok) {
        user.value = await res.json();
    }
});
</script>
