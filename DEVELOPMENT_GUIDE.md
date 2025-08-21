# libSQL Client Development Guide

This document provides a comprehensive analysis of the Go implementation and serves as a guide for implementing clients in other languages.

## Architecture Overview

The libSQL client library provides a standardized interface for connecting to Turso databases using the Hrana protocol. It supports multiple connection types and follows the database/sql driver pattern in Go.

### Supported URL Schemes

- `libsql://` - Turso cloud databases (auto-detects HTTP/HTTPS based on TLS setting)
- `https://` - HTTP with TLS
- `http://` - HTTP without TLS  
- `wss://` - WebSocket with TLS
- `ws://` - WebSocket without TLS
- `file://` - Local SQLite files

### Connection Types

1. **HTTP Connector** (`libsql/internal/http`)
   - Uses Hrana v2 protocol over HTTP
   - Stateless connections
   - Pipeline requests for efficiency
   - Supports connection reuse

2. **WebSocket Connector** (`libsql/internal/ws`)
   - Uses Hrana v1 protocol over WebSocket
   - Persistent connections
   - Real-time communication
   - Stream-based requests

3. **File Connector**
   - Direct SQLite file access
   - Requires sqlite/sqlite3 driver
   - Local database operations

## Hrana Protocol

Hrana is the wire protocol used by libSQL for client-server communication.

### Hrana v2 (HTTP)

- **Endpoint**: `/v2/pipeline`
- **Method**: POST
- **Content-Type**: application/json
- **Authentication**: Bearer token in Authorization header

**Request Structure**:
```json
{
  "requests": [
    {
      "type": "execute",
      "stmt": {
        "sql": "SELECT * FROM users WHERE id = ?",
        "args": [{"type": "integer", "value": "123"}],
        "replication_index": 0
      }
    }
  ]
}
```

**Response Structure**:
```json
{
  "base_url": "https://...",
  "results": [
    {
      "type": "ok",
      "response": {
        "type": "execute",
        "result": {
          "cols": [{"name": "id", "decltype": "INTEGER"}],
          "rows": [[{"type": "integer", "value": "123"}]],
          "affected_row_count": 1,
          "last_insert_rowid": "123",
          "replication_index": 1
        }
      }
    }
  ]
}
```

### Hrana v1 (WebSocket)

- **Protocol**: `hrana1`
- **Authentication**: JWT in hello message

**Message Types**:
- `hello` - Initial handshake
- `request` - Execute SQL statements
- `response` - Query results
- `error` - Error responses

## Core Components

### 1. Configuration Management

**Options Pattern**:
```go
type Option interface {
    apply(*config) error
}

// Configuration options
WithAuthToken(string) Option
WithTls(bool) Option  
WithProxy(string) Option
WithSchemaDb(bool) Option
```

**Config Structure**:
```go
type config struct {
    authToken *string
    tls       *bool
    proxy     *string
    schemaDb  *bool
}
```

### 2. Connection Management

**Connector Interface**:
```go
type Connector interface {
    Connect(context.Context) (driver.Conn, error)
    Driver() driver.Driver
}
```

**Implementation Types**:
- `httpConnector` - HTTP-based connections
- `wsConnector` - WebSocket-based connections  
- `fileConnector` - File-based connections

### 3. SQL Execution

**Execution Flow**:
1. Parse SQL statements
2. Bind parameters
3. Create Hrana request
4. Send to server
5. Parse response
6. Return results

**Parameter Binding Formats**:
- Positional: `?`, `?1`, `?2`
- Named: `:name`, `@name`, `$name`

### 4. Transaction Support

**Transaction Operations**:
- `BEGIN` - Start transaction
- `COMMIT` - Commit changes
- `ROLLBACK` - Rollback changes

**Implementation**:
- Maintains transaction state
- Handles nested transactions
- Supports transaction isolation

### 5. Error Handling

**Error Types**:
- Connection errors
- SQL syntax errors
- Authentication errors
- Network errors
- Protocol errors

**Error Response Structure**:
```json
{
  "type": "error",
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE"
  }
}
```

## Key Features Implementation

### Authentication

1. **JWT Token Management**:
   - Provided via `WithAuthToken()` option
   - Included in Authorization header (HTTP)
   - Sent in hello message (WebSocket)

2. **Token Validation**:
   - Server validates token
   - Returns authentication errors
   - Supports token refresh

### Connection Pooling

1. **HTTP Connections**:
   - Stateless by nature
   - Reuses HTTP connections
   - Connection pooling handled by HTTP client

2. **WebSocket Connections**:
   - Persistent connections
   - Manual connection management
   - Reconnection on failures

### Data Type Mapping

**Supported Types**:
- `null` - SQL NULL
- `integer` - 64-bit signed integer
- `float` - 64-bit floating point
- `text` - UTF-8 string
- `blob` - Binary data

**Type Conversion**:
```go
// Go to Hrana
value := map[string]interface{}{
    "type": "integer",
    "value": "123"
}

// Hrana to Go
switch v.Type {
case "integer":
    return strconv.ParseInt(v.Value, 10, 64)
case "float":
    return strconv.ParseFloat(v.Value, 64)
// ...
}
```

## Integration Patterns

### Standard Database Integration

```go
import (
    "database/sql"
    _ "github.com/tursodatabase/libsql-client-go/libsql"
)

// Open connection
db, err := sql.Open("libsql", "libsql://your-db.turso.io?authToken=...")

// Execute queries
rows, err := db.Query("SELECT * FROM users")
```

### Custom Connector

```go
import "github.com/tursodatabase/libsql-client-go/libsql"

// Create connector with options
connector, err := libsql.NewConnector(
    "libsql://your-db.turso.io",
    libsql.WithAuthToken("your-token"),
    libsql.WithTls(true),
)

// Use with database/sql
db := sql.OpenDB(connector)
```

## Testing Strategy

### Test Coverage Areas

1. **Connection Tests**:
   - URL parsing
   - Authentication
   - TLS configuration
   - Proxy settings

2. **SQL Execution Tests**:
   - Basic queries
   - Parameter binding
   - Data type handling
   - Error conditions

3. **Transaction Tests**:
   - Begin/commit/rollback
   - Nested transactions
   - Isolation levels

4. **Protocol Tests**:
   - Hrana message formatting
   - Response parsing
   - Error handling

### Test Environment

- Local SQLite for file tests
- Mock servers for HTTP/WebSocket tests
- Integration tests with real Turso databases

## Implementation Guidelines for Other Languages

### Essential Components

1. **URL Parser**:
   - Parse connection strings
   - Extract authentication tokens
   - Handle scheme conversion

2. **HTTP Client**:
   - Support for Hrana v2 protocol
   - JSON request/response handling
   - Authentication headers

3. **WebSocket Client** (Optional):
   - Support for Hrana v1 protocol
   - Message-based communication
   - Connection management

4. **SQL Parser** (Basic):
   - Statement separation
   - Parameter detection
   - Comment handling

5. **Type System**:
   - Language-native type mapping
   - Hrana type conversion
   - NULL value handling

### Phoenix/Ecto Integration Considerations

For Elixir implementation:

1. **Ecto Adapter**:
   - Implement `Ecto.Adapters.SQL` behavior
   - Handle connection pooling
   - Support migrations

2. **Connection Pool**:
   - Use `DBConnection` behavior
   - Handle connection lifecycle
   - Support backoff strategies

3. **Query Building**:
   - Parameter substitution
   - SQL generation
   - Type casting

4. **Configuration**:
   - Runtime configuration
   - Environment variables
   - Connection validation

## Security Considerations

1. **Token Management**:
   - Secure token storage
   - Token rotation
   - Environment variable usage

2. **TLS/SSL**:
   - Certificate validation
   - Secure defaults
   - Protocol version selection

3. **Input Validation**:
   - SQL injection prevention
   - Parameter validation
   - Error message sanitization

## Performance Optimization

1. **Connection Reuse**:
   - HTTP keep-alive
   - WebSocket persistence
   - Connection pooling

2. **Request Batching**:
   - Pipeline multiple statements
   - Reduce round trips
   - Batch parameter binding

3. **Response Caching**:
   - Schema information
   - Prepared statements
   - Connection metadata

## Monitoring and Debugging

1. **Logging**:
   - Request/response logging
   - Error tracking
   - Performance metrics

2. **Health Checks**:
   - Connection validation
   - Ping operations
   - Timeout handling

3. **Debugging Tools**:
   - Protocol inspection
   - Connection state
   - Query execution plans