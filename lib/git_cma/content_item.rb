require 'ostruct'

module GitCma
  # Public: Structured content storage. Uses `Document` for versioning and publishing pipeline support.
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

    def save!(timestamp)
      document.content = @content.to_json
      document.save!(timestamp)
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
      document.promote!(from, to, message, timestamp)
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
        @content.send meth.chomp("="), *args
      else
        super
      end
    end

    class << self

      def open(id, rev = nil)
        doc = Document.open(id, rev)
        new(nil, document: doc)
      end
    end
  end
end
