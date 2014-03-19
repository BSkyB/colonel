require 'sinatra'
require "sinatra/json"

# Basic example using Sinatra
class ColonelSample < Sinatra::Base
  # Ensure index and mapping
  # Can be moved into Colonel::ContentItem eventually so not explicitally needed.
  Colonel::ContentItem.ensure_index!
  Colonel::ContentItem.put_mapping!

  # Search content by it's id.
  get '/search/:query' do
    search 'master', params[:query]
  end

  # Gets content by it's id.
  get '/content/:id' do
    doc = Colonel::ContentItem.open(params[:id])
    result doc
  end

  # Post content to create a sample document
  post '/content' do
    doc = Colonel::ContentItem.new({ title: 'My Item', body: 'Some text.' })
    doc.save!(Time.now)
    json doc.id
  end

  # Put content to update a sample document
  put '/content/:id' do
    doc = Colonel::ContentItem.open(params[:id])
    doc.body = 'Updated text.'
    doc.save!(Time.now)
    result doc
  end

  private

  # Result for generic response
  def result(item)
    json id: item.id, title: item.title, body: item.body
  end

  # Basic example of exposing search
  def search(state, query_string, opts = {})
    query = {
      filtered: {
        query: {
          query_string: {
            query: query_string
          }
        },
        filter: {
          term: { state: state }
        }
      }
    }

    hits = Colonel::ContentItem.search(query, opts)
    items = hits[:hits].map do |hit|
      result Colonel::ContentItem.open(hit.id)
    end
    json results: items, total: hits[:total]
  end
end
