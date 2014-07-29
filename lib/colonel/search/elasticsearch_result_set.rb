
module Colonel
  class ElasticsearchResultSet
    include Enumerable

    attr_reader :total, :facets

    def initialize(results)
      @total  = results["hits"]["total"]
      @max_score = results["hits"]["max_score"]
      @hits   = results["hits"]["hits"]

      @facets = results["facets"]
    end

    # Public: raw results
    def raw(&block)
      return to_enum(:raw) unless block_given?

      @hits.each do |hit|
        yield Content.new(hit["_source"])
      end
    end

    # Public: iterate through results
    def each(&block)
      return to_enum(:each) unless block_given?

      @hits.each do |hit|
        yield Document.open(hit["_source"]["id"])
      end
    end
  end
end
