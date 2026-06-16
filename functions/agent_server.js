// functions/agent_server.js
const { WebSocketServer } = require('ws');
const { execFileSync }    = require('child_process');
const fs                  = require('fs');
require('dotenv').config();

const systemPrompt = fs.readFileSync('./openclaw/skills.md', 'utf8');

const wss = new WebSocketServer({ port: 18789 });
console.log("🚀 Prioritization Agent Engine running on ws://localhost:18789");

wss.on('connection', function connection(ws) {
    console.log("📱 Flutter UI Connected!");

    let contextStack = [{ role: "system", content: systemPrompt }];

    ws.on('message', async function message(data) {
        try {
            const rawData   = data.toString();
            let userMessage = rawData;
            let sessionUid  = null

            try {
                const payload = JSON.parse(rawData);
                if (payload.type === 'init_flow') {
                    sessionUid  = payload.uid;
                    userMessage = `Please check the university emails for user ID: ${payload.uid} and calculate the Priority Scores.`;
                    console.log(`[System]: Kicking off flow for UID: ${payload.uid}`);
                }
            } catch (e) {
                console.log(`[User]: ${userMessage}`);
            }

            contextStack.push({ role: "user", content: userMessage });

            let isTaskResolved = false;
            const MAX_ITERATIONS = 14;
            let iterations = 0;

            const sendFallback = (reason) => {
                console.error(`❌ Sending fallback to Flutter: ${reason}`);
                ws.send(JSON.stringify({
                    type: 'final_response',
                    text: JSON.stringify([
                        { id: "system_error", priorityScore: 0, title: "System Error", summary: reason }
                    ]),
                }));
            };

            while (!isTaskResolved) {
                if (++iterations > MAX_ITERATIONS) {
                    sendFallback("Agent exceeded maximum iteration limit.");
                    break;
                }

                let response, result;
                try {
                    response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                        method: "POST",
                        headers: {
                            "Authorization": `Bearer ${process.env.OPENROUTER_API_KEY}`,
                            "Content-Type":  "application/json",
                        },
                        body: JSON.stringify({
                            model:    "meta-llama/llama-3-70b-instruct",
                            messages: contextStack,
                        }),
                    });
                    result = await response.json();
                } catch (networkErr) {
                    sendFallback(`Network error reaching OpenRouter: ${networkErr.message}`);
                    break;
                }

                if (!response.ok || result.error || !result.choices?.length) {
                    const apiError = result.error?.message ?? `HTTP ${response.status}`;
                    console.error("❌ OpenRouter API error:", apiError);
                    sendFallback(`LLM API error: ${apiError}`);
                    break;
                }

                const llmOutput = result.choices[0].message.content;
                console.log(`[Agent]:\n${llmOutput}`);
                ws.send(JSON.stringify({ type: "debug_log", text: llmOutput }));
                contextStack.push({ role: "assistant", content: llmOutput });

                // ── Tool call detection ──────────────────────────────────────────
                const toolMatch = llmOutput.match(/\[TOOL_CALL:\s*(\{[\s\S]*?\})\s*\]/);

                if (toolMatch) {
                    let toolRequest;
                    try {
                        toolRequest = JSON.parse(toolMatch[1]);
                    } catch (parseErr) {
                        contextStack.push({ role: "user", content: `Observation: Error — malformed TOOL_CALL JSON: ${parseErr.message}` });
                        continue;
                    }

                    // Always use the server-owned sessionUid.
                    // Never trust the LLM's uid arg — it may be a placeholder like "THE_UID_HERE".
                    const uid = sessionUid ?? toolRequest.args?.uid ?? "";
                    console.log(`⚙️ Executing Tool: ${toolRequest.tool} for UID: ${uid}`);
                    ws.send(JSON.stringify({ type: "status", text: `Running ${toolRequest.tool}...` }));

                    try {
                        // Gunakan execFileSync dengan array argumen (BUKAN string shell).
                        // execSync(`node x.js '${uid}'`) merusak UID di Windows karena cmd.exe
                        // tidak menghapus tanda kutip tunggal seperti shell Unix — tanda kutip
                        // ikut masuk sebagai bagian dari argv[2], membuat path Firestore salah
                        // (contoh: ccxpUsers/'uid' bukan ccxpUsers/uid).
                        // execFileSync dengan array args melewati shell sepenuhnya: setiap
                        // elemen array diteruskan apa adanya ke process.argv pada proses anak.
                        const rawOutput = execFileSync(
                            'node',
                            [`tools/${toolRequest.tool}.js`, uid]
                        ).toString();

                        const observation = `Observation: ${rawOutput.trim()}`;
                        console.log(observation);
                        contextStack.push({ role: "user", content: observation });

                    } catch (error) {
                        console.error("Tool Error:", error.message);
                        contextStack.push({ role: "user", content: `Observation: Error running tool — ${error.message}` });
                    }

                } else {
                    // ── No tool call: LLM emitted its final JSON array ───────────

                    // Extract the JSON block from this turn's output
                    let extractedJson = null;

                    const codeBlockMatch =
                        llmOutput.match(/```json\s*([\s\S]*?)\s*```/i) ||
                        llmOutput.match(/```\s*([\s\S]*?)\s*```/);

                    if (codeBlockMatch) {
                        extractedJson = codeBlockMatch[1].trim();
                    } else {
                        // Look for a JSON array in the raw output
                        const firstBracket = llmOutput.indexOf('[');
                        const lastBracket  = llmOutput.lastIndexOf(']');
                        if (firstBracket !== -1 && lastBracket > firstBracket) {
                            extractedJson = llmOutput.slice(firstBracket, lastBracket + 1).trim();
                        }
                    }

                    if (!extractedJson) {
                        // LLM produced conversational text mid-flow — nudge it.
                        contextStack.push({
                            role: "user",
                            content: "Observation: No JSON array or TOOL_CALL found in your last response. Continue with the next step."
                        });
                        continue;
                    }

                    let parsedPayload;
                    try {
                        parsedPayload = JSON.parse(extractedJson);
                    } catch (e) {
                        contextStack.push({
                            role: "user",
                            content: `Observation: Your JSON was malformed and could not be parsed. Error: ${e.message}. Please re-emit it.`
                        });
                        continue;
                    }

                    // The final output must be a JSON array of task objects
                    if (!Array.isArray(parsedPayload)) {
                        contextStack.push({
                            role: "user",
                            content: "Observation: Expected a JSON array of task objects as the final output. Please re-emit it in the correct format."
                        });
                        continue;
                    }

                    // ── Done: send the scored task array to Flutter ──────────────
                    isTaskResolved = true;
                    console.log(`✅ Agent done — ${parsedPayload.length} task(s)`);

                    ws.send(JSON.stringify({
                        type: 'final_response',
                        text: JSON.stringify(parsedPayload),
                    }));
                }
            }

        } catch (fatalErr) {
            console.error("💥 Unhandled agent error:", fatalErr);
            try {
                ws.send(JSON.stringify({
                    type: 'final_response',
                    text: JSON.stringify([
                        { id: "system_error", priorityScore: 0, title: "System Error", summary: `Unhandled server error: ${fatalErr.message}` }
                    ]),
                }));
            } catch (_) {}
        }
    });
});