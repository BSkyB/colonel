
module Colonel
  # Public: Results from elasticsearch. This is just an enumerable wrapper for the hash coming
  # out of the Elasticsearch API. Instead of just plain hashes it retuns Document instances.
  #
  # When you need high performance (e.g. listing many results) and don't need full Document
  # instances, you can use `raw`, which returns just plain `Content` without touching the
  # git backend.
  class ElasticsearchResultSet
    include Enumerable

    attr_reader :total, :facets

    # Internal: Create a new result set
    def initialize(results, document_type)
      @document_type = document_type

      @total  = results["hits"]["total"]
      @max_score = results["hits"]["max_score"]
      @hits   = results["hits"]["hits"]

      @facets = results["facets"]
    end

    # Public: Iterate over raw results
    def raw(&block)
      return to_enum(:raw) unless block_given?

      @hits.each do |hit|
        yield Content.new(hit["_source"])
      end
    end

    # Public: iterate over returned Documents
    def each(&block)
      return to_enum(:each) unless block_given?

      @hits.each do |hit|
        yield @document_type.open(hit["_source"]["id"])
      end
    end
  end
end
