require 'ostruct'
require 'json'

module Colonel

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

    def update(opts)
      if opts.is_a?(Array)
        @list = opts # overwrite array
      elsif opts.is_a?(Hash)
        for k,v in opts # merge hash
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

    def plain
      if @list
        @list.map do |item|
          item.is_a?(Content) ? item.plain : item
        end
      else
        result = {}
        @table.each do |k, v|
          result[k] = v.is_a?(Content) ? v.plain : v
        end

        result
      end
    end

    def to_json(state = nil)
      JSON.generate(@list || @table)
    end

    def self.from_json(string)
      it = JSON.parse(string)
      new(it)
    end

    def respond_to?(what)
      return true if @list && @list.respond_to?(what) || @table && @table.respond_to?(what)

      super
    end

    def method_missing(meth, *args, &block)
      if @list && @list.respond_to?(meth)
        @list.send(meth, *args, &block)
      elsif @table && @tbale.respond_to?(meth)
        @list.send(meth, *args, &block)
      else
        super
      end
    end

    def inspect
      "#<#{self.class} #{(@list || @table).inspect}>"
    end

    private

    def wrap(v)
      return self.class.new(v) if v.is_a?(Array) || v.is_a?(Hash)

      v
    end
  end
end
