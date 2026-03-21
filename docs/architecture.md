# Frontend Architecture

Single-page React application that presents the LLM Council 3-stage deliberation process as a chat interface.

## Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| React | 19.2 | UI framework |
| Vite | 7.2 | Dev server + build tool |
| react-markdown | 10.1 | Render markdown in model responses |

No Redux, no Context API — state lives in `App.jsx` and flows down via props.

## File Structure

```
src/
├── api.js                     # API client (all backend calls)
├── App.jsx                    # Root: state, streaming, message flow
├── App.css
├── main.jsx                   # React entry point
├── index.css
└── components/
    ├── Sidebar.jsx            # Conversation list + new conversation
    ├── Sidebar.css
    ├── ChatInterface.jsx      # Message thread, input form
    ├── ChatInterface.css
    ├── Stage1.jsx             # Tabbed view of individual model responses
    ├── Stage1.css
    ├── Stage2.jsx             # Peer rankings + aggregate scores table
    ├── Stage2.css
    ├── Stage3.jsx             # Final synthesized answer
    └── Stage3.css
```

## Component Tree

```
App
├── Sidebar
│   ├── "New Conversation" button
│   └── ConversationItem[] (title, message count)
└── ChatInterface
    ├── Message[] (user messages)
    └── AssistantMessage
        ├── Stage1  (tabs per model, markdown responses)
        ├── Stage2  (tabs per evaluator, aggregate ranking table)
        └── Stage3  (chairman's final answer)
```

## State Management

All application state lives in `App.jsx`:

```javascript
conversations[]        // List metadata for sidebar
currentConversationId  // Active conversation ID
currentConversation    // Full object with messages[]
isLoading              // True while SSE stream is active
```

### Message Shape

**User message:**
```javascript
{ role: 'user', content: '...' }
```

**Assistant message (built progressively during streaming):**
```javascript
{
  role: 'assistant',
  stage1: null | [{model, response}, ...],
  stage2: null | [{model, ranking, parsed_ranking}, ...],
  stage3: null | {model, response},
  metadata: null | {label_to_model, aggregate_rankings},
  loading: { stage1: bool, stage2: bool, stage3: bool },
  error: null | string   // set when SSE emits {"type":"error","message":"..."}; ephemeral, not persisted
}
```

The `loading` flags drive per-stage spinners. Fields start as `null` and are filled as SSE events arrive.

## Key Behaviors

### Optimistic Updates
When the user sends a message, two entries are immediately added to the message list — a user message and an empty assistant message — before any backend response arrives. This keeps the UI responsive.

### Progressive Streaming
`handleSendMessage` in `App.jsx` uses `api.sendMessageStream()` to open an SSE connection. Each event updates only the relevant part of the last assistant message via `setCurrentConversation`, causing React to re-render just the changed stage.

### Auto-scroll
`ChatInterface.jsx` uses a `useRef` on the message container to scroll to the bottom whenever messages update.

### Markdown Rendering
All model responses (Stage 1, Stage 3) and ranking evaluations (Stage 2) are rendered through `react-markdown`, preserving formatting from LLM outputs.

### De-anonymization (Stage 2)
Stage 2 responses from the backend use generic labels (`Response A`, `Response B`, ...). `Stage2.jsx` replaces these with bold model names using the `labelToModel` map from `metadata`, so users see actual model names in the ranking text.

## Configuration

The backend URL is hardcoded in `src/api.js`:

```javascript
const API_BASE = 'http://localhost:8001';
```

Change this for production or use Vite's `import.meta.env.VITE_API_BASE` with a `.env` file.

## Dev Setup

```bash
npm install
npm run dev     # starts at http://localhost:5173
```

The Go backend must be running on port 8001. It is CORS-configured for `localhost:5173`.
