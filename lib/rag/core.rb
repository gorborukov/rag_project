require 'langchain'
require 'sqlite3'
require 'sqlite_vec'

module RAG
  class Core
    attr_accessor :chat_template, :table_created

    def initialize
      @table_created = false
      
      puts "Connecting to local llama-server on http://localhost:8080..."
      
      @llm = Langchain::LLM::OpenAI.new(
        api_key: "dummy-key-not-needed",
        llm_options: { uri_base: "http://localhost:8080" },
        default_options: {
          chat_completion_model_name: "qwen-local",
          embeddings_model_name: "qwen-local"
        }
      )

      @db = SQLite3::Database.new("rag.db")
      
      @db.enable_load_extension(true)  
      SqliteVec.load(@db)              
      @db.enable_load_extension(false) 
    end

    def generate_embedding(text)
      emb = @llm.embed(text: text, model: "qwen-local").embedding
      return nil unless emb && !emb.empty?

      # L2 Normalization (make the vector length exactly 1.0)
      norm = Math.sqrt(emb.map { |x| x**2 }.sum)
      emb.map { |x| x / norm }
    end

    def generate_answer(prompt)
      messages = [
        { role: "user", content: prompt }
      ]
      
      response = @llm.chat(
        messages: messages, 
        model: "qwen-local", 
        max_tokens: 512
      )
      
      # Return the parsed text
      response.chat_completion
    end

    def init_db!
      return if @table_created
      puts "Initializing Vector Database tables..."
      
      dim = generate_embedding("test_dimension_size").length
      
      @db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS vec_docs USING vec0(embedding float[#{dim}]);")
      @db.execute("CREATE TABLE IF NOT EXISTS docs(rowid INTEGER PRIMARY KEY, text TEXT, source TEXT);")
      @table_created = true
    end

    def store_chunk(text, source)
      init_db!
      return if text.nil? || text.strip.empty?
      
      begin
        embedding = generate_embedding(text)
        
        # If embedding generation failed (returned nil), skip it
        return unless embedding
        
        packed_embedding = embedding.pack("f*")
        
        # Use a transaction. If one table fails, both rollback.
        @db.transaction do
          @db.execute("INSERT INTO docs (text, source) VALUES (?, ?)", [text, source])
          rowid = @db.last_insert_row_id
          
          @db.execute("INSERT INTO vec_docs (rowid, embedding) VALUES (?, ?)", [rowid, packed_embedding])
        end
      rescue => e
        puts "Warning: Failed to process chunk from #{source}: #{e.message}"
      end
    end

    def search_similar(query, k: 3)
      return[] unless @table_created
      
      emb = generate_embedding(query)
      packed = emb.pack("f*")
      
      res = @db.execute(<<~SQL, [packed, k])
        SELECT docs.text, docs.source, vec_docs.distance
        FROM vec_docs
        LEFT JOIN docs ON docs.rowid = vec_docs.rowid
        WHERE vec_docs.embedding MATCH ? AND k = ?
        ORDER BY vec_docs.distance ASC
      SQL
      
      res.map { |row| { text: row[0], source: row[1], distance: row[2] } }
    end
  end
end