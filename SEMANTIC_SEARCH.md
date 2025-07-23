# Semantic Search for EmberChat

This document describes the semantic search functionality that has been added to EmberChat using the all-MiniLM-L6-v2 model and sqlite-vec.

## Features

- **Semantic Understanding**: Search messages using natural language queries
- **Recency Weighting**: Balance between similarity and message recency
- **Real-time Results**: Live search interface with instant feedback
- **Advanced Filtering**: Filter by room, adjust similarity/recency weights
- **Similar Message Discovery**: Find messages similar to any given message
- **Search Suggestions**: Auto-complete suggestions based on message content

## Architecture

### Components

1. **Embedding Service** (`priv/embedding_service/`)
   - Python Flask service running all-MiniLM-L6-v2
   - Generates 384-dimensional vectors for text content
   - RESTful API for single and batch embedding generation

2. **Database Layer**
   - SQLite with sqlite-vec extension for vector storage
   - Virtual table `message_embeddings` for efficient similarity search
   - Indexed for performance with room and timestamp filtering

3. **Elixir Modules**
   - `Emberchat.Embeddings`: Communication with Python service
   - `Emberchat.Chat.EmbeddingGenerator`: Embedding lifecycle management
   - `Emberchat.Chat.SemanticSearch`: Search logic and ranking
   - `EmberchatWeb.SearchLive`: LiveView interface

## Setup

1. **Run the setup script:**
   ```bash
   ./setup_embedding_service.sh
   ```

2. **Start the embedding service:**
   ```bash
   cd priv/embedding_service
   source venv/bin/activate
   python embedding_server.py
   ```

3. **Start Phoenix in another terminal:**
   ```bash
   mix ecto.migrate
   mix phx.server
   ```

4. **Visit the search interface:**
   Navigate to `http://localhost:4000/search`

## Usage

### Basic Search

Simply type natural language queries like:
- "machine learning discussion"
- "project deadlines"
- "meeting tomorrow"
- "database migration issues"

### Advanced Options

**Room Filtering**: Search within specific rooms only

**Weight Adjustment**:
- **Similarity Weight** (0.1-1.0): How much semantic similarity matters
- **Recency Weight** (0.1-1.0): How much message recency matters

**Similar Messages**: Click "Find Similar" on any search result to discover related messages

### Search Suggestions

Type at least 2 characters to see auto-complete suggestions based on existing message content.

## Configuration

### Similarity Thresholds

Default minimum similarity threshold is 0.1. Adjust in `semantic_search.ex`:

```elixir
@min_similarity_threshold 0.1
```

### Embedding Dimensions

The system uses 384-dimensional vectors from all-MiniLM-L6-v2. To change models:

1. Update `requirements.txt` with new model
2. Modify `@embedding_dimensions` in `embeddings.ex`
3. Update virtual table schema in migration

### Performance Tuning

**Batch Size**: For backfilling embeddings, adjust batch size:

```elixir
Emberchat.Chat.backfill_embeddings(100)  # Default: 50
```

**Search Limits**: Default search returns 20 results. Adjust in search functions:

```elixir
Chat.search_messages(query, scope, limit: 50)
```

## API Functions

### Chat Context Functions

```elixir
# Search messages
{:ok, results} = Chat.search_messages("machine learning", scope, 
  room_id: 123, limit: 10)

# Find similar messages  
{:ok, similar} = Chat.find_similar_messages(message, limit: 5)

# Get search suggestions
{:ok, suggestions} = Chat.get_search_suggestions("proj", scope)

# Backfill embeddings for existing messages
{:ok, count} = Chat.backfill_embeddings(50)

# Count messages without embeddings
count = Chat.count_messages_without_embeddings()
```

### Direct Embedding Operations

```elixir
# Generate single embedding
{:ok, vector} = Embeddings.generate_embedding("Hello world")

# Generate batch embeddings
{:ok, vectors} = Embeddings.generate_batch_embeddings(["text1", "text2"])

# Calculate cosine similarity
{:ok, similarity} = Embeddings.cosine_similarity(vec1, vec2)
```

## Performance Considerations

### Embedding Generation

- Embeddings are generated asynchronously to avoid blocking message creation
- The Python service should be warmed up (first request may be slow)
- Consider using a process supervisor for the Python service in production

### Vector Search

- Uses sqlite-vec's optimized cosine distance calculation
- Indexed by room_id and timestamp for efficient filtering
- Virtual table provides fast similarity search

### Scaling

For larger deployments consider:

1. **Multiple Embedding Service Instances**: Load balance across multiple Python processes
2. **Embedding Caching**: Cache embeddings for frequently searched terms
3. **Background Job Processing**: Use Oban instead of Task for more robust job processing
4. **Database Optimizations**: Consider PostgreSQL with pgvector for larger datasets

## Troubleshooting

### Common Issues

**"Model not loaded" error**:
- Ensure the Python service is running
- Check that dependencies are installed correctly
- Verify the model downloads successfully on first run

**Search returns no results**:
- Check that messages have embeddings generated
- Run backfill process: `Chat.backfill_embeddings()`
- Verify sqlite-vec extension is loaded

**Performance issues**:
- Monitor Python service memory usage (model uses ~80MB)
- Check database indexes are created
- Consider adjusting batch sizes for embedding generation

### Health Checks

```elixir
# Check embedding service health
{:ok, :healthy} = Embeddings.health_check()

# Check embedding status
Chat.count_messages_without_embeddings()
```

### Logs

Monitor logs for embedding generation:
- Successful: "Synced embedding for message X to vector table"
- Errors: Check embedding service logs for model/API issues

## Development

### Adding New Features

**Custom Ranking**: Modify `calculate_combined_scores/4` in `semantic_search.ex`

**New Search Types**: Add functions to `SemanticSearch` module

**UI Enhancements**: Modify `SearchLive` render function

### Testing

```elixir
# Test embedding generation
message = %Message{content: "test message"}
{:ok, updated} = EmbeddingGenerator.generate_embedding_for_message(message)

# Test search functionality  
{:ok, results} = SemanticSearch.search_messages("test query", scope)
```

## Production Deployment

1. **Environment Variables**: Configure embedding service port/host
2. **Process Management**: Use systemd or supervisor for Python service
3. **Monitoring**: Monitor embedding generation success rates
4. **Backup**: Include vector table in database backups
5. **Security**: Restrict embedding service to internal network

## Support

For issues or questions:
1. Check logs for embedding service and Phoenix application
2. Verify all dependencies are installed correctly
3. Test with simple queries first
4. Monitor system resources during operation

---

*This semantic search implementation provides a foundation for intelligent message discovery in chat applications. The modular design allows for easy customization and scaling as your needs grow.*