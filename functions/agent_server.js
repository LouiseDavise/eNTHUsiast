// \functions\agent_server.js
const { WebSocketServer } = require('ws');
const fs = require('fs');

const wss = new WebSocketServer({ port: 18789 });
console.log("🚀 Shared OpenClaw Engine running on port 18789");

wss.on('connection', (ws) => {
    let currentSystemPrompt = "";
    let contextStack = [];

    ws.on('message', async (message) => {
        const data = JSON.parse(message.toString());

        // 1. Check for Init Handshake from either your service or your friend's service
        if (data.type === 'init_flow') {
            if (data.flow === 'gmail_prioritization') {
                currentSystemPrompt = fs.readFileSync('./openclaw/gmail_skills.md', 'utf8');
                console.log("📥 Flow Switched: Event Prioritization Agent Active");
            } else if (data.flow === 'baobao_course_planning') {
                currentSystemPrompt = fs.readFileSync('./openclaw/baobao_skills.md', 'utf8');
                console.log("🎓 Flow Switched: BaoBao Course Planner Active");
            }
            contextStack = [{ role: "system", content: currentSystemPrompt }];
            return; // Initialization complete
        }

        // 2. Handle standard user prompts normally under the chosen active profile...
    });
});