# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm install        # install dependencies
npm run dev        # dev server at http://localhost:5173
npm run build      # production build
npm run lint       # ESLint
npm run preview    # serve the production build locally
```

There is no test suite.

## Architecture

The frontend is a single-page React app for the LLM Council system — a 3-stage deliberation pipeline where multiple LLMs answer a question, peer-review each other anonymously, and a Chairman model synthesizes a final answer.

**State lives entirely in `App.jsx`** (no Redux, no Context). It flows down via props. The key shape is the assistant message, which is built progressively during streaming:

```javascript
{
  role: 'assistant',
  stage1: null | [{model, response}],
  stage2: null | [{model, ranking, parsed_ranking}],
  stage3: null | {model, response},
  metadata: null | {label_to_model, aggregate_rankings},
  loading: {stage1, stage2, stage3}  // drives per-stage spinners
}
```

**`src/api.js`** is the single API client. `API_BASE` is hardcoded to `http://localhost:8001` (the Go backend). The streaming method reads a `ReadableStream` and calls `onEvent(eventType, event)` for each SSE `data:` line.

**`src/components/Stage2.jsx`** does de-anonymization: Stage 2 responses from the backend use labels (`Response A`, `Response B`, ...) and `Stage2.jsx` replaces them with bold model names using `metadata.label_to_model`. This mapping is ephemeral — not stored by the backend — so it is only available during and immediately after the streaming response, not when loading a saved conversation.

## Backend

The Go backend repo is at `../llm-council-backend`. See `docs/api-contract.md` for endpoint shapes and `docs/streaming.md` for the full SSE event sequence.

The backend must be running before starting the dev server. CORS is configured on the backend for `localhost:5173`.
