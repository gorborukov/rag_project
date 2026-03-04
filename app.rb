#!/usr/bin/env ruby

require 'optparse'
require_relative 'lib/rag/core'
require_relative 'lib/rag/ingestor'
require_relative 'lib/server'

# Set default max_depth to 0 (no nesting)
options = { max_depth: 0 }

OptionParser.new do |opts|
  opts.banner = "Usage: bundle exec ruby app.rb [options]"

  opts.on("--local-data FOLDER", "Folder with local documents") { |v| options[:local_data] = v }
  opts.on("--remote-data URL1,URL2", Array, "Comma-separated list of URLs to fetch remote data") { |v| options[:remote_data] = v }
  opts.on("--chat-template TEMPLATE", "Custom chat template string") { |v| options[:chat_template] = v }
  # Add the new max-depth flag
  opts.on("--max-depth DEPTH", Integer, "Maximum crawl depth for remote URLs (default: 0)") { |v| options[:max_depth] = v }
end.parse!

core_engine = RAG::Core.new
core_engine.chat_template = options[:chat_template].gsub('\\n', "\n") if options[:chat_template]

if options[:local_data] || options[:remote_data]
  ingestor = RAG::Ingestor.new(core_engine)
  
  if options[:local_data]
    puts "Starting local data ingestion..."
    ingestor.load_local_data(options[:local_data])
  end

  if options[:remote_data]
    options[:remote_data].each do |url|
      puts "Starting remote URL crawler for: #{url} (Depth: #{options[:max_depth]})..."
      # Pass the dynamic max_depth instead of hardcoded 1
      ingestor.crawl_and_load(url.strip, max_depth: options[:max_depth])
    end
  end
end

core_engine.init_db!

puts "\n>> Starting RAG Web GUI on http://localhost:4567 ...\n\n"
RAGServer.set :rag_core, core_engine
RAGServer.run!(port: 4567)