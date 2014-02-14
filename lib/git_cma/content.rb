require 'ostruct'
require 'json'

module GitCma

  # Public: Extends OpenStruct to dynamically convert saved hashes to structs and support JSON (de)serialization.
  class Content < OpenStruct

    def initialize(opts = {})
      if opts.is_a?(Array)
        @list = opts.map { |v| wrap(v) }
        @table = {}
      elsif opts.is_a?(Hash)
        @table = {}
        for k,v in opts
          @table[k.to_sym] = wrap(v)
          new_ostruct_member(k)
        end
      end
    end

    def [](i)
      @list[i]
    end

    def []=(i, val)
      @list[i] = val
    end

    def to_json(state = nil)
      JSON.generate(@list || @table)
    end

    def self.from_json(string)
      it = JSON.parse(string)
      new(it)
    end

    private

    def wrap(v)
      return self.class.new(v) if v.is_a?(Array) || v.is_a?(Hash)

      v
    end
  end
end
