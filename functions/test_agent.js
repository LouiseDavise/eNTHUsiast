// \functions\test_agent.js
const fs = require('fs');

async function testLLM() {
    // 1. Load the Brain
    const systemPrompt = fs.readFileSync('./openclaw/skills.md', 'utf8');
    
    // 2. Simulate the runtime context after tools have run
const simulatedContext = `
    User: Check my emails for user student_123.
    Thought: I need to fetch emails first.
    Action: [TOOL_CALL: {"tool": "fetch_gmail", "args": {"uid": "student_123"}}]
    Observation: {"status": "success", "data": [{"subject": "Linear Algebra Midterm rescheduled", "text": "The exam is tomorrow.", "date": "Today"}]}
    Thought: I have an exam tomorrow. I need to check the history to calculate the History Multiplier.
    Action: [TOOL_CALL: {"tool": "fetch_history", "args": {"uid": "student_123"}}]
    Observation: {"status": "success", "history": [{"title": "Discrete Mathematics", "status": "Failed"}]}
    Thought: I have the email data and the student's history. Now, I need to check the schedule for conflicts.
    Action: [TOOL_CALL: {"tool": "verify_schedule", "args": {"uid": "student_123"}}]
    Observation: {"status": "success", "schedule": [{"title": "Data Structures", "day": "Tuesday", "startSlot": 3, "duration": 2}]}
    `;

    // 3. Call OpenRouter
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
            "Authorization": `Bearer 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`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            model: "meta-llama/llama-3-70b-instruct", // or your preferred model
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: simulatedContext + "\nThought:" }
            ]
        })
    });

    const result = await response.json();
    if (!result.choices) {
    console.error("❌ OpenRouter API Error! Here is what it returned:");
    console.error(JSON.stringify(result, null, 2));
    process.exit(1); // Stop the script safely
}

// 2. If it didn't fail, print the content safely
console.log("LLM Output:\n", result.choices[0].message.content);
}

testLLM();