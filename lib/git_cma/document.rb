
module GitCma
  class Document
    attr_reader :name, :revision
    attr_accessor :content

    def initialize(name = nil, opts = {})
      @name = name || SecureRandom.hex(8) # FIXME check that the content id isn't already used
      @repo = opts[:repo]
      @revision = opts[:revision]
      @content = opts[:content]
    end

    def save(timestamp)
      oid = repository.write(@content, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)

      author = {email: 'git-cma@example.com', name: 'Git CMA', time: timestamp}
      options = {
        tree: tree,
        author: author,
        committer: author,
        message: 'save from Git CMA',
        parents: (repository.empty? ? [] : [repository.head.target].compact),
        update_ref: 'HEAD'
      }

      @revision = Rugged::Commit.create(repository, options)
    end

    # rev is revision or a version name, defults to HEAD
    def load(rev = nil)
      rev ||= repository.head.target

      tree = repository.lookup(rev).tree
      file = repository.lookup(tree.first[:oid]).read_raw

      @content = file.data
      @revision = rev
    end

    def revisions

    end

    # Versions - named revisions

    def named_versions

    end

    def name_version(name, revision = nil)

    end

    def repository
      @repo ||= Rugged::Repository.init_at("storage/#{name}", :bare)
    end

    class << self
      def open(name, rev = nil)
        repo = Rugged::Repository.new("storage/#{name}")
        doc = Document.new(name, repo: repo)
        doc.load

        doc
      end
    end
  end
end
