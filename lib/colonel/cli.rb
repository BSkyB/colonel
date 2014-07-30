require 'thor'

def load_dot_file!
  begin
    load(File.join(Dir.pwd, ".colonel"))
  rescue LoadError
  end
end

module Colonel
  class CLI < Thor

    desc "backup", "Backup content to an archive"
    def backup
      load_dot_file!

      index = DocumentIndex.new(Colonel.config.storage_path)
      docs = index.documents.map do |doc|
        type = DocumentType.get(doc[:type])
        type.open(doc[:name])
      end
      Serializer.generate(docs, STDOUT)
    end

    desc "restore", "Restore from a backup"
    method_option :input_file, type: :string, aliases: '-f'
    method_option :index_name, type: :string, aliases: '-i'
    def restore
      load_dot_file!

      if options[:input_file]
        raise ArgumentError, "File input not implemented yet, consider using '< file'"
      else
        Serializer.load(STDIN)
      end

      perform_indexing(options[:index_name])
    end

    desc "index", "Index documents in document index into elasticsearch"
    method_option :index_name, type: :string, aliases: '-i'
    def index
      load_dot_file!

      perform_indexing(options[:index_name])
    end

    private

    def perform_indexing(index_name)
      index = DocumentIndex.new(Colonel.config.storage_path)

      docs = index.documents.map do |doc|
        type = DocumentType.get(doc[:type])
        type.open(doc[:name])
      end

      puts "Indexing into #{index_name || 'default index'}..."
      Indexer.index(docs, index_name)
    end
  end
end
