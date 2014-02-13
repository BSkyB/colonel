
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
      @revision = commit!(@content, parents, 'refs/heads/master', 'save from git CMA', timestamp)
    end

    # State handling

    def rollback!(state)
      # update ref/heads/published to 1st parent commit
    end

    # rev is revision or a version name, defults to HEAD
    def load!(rev = nil)
      rev ||= repository.head.target

      begin
        rev_obj = repository.lookup(rev)
      rescue Rugged::InvalidError
        rev = Rugged::Reference.lookup(repository, "refs/heads/#{rev}").target
        rev_obj = repository.lookup(rev)
      end

      tree = rev_obj.tree
      file = repository.lookup(tree.first[:oid]).read_raw

      @content = file.data
      @revision = rev
    end

    def history(state = nil, stop = nil, &block)
      rev = if state
        ref = Rugged::Reference.lookup(repository, "refs/heads/#{state}")
        ref.target if ref
      else
        revision
      end

      results = []
      return results unless rev

      commit = repository.lookup(rev)
      while(commit)
        results << { rev: commit.oid, message: commit.message, author: commit.author, time: commit.time }
        yield results.last if block_given?

        break if commit.parents.length < 2 && state != 'master'

        commit = commit.parents.first
      end

      results unless block_given?
    end

    def promote!(from, to, message, timestamp)
      # commit, with parents ref/heads/to, ref/heads/from
      from_ref = Rugged::Reference.lookup(repository, "refs/heads/#{from}")
      to_ref = Rugged::Reference.lookup(repository, "refs/heads/#{to}")

      from_sha = from_ref.target
      to_sha = to_ref.target if to_ref

      commit!(@content, [to_sha, from_sha].compact, "refs/heads/#{to}", message, timestamp)
    end

    def rollback!(state)
      ref = Rugged::Reference.lookup(repository, "refs/heads/#{state}")
      sha = ref.target if ref

      commit = repository.lookup(sha)

      if commit.parents.length < 2
        ref.delete!
        return nil
      end

      parent = commit.parents.first.oid
      ref.set_target(parent)

      parent
    end

    # is this commit reachable as a direct ancestor of the given revision
    # i.e. for "published", was this revision merged into published
    def has_been_promoted?(to, rev = nil)
      rev ||= revision
      ref = Rugged::Reference.lookup(repository, "refs/heads/#{to}")
      return false unless ref

      start = ref.target

      commit = repository.lookup(start)
      has_ancestor?(commit, :first) do |bc|
        has_ancestor?(bc.parents.last, :last) do |ac|
          ac && ac.oid == rev
        end
      end
    end

    def repository
      @repo ||= Rugged::Repository.init_at("storage/#{name}", :bare)
    end

    class << self
      def open(name, rev = nil)
        repo = Rugged::Repository.new("storage/#{name}")
        doc = Document.new(name, repo: repo)
        doc.load!

        doc
      end
    end

    private

    def has_ancestor?(start, update, &block)
      while start
        return true if yield(start)
        break if start.parents.length < 2

        start = start.parents.send(update)
      end

      return false
    end

    def commit!(content, parents, ref, message, timestamp)
      oid = repository.write(@content, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)

      author = {email: 'git-cma@example.com', name: 'Git CMA', time: timestamp}
      options = {
        tree: tree,
        author: author,
        committer: author,
        message: message,
        parents: parents,
        update_ref: ref
      }

      @revision = Rugged::Commit.create(repository, options)
    end
  end
end
