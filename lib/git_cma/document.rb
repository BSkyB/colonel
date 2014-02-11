
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
      parents = (repository.empty? ? [] : [repository.head.target].compact)
      commit!(@content, parents, 'refs/heads/master', timestamp)
    end

    # State handling

    def preview!(timestamp)
      transition!('master', 'preview')
    end

    def publish!(timestamp)
      transition!('preview', 'published')
    end

    def transition!(from, to, timestamp)
      # commit, with parents ref/heads/to, ref/heads/from
      # update ref/heads/to
    end

    def rollback!(state)
      # update ref/heads/published to 1st parent commit
    end

    # rev is revision or a version name, defults to HEAD
    def load(rev = nil)
      rev ||= repository.head.target

      tree = repository.lookup(rev).tree
      file = repository.lookup(tree.first[:oid]).read_raw

      @content = file.data
      @revision = rev
    end

    def history(state = nil, stop = nil, &block)
      rev = if state
        Rugged::Reference.lookup(repository, "refs/heads/#{state}").target
      else
        revision
      end

      # walk the history
      commit = repository.lookup(rev)
      while(commit)
        yield({ rev: commit.oid, message: commit.message, author: commit.author, time: commit.time })
        commit = commit.parents.first
      end
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

    private

    def commit!(content, parents, ref, timestamp)
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
        parents: parents,
        update_ref: ref
      }

      @revision = Rugged::Commit.create(repository, options)
    end
  end
end
