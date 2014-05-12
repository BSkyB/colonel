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
      docs = index.documents.map { |doc| Document.open(doc) }
      Serializer.generate(docs, STDOUT)
    end

    desc "restore", "Restore from a backup"
    method_option :input, type: :string, aliases: '-i'
    def restore
      load_dot_file!

      if options[:input]
        raise ArgumentError, "File input not implemented yet, consider using '< file'"
      else
        Serializer.load(STDIN)
      end
    end
  end
end
