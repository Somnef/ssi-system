<template>
    <div class="max-w-2xl mx-auto mt-12 bg-white p-6 shadow rounded">
        <h2 class="text-2xl font-semibold mb-6">Admin Panel: Approve Agent Requests</h2>

        <div v-if="requests.length === 0" class="text-gray-500">
            No pending agent requests.
        </div>

        <div v-for="req in requests" :key="req.username" class="border-t pt-4 mt-4">
            <p><strong>Username:</strong> {{ req.username }}</p>
            <p><strong>Role:</strong> {{ req.role }}</p>
            <p><strong>File:</strong> <a :href="fileUrl(req.filename)" target="_blank"
                    class="text-blue-600 underline">Download</a></p>
            <p><strong>Status:</strong>
                <span class="text-yellow-700 font-medium" v-if="req.status === 'pending'">Pending</span>
                <span class="text-green-700 font-medium" v-else>Approved</span>
            </p>

            <button class="mt-2 bg-green-600 hover:bg-green-700 text-white px-4 py-1 rounded"
                @click="approveRequest(req.username)" :disabled="approving === req.username">
                {{ approving === req.username ? 'Approving...' : 'Approve Request' }}
            </button>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from "vue";

const requests = ref([]);
const approving = ref(null);

async function loadRequests() {
    const res = await fetch("http://localhost:8081/admin/requests", {
        credentials: "include",
    });

    if (res.ok) {
        const data = await res.json();
        requests.value = data.filter(r => r.status === "pending");
    } else {
        alert("Failed to load requests");
    }
}

async function approveRequest(username) {
    approving.value = username;
    const res = await fetch("http://localhost:8081/admin/approve-request", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({ username }),
    });

    if (res.ok) {
        requests.value = requests.value.filter(r => r.username !== username);
    } else {
        const err = await res.json();
        alert("Failed to approve: " + err.detail);
    }
    approving.value = null;
}

function fileUrl(path) {
    return `http://localhost:8081/${path}`;
}

onMounted(loadRequests);
</script>
