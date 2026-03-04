require 'pdf-reader'
require 'docx'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'set'

module RAG
  class Ingestor
    CHUNK_SIZE = 500
    CHUNK_OVERLAP = 50
    ALLOWED_SCHEMES = %w[http https].freeze
    REMOVABLE_TAGS = 'script, style, nav, footer, header'

    def initialize(core_instance)
      @core = core_instance
    end

    def extract_text(file)
      case File.extname(file).downcase
      when ".pdf" then PDF::Reader.new(file).pages.map(&:text).join("\n")
      when ".docx", ".doc" then Docx::Document.open(file).paragraphs.map(&:text).join("\n")
      else File.read(file)
      end
    end

    def load_local_data(folder)
      Dir.glob(File.join(folder, "**", "*.{pdf,doc,docx,md,txt}")).each do |file|
        puts "Processing local file: #{file}..."
        chunk_and_store(extract_text(file), file)
      rescue => e
        puts "Error loading #{file}: #{e.message}"
      end
    end

    def crawl_and_load(url, max_depth: 0, current_depth: 0, visited: Set.new)
      return if visited.include?(url) || current_depth > max_depth

      visited << url
      puts "Crawling: #{url}"

      uri = URI.parse(url)
      doc = parse_html(Net::HTTP.get(uri))
      chunk_and_store(extract_clean_text(doc), url)

      crawl_links(doc, uri, url, max_depth, current_depth, visited) if current_depth < max_depth
    rescue => e
      puts "Failed to crawl #{url}: #{e.message}"
    end

    private

    def chunk_and_store(text, source)
      splitter = Langchain::Chunker::RecursiveText.new(text, chunk_size: CHUNK_SIZE, chunk_overlap: CHUNK_OVERLAP)
      splitter.chunks.each { |chunk| @core.store_chunk(chunk.text, source) }
    end

    def parse_html(html)
      Nokogiri::HTML(html)
    end

    def extract_clean_text(doc)
      doc.search(REMOVABLE_TAGS).remove
      doc.text.gsub(/\s+/, ' ').strip
    end

    def crawl_links(doc, base_uri, base_url, max_depth, current_depth, visited)
      doc.css('a').each do |a|
        next unless (href = a['href'])
        next_url = URI.join(base_url, href).to_s
        next_uri = URI.parse(next_url)
        
        if next_uri.host == base_uri.host && ALLOWED_SCHEMES.include?(next_uri.scheme)
          crawl_and_load(next_url, max_depth: max_depth, current_depth: current_depth + 1, visited: visited)
        end
      rescue URI::InvalidURIError
        next
      end
    end
  end
end