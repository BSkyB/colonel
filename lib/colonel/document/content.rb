require 'json'

module Colonel

  # Public: Dynamically converts saved hashes to structs and support JSON (de)serialization.
  #
  # This is essentially an extended OpenStruct
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

    # Public: Access array element by index
    def [](i)
      @list[i]
    end

    # Public: Set array element by index
    def []=(i, val)
      @list[i] = val
    end

    # Public: Get hash value by key
    def get(key)
      @table[key.to_sym]
    end

    # Public: Set hash value for key
    def set(key, value)
      @table[key.to_sym] = value
    end

    # Public: Return a hash or array representation of the content
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

    # Public: Serialize content to JSON
    def to_json(state = nil)
      JSON.generate(@list || @table)
    end

    # Public: Load content from a JSON string
    def self.from_json(string)
      it = JSON.parse(string)
      new(it)
    end

    # Struct-like access

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
