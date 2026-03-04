## Self-hosted RAG system in Ruby powered by llama.cpp

Note from a human: The documentation in this file is AI-generated, so there may be inaccuracies.

### 1. Build `llama.cpp` for Your Architecture

Clone and build llama.cpp for your system:

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release
```

For specific hardware (Metal, CUDA, etc.), follow the platform-specific build flags described in the repository.
### 2. Download a GGUF Model

Download a compatible `.gguf` model (quantized for your hardware). Place it in:

```
./models/Qwen3.5-4B-UD-Q5_K_XL/
```

### 3. Start `llama-server`

Run `llama-server` with embedding support enabled:

```bash
llama-server \
  -m ./models/Qwen3.5-4B-UD-Q5_K_XL/Qwen3.5-4B-UD-Q5_K_XL.gguf \
  --ctx-size 16384 \
  --embedding \
  --pooling mean
```

#### Flags Explained

- `-m` — Path to the `.gguf` model
- `--ctx-size 16384` — Context window size
- `--embedding` — Enables embedding endpoint
- `--pooling mean` — Mean pooling for embeddings

### 4. Install Ruby Dependencies

From  project root:

```bash
bundle install
```

### 5. Run the application

The application supports:

- Local document ingestion
- Remote website crawling
- Combined local + remote sources
- Depth-limited crawling

#### Index Local Documents

```bash
bundle exec ruby app.rb --local-data "./docs"
```

Indexes all supported files inside `./docs`.

#### Index Remote Documentation

```bash
bundle exec ruby app.rb --remote-data "https://docs.langchain.com/oss/python/langchain/overview"
```

#### Index Multiple Remote Sources

```bash
bundle exec ruby app.rb \
  --remote-data "https://docs.langchain.com/oss/python/langchain/overview,https://github.com/patterns-ai-core/langchainrb"
```

#### Limit Crawl Depth

```bash
bundle exec ruby app.rb \
  --remote-data "https://docs.langchain.com/oss/python/langchain/overview" \
  --max-depth 1
```

Limits recursive crawling to depth `1`.

#### Combine Remote + Local Data

```bash
bundle exec ruby app.rb \
  --remote-data "https://docs.langchain.com/oss/python/langchain/overview" \
  --local-data "./docs"
```

Indexes both sources into the same retrieval pipeline.

### Notes

- Ensure `llama-server` is running before starting the Ruby app.
- Make sure your model supports embeddings.
- Adjust `--ctx-size` depending on available RAM.
- Larger context windows increase memory usage.

### Result

You now have a fully local, self-hosted RAG system in Ruby powered by:

- llama.cpp
- A GGUF quantized model
- A custom Ruby ingestion + retrieval pipeline

No external APIs required.