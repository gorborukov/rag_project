require 'pdf-reader'
require 'docx'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'set'

module RAG
  class Ingestor
    def initialize(core_instance)
      @core = core_instance
    end

    def extract_text(file)
      ext = File.extname(file).downcase
      case ext
      when ".pdf"
        PDF::Reader.new(file).pages.map(&:text).join("\n")
      when ".docx", ".doc"
        Docx::Document.open(file).paragraphs.map(&:text).join("\n")
      else
        File.read(file)
      end
    end

    def load_local_data(folder)
      files = Dir.glob(File.join(folder, "**", "*.{pdf,doc,docx,md,txt}"))
      files.each do |file|
        puts "Processing local file: #{file}..."
        begin
          text = extract_text(file)
          splitter = Langchain::Chunker::RecursiveText.new(text, chunk_size: 1000, chunk_overlap: 200)
          splitter.chunks.each { |chunk| @core.store_chunk(chunk.text, file) }
        rescue => e
          puts "Error loading #{file}: #{e.message}"
        end
      end
    end

    def crawl_and_load(url, max_depth: 0, current_depth: 0, visited: Set.new)
      return if visited.include?(url) || current_depth > max_depth
      visited << url

      puts "Crawling: #{url}"
      begin
        uri = URI.parse(url)
        html = Net::HTTP.get(uri)
        doc = Nokogiri::HTML(html)
        
        doc.search('script, style, nav, footer, header').remove
        text = doc.text.gsub(/\s+/, ' ').strip
        
        splitter = Langchain::Chunker::RecursiveText.new(text, chunk_size: 1000, chunk_overlap: 200)
        splitter.chunks.each { |chunk| @core.store_chunk(chunk.text, url) }

        # ONLY look for links if we are allowed to go deeper
        if current_depth < max_depth
          doc.css('a').each do |a|
            href = a['href']
            next unless href
            begin
              next_url = URI.join(url, href).to_s
              next_uri = URI.parse(next_url)
              if next_uri.host == uri.host && %w[http https].include?(next_uri.scheme)
                crawl_and_load(next_url, max_depth: max_depth, current_depth: current_depth + 1, visited: visited)
              end
            rescue URI::InvalidURIError
              next
            end
          end
        end
        
      rescue => e
        puts "Failed to crawl #{url}: #{e.message}"
      end
    end
  end
end