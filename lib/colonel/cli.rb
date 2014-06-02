require 'thor'

def load_dot_file!
  load(File.join(Dir.pwd, ".colonel"))
end

module Colonel
  class CLI < Thor

    desc "backup", "Backup content to an archive"
    def backup
      load_dot_file!

      index = DocumentIndex.new(Colonel.config.storage_path)
      docs = index.documents.map { |doc| Document.open(doc[:name]) }
      Serializer.generate(docs, STDOUT)
    end

    desc "restore", "Restore from a backup"
    method_option :input_file, type: :string, aliases: '-f'
    method_option :index_name, type: :string, aliases: '-i'
    method_option :content_items, type: :array, aliases: '-c'
    def restore
      load_dot_file!

      if options[:input_file]
        raise ArgumentError, "File input not implemented yet, consider using '< file'"
      else
        Serializer.load(STDIN)
      end

      if options[:content_items]
        perform_indexing(options[:index_name], options[:content_items])
      else
        warn "Not indexing the restored content, no content items specified. Use 'colonel index' if you forgot."
      end
    end

    desc "index", "Index documents in document index into elasticsearch"
    method_option :index_name, type: :string, aliases: '-i'
    method_option :content_items, type: :array, aliases: '-c', required: true
    def index
      load_dot_file!

      perform_indexing(options[:index_name], options[:content_items])
    end

    private

    def perform_indexing(index_name, content_items)
      Colonel.config.index_name = index_name if index_name

      index = DocumentIndex.new(Colonel.config.storage_path)
      docs = index.documents.map { |doc| Document.open(doc[:name]) }

      mapping = content_items.map do |klass|
        klass = eval(klass)
        type_name = klass.item_type_name

        [type_name, klass]
      end

      Indexer.index(docs, Hash[mapping])
    end
  end
end
