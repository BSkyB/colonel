require 'thor'

module Colonel
  class CLI < Thor
    # TODO add support for config override in .colonel

    desc "backup", "Backup content to an archive"
    def backup
      index = DocumentIndex.new(Colonel.config.storage_path)
      docs = index.documents.map { |doc| Document.open(doc) }
      Serializer.generate(docs, STDOUT)
    end

    desc "restore", "Restore from a backup"
    method_option :input, type: :string, aliases: '-i'
    def restore
      if options[:input]
        raise ArgumentError, "File input not implemented yet, consider using '< file'"
      else
        Serializer.load(STDIN)
      end
    end
  end
end
