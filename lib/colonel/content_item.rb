require 'ostruct'

module Colonel
  # DEPRECATED
  # Public: Structured content storage. Backed by `Document` for versioning and publishing states support.
  # Content can be any data structure composed of hashes and arrays. It is then accessible through method
  # calls (similar to OpenStruct which it is based on). When saved, content item serializes the content
  # to JSON and saves it. Loading a content item automatically constructs the data structure from the JSON.
  #
  # You can list and search the content items using the `list` and `search` class methods.
  #
  # If you need to customize the search behavior - change the index name, the type name or the attributes
  # indexing, you will need to inherit the ContentItem class.
  #
  # Examples
  #
  # Let's take an example, an Article class that has a `title`, an
  # `abstract` a `body` and a `published_at` date.
  #
  #   class Document
  #     index_name 'my_app_index'
  #     item_type_name 'article'
  #
  #     attributes_mapping do
  #       {
  #         title: { type: 'string' },
  #         abstract: { type: 'string' },
  #         body: { type: 'string' },
  #         published_at: { type: 'date' },
  #       }
  #     end
  #   end
  #
  class ContentItem
    attr_reader :document, :id


    class << self


      def scope(name, predicates)
        @scopes ||= {}
        @scopes[name] = predicates
      end

      def scopes
        @scopes ||= {}
      end

    end
  end
end
