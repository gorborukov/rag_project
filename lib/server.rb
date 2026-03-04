require 'sinatra/base'
require 'json'

class RAGServer < Sinatra::Base
  set :server, :puma
  set :public_folder, File.expand_path('../../public', __FILE__)
  set :views, File.expand_path('../../views', __FILE__)

  get '/' do
    erb :index
  end

  post '/chat' do
    content_type :json
    req = JSON.parse(request.body.read)
    query = req['query']
    
    core = settings.rag_core
    
    similar = core.search_similar(query, k: 3)
    context = similar.map { |c| "[Source: #{c[:source]}]\n#{c[:text]}" }.join("\n\n")
    
    template = core.chat_template || default_template
    prompt = template.gsub('{context}', context).gsub('{query}', query)
    
    response = core.generate_answer(prompt)
    
    { answer: response, sources: similar }.to_json
  end

  private

  def default_template
    <<~TMPL
      <|im_start|>system
      You are a helpful assistant. Use the following context to answer the user's question. If you cannot answer using the context, simply say so.
      
      Context:
      {context}<|im_end|>
      <|im_start|>user
      {query}<|im_end|>
      <|im_start|>assistant
    TMPL
  end
end