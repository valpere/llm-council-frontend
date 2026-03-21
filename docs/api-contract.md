# API Contract

The frontend communicates with the Go backend (port 8001) via REST + Server-Sent Events. All requests and responses use JSON.

## Endpoints

### List Conversations

```
GET /api/conversations
```

Response:
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": "2025-03-21T10:00:00.000000Z",
    "title": "Why is the sky blue?",
    "message_count": 2
  }
]
```

Sorted by `created_at` descending (newest first). Used by `Sidebar` to populate the conversation list.

---

### Create Conversation

```
POST /api/conversations
Content-Type: application/json

{}
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2025-03-21T10:00:00.000000Z",
  "title": "New Conversation",
  "messages": []
}
```

---

### Get Conversation

```
GET /api/conversations/{id}
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2025-03-21T10:00:00.000000Z",
  "title": "Why is the sky blue?",
  "messages": [
    {
      "role": "user",
      "content": "Why is the sky blue?"
    },
    {
      "role": "assistant",
      "stage1": [
        { "model": "openai/gpt-5.1", "response": "..." }
      ],
      "stage2": [
        {
          "model": "openai/gpt-5.1",
          "ranking": "Full evaluation text...",
          "parsed_ranking": ["Response C", "Response A", "Response B"]
        }
      ],
      "stage3": {
        "model": "google/gemini-3-pro-preview",
        "response": "Final synthesized answer..."
      }
    }
  ]
}
```

Note: `metadata` (label_to_model, aggregate_rankings) is **not persisted** — it is only returned during the streaming response. Loaded conversations from `GET` will not include it.

---

### Send Message (Blocking)

```
POST /api/conversations/{id}/message
Content-Type: application/json

{"content": "Why is the sky blue?"}
```

Response: same assistant message shape as stored in `GET /api/conversations/{id}`, plus a top-level `metadata` field:

```json
{
  "stage1": [...],
  "stage2": [...],
  "stage3": {...},
  "metadata": {
    "label_to_model": {
      "Response A": "openai/gpt-5.1",
      "Response B": "anthropic/claude-sonnet-4.5",
      "Response C": "google/gemini-3-pro-preview",
      "Response D": "x-ai/grok-4"
    },
    "aggregate_rankings": [
      { "model": "openai/gpt-5.1", "average_rank": 1.5, "rankings_count": 4 }
    ]
  }
}
```

The frontend uses the streaming endpoint instead. This endpoint exists for non-streaming use cases.

---

### Send Message (Streaming)

```
POST /api/conversations/{id}/message/stream
Content-Type: application/json

{"content": "Why is the sky blue?"}
```

Response: `text/event-stream` (Server-Sent Events). See [streaming.md](./streaming.md) for the full event sequence and shapes.

---

## Data Types

### ConversationMeta

```typescript
{
  id: string           // UUID v4
  created_at: string   // RFC 3339 / ISO 8601
  title: string
  message_count: number
}
```

### Conversation

```typescript
{
  id: string
  created_at: string
  title: string
  messages: (UserMessage | AssistantMessage)[]
}
```

### UserMessage

```typescript
{
  role: "user"
  content: string
}
```

### AssistantMessage (stored)

```typescript
{
  role: "assistant"
  stage1: StageOneResult[]
  stage2: StageTwoResult[]
  stage3: StageThreeResult
}
```

### StageOneResult

```typescript
{ model: string; response: string }
```

### StageTwoResult

```typescript
{
  model: string
  ranking: string          // Full text from the model (used for display)
  parsed_ranking: string[] // Extracted ordered list: ["Response C", "Response A", ...]
}
```

### StageThreeResult

```typescript
{ model: string; response: string }
```

### Metadata (ephemeral, not stored)

```typescript
{
  label_to_model: Record<string, string>   // "Response A" → "openai/gpt-5.1"
  aggregate_rankings: {
    model: string
    average_rank: number
    rankings_count: number
  }[]
}
```

## CORS

The backend allows:
- Origins: `http://localhost:5173`, `http://localhost:3000`
- Methods: `GET`, `POST`, `OPTIONS`
- Headers: `Content-Type`
