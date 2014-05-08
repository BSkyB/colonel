require 'thor'

module Colonel
  class CLI < Thor
    # TODO add support for config override in .colonel

    desc "backup", "Backup content to an archive"
    def backup
      puts "Not implemented yet... (storage_path: #{Colonel.config.storage_path})"
    end

    desc "restore", "Restore from a backup"
    method_option :input, type: :string, aliases: '-i'
    def restore
      puts "Not implemented yet... (storage_path: #{Colonel.config.storage_path}, input: #{options[:input]})"
    end
  end
end
