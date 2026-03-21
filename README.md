# LLM Council — Frontend

The frontend for **LLM Council**, a system that replaces a single AI answer with a
collective one. Instead of asking one model, you ask a council: multiple LLMs respond
independently, evaluate each other anonymously, and a designated Chairman synthesizes
the best final answer from all of that.

This repository is the React UI. The backend is a separate Go service at
[`llm-council-backend`](../llm-council-backend).

---

## How it works

Every message you send goes through three stages, which the UI reveals progressively
as they complete:

**Stage 1 — Individual responses**
All council models (GPT, Gemini, Claude, Grok, …) answer your question in parallel,
with no knowledge of each other.

**Stage 2 — Peer review**
Each model evaluates all the responses from Stage 1 — but anonymized as "Response A",
"Response B", etc., so no model knows which answer is its own. They rank the responses
and explain why. The UI shows each model's full evaluation and an aggregate ranking
table ("street cred") that averages all the votes.

**Stage 3 — Chairman synthesis**
A single designated model receives all Stage 1 responses and all Stage 2 rankings and
writes a final, synthesized answer informed by the collective evaluation.

The conversation is saved and can be revisited from the sidebar.

---

## Prerequisites

- Node.js 18+
- The Go backend running on port 8001 (see [`llm-council-backend`](../llm-council-backend))

---

## Getting started

```bash
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173). The backend must already be running —
it handles the actual LLM calls and conversation storage.

---

## Other commands

```bash
npm run build     # production build → dist/
npm run preview   # serve the production build locally
npm run lint      # ESLint
```

---

## Project structure

```
src/
├── api.js               API client — all backend communication lives here
├── App.jsx              Root component, all state, streaming message handler
└── components/
    ├── Sidebar.jsx      Conversation list, new conversation button
    ├── ChatInterface.jsx  Message thread, input form
    ├── Stage1.jsx       Tabbed view of each model's individual response
    ├── Stage2.jsx       Peer rankings, de-anonymized evaluations, aggregate table
    └── Stage3.jsx       Chairman's final synthesized answer
```

Each component has a co-located `.css` file.

---

## Configuration

The backend URL is set in `src/api.js`:

```js
const API_BASE = 'http://localhost:8001';
```

For a different environment, either change this directly or switch to Vite's
environment variable support:

```js
const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:8001';
```

Then create a `.env` file:

```
VITE_API_BASE=https://your-backend-host
```

---

## Further reading

- [`docs/architecture.md`](docs/architecture.md) — component tree, state shape,
  key behaviors (optimistic updates, SSE streaming, de-anonymization)
- [`docs/api-contract.md`](docs/api-contract.md) — REST endpoint reference with
  request/response shapes
- [`docs/streaming.md`](docs/streaming.md) — SSE event sequence and payload shapes
