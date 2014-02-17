require 'ostruct'

module GitCma
  # Public: Structured content storage. Uses `Document` for versioning and publishing pipeline support.
  # Content can be any data structure composed of hashes and arrays. It will be accessible through method
  # calls (similar to OpenStruct which it is based on). When saved, content item will serialize the content
  # to JSON and save it. Loading a content item automatically constructs the data structure from the JSON.
  class ContentItem
    attr_reader :document, :id

    def initialize(content, opts = {})
      @document = opts[:document] || Document.new
      @content = if @document.content && !@document.content.empty?
        Content.from_json(@document.content)
      else
        Content.new(content)
      end

      @id = @document.name
    end

    def update(content)
      @content.update(content)
    end

    def delete_field(field)
      @content.delete_field(field)
    end

    def save!(timestamp)
      document.content = @content.to_json
      sha = document.save!(timestamp)

      index!(state: 'master', updated_at: timestamp, revision: sha)

      sha
    end

    def index!(opts = {})
      state = opts[:state] || 'master'
      updated_at = opts[:updated_at]
      sha = opts[:revision]

      body = {
        id: id,
        revision: sha,
        state: state,
        updated_at: updated_at
      }

      item_id = "#{@id}-#{state}"
      rev_id = "#{@id}-#{sha}"

      # Index the document
      self.class.es_client.index(index: self.class.index_name, type: self.class.item_type_name.to_s, id: item_id, body: body)

      # Index the revision
      self.class.es_client.index(index: self.class.index_name, type: self.class.revision_type_name.to_s, id: rev_id, parent: item_id, body: body)
    end

    def load!(rev)
      rev = document.load!(rev)
      @content = Content.from_json(document.content)

      rev
    end

    # Surfacing document API

    def revision
      document.revision
    end

    def history(state = nil, &block)
      document.history(state, &block)
    end

    def promote!(from, to, message, timestamp)
      sha = document.promote!(from, to, message, timestamp)

      index!(state: to, revision: sha, updated_at: timestamp)

      sha
    end

    def has_been_promoted?(to, rev = nil)
      document.has_been_promoted?(to, rev)
    end

    def rollback!(state)
      document.rollback!(state)
    end

    # Surfacing content

    def [](i)
      @content[i]
    end

    def []=(i, val)
      @content[i] = value
    end

    def method_missing(meth, *args)
      if args.length < 1
        @content.send meth
      elsif args.length == 1
        @content.send meth.to_s.chomp("="), *args
      else
        super
      end
    end

    class << self
      def open(id, rev = nil)
        doc = Document.open(id, rev)
        new(nil, document: doc)
      end

      def all(state = 'master')
        # query for all documents in a given state
      end

      def search(query)
        query = {} if query.is_a?(String)

        # talk to elastic search
      end

      def es_client
        @es_client ||= ::Elasticsearch::Client.new log: true
      end

      def item_type_name
        :content_item
      end

      def revision_type_name
        :content_item_rev
      end

      def index_name
        'git-cma-content'
      end

      # Internal: idempotently create the ES index
      def ensure_index!
        unless es_client.indices.exists index: index_name
          body = { mappings: {} }
          body[:mappings][item_type_name] = ITEM_MAPPINGS
          body[:mappings][revision_type_name] = DEFAULT_MAPPINGS

          es_client.indices.create index: index_name, body: body
        end
      end
    end

    # Item mapping, used for listing documents
    ITEM_MAPPINGS = {
      properties: {
        # _id is "{id}-{state}"
        id: {
          type: 'string',
          store: 'yes',
          index: 'not_analyzed'
        },
        state: {
          type: 'string',
          store: 'yes',
          index: 'not_analyzed'
        },
        updated_at: {
          type: 'date'
        }
      }
    }

    # Revision mapping, used for all other types of search through parent-child relation on the item
    DEFAULT_MAPPINGS = {
      _source: { enabled: false }, # you only get what you store
      _parent: { type: item_type_name },
      properties: {
        # _id is "{id}-{rev}"
        id: {
          type: 'string',
          store: 'yes',
          index: 'not_analyzed'
        },
        revision: {
          type: 'string',
          store: 'yes',
          index: 'not_analyzed'
        },
        state: {
          type: 'string',
          store: 'yes',
          index: 'not_analyzed'
        },
        updated_at: {
          type: 'date'
        }
      }
    }
  end
end
