require 'json'

module Colonel

  # Public: Dynamically converts saved hashes to structs and support JSON (de)serialization.
  class Content
    def initialize(plain = {})
      if plain.is_a?(Array)
        @list = plain.map { |v| wrap(v) }
        @table = {}
      elsif plain.is_a?(Hash)
        @table = {}
        for k,v in plain
          @table[k.to_sym] = wrap(v)
        end
      end
    end

    def update(opts)
      if opts.is_a?(Array)
        @list = opts # overwrite array
      elsif opts.is_a?(Hash)
        for k,v in opts # merge hash
          @table[k.to_sym] = wrap(v)
        end
      end
    end

    def [](i)
      @list[i]
    end

    def []=(i, val)
      @list[i] = val
    end

    def get(key)
      @table[key.to_sym]
    end

    def set(key, value)
      @table[key.to_sym] = value
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
      elsif meth =~ /=$/ && args.length == 1
        set(meth.to_s.chop, args[0])
      elsif @table && @table.has_key?(meth.to_sym)
        get(meth)
      elsif @table && @table.respond_to?(meth)
        @table.send(meth, *args, &block)
      elsif args.length < 1 && !block_given?
        nil
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
