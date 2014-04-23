
module Colonel
  # Public: A versioned document storage with publishing pipeline support. Documents are internally
  # stored as a single file in a separate git repository for each document. Each state in the publishing
  # process is a separate branch.
  #
  # Every save to a document goes in as a commit to a master branch representing a draft stage. The
  # master branch is never reset, all changes only go forward.
  #
  # A promotion to a following state is recorded as a merge commit from the original state baranch to
  # a new state branch. New state revision is therefore not the same revision as the original revision.
  # Documents in all states except `master` can be rolled back to their previous revision (git reset), and
  # a revision history is available for each state separately.
  class Document
    attr_reader :name, :revision
    attr_accessor :content

    # Public: create a new document
    #
    # name    - the name of the document, must be a valid filename. Will be generated randomly if not provided
    # options - an options Hash with extra attributes
    #           :content - the new document's content (optional)
    #           :repo    - rugged repository object when loading an existing document. (optional).
    #                      Not meant to be used directly
    def initialize(name = nil, opts = {})
      @name = name || SecureRandom.hex(16) # FIXME check that the content id isn't already used
      @repo = opts[:repo]
      @content = opts[:content]
    end

    # Storage

    # Public: save the document as a new revision. Commits the content to the top of `master`, updates `master`
    # and updates the Document's revision to the newly created commit.
    #
    # author    - a Hash containing author attributes
    #             :name - the name of the author
    #             :email - the email of the author
    # message   - message for the commit (optional)
    # timestamp - time of the save (optional), Defaults to Time.now
    #
    # Returns the sha of the created revision
    def save!(author, message = '', timestamp = Time.now)
      parents = (repository.empty? ? [] : [repository.head.target_id].compact)
      @revision = commit!(@content, parents, 'refs/heads/master', author, message, timestamp)
    end

    # Public: loads the revision specified by `rev`. Updates content and revision of the Document
    #
    # rev - the revision to load. Can be a sha or a state name (e.g. `published`).
    #        Defaults to `master` (optional)
    #
    # Returns the sha of the loaded revision.
    def load!(rev = nil)
      rev ||= repository.head.target_id

      begin
        rev_obj = repository.lookup(rev)
      rescue Rugged::InvalidError
        rev = repository.references["refs/heads/#{rev}"].target_id
        rev_obj = repository.lookup(rev)
      end

      tree = rev_obj.tree
      file = repository.lookup(tree.first[:oid]).read_raw

      @content = file.data
      @revision = rev
    end

    # Public: List all the revisions.
    #
    # state   - list history of a given state, e.g. `published`. (optional)
    # block   - yield each revision to the block as it's traversed. Useful for early termination
    #
    # Returns an array of revision hashes if no block was given, otherwise yields every revision
    # to the block and returns nothing.
    def history(state = nil, &block)
      rev = if state
        ref = repository.references["refs/heads/#{state}"]
        rev = ref.target_id if ref
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

    # Publishing pipeline handling


    # Public: Promotes the latest revision in state `from` to state `to`. Creates a merge commit on
    # branch `to` with a `message` and `timestamp`
    #
    # from      - initial state, the latest revision of which will be promoted
    # to        - final state, a new revision will be created in it
    # author    - a Hash containing author attributes
    #             :name - the name of the author
    #             :email - the email of the author
    # message   - message for the commit (optional)
    # timestamp - time of the save (optional), Defaults to Time.now
    #
    # Returns the sha of the created revision.
    def promote!(from, to, author, message = '', timestamp = Time.now)
      from_ref = repository.references["refs/heads/#{from}"]
      to_ref = repository.references["refs/heads/#{to}"]

      from_sha = from_ref.target_id
      to_sha = to_ref.target_id if to_ref

      commit!(@content, [to_sha, from_sha].compact, "refs/heads/#{to}", author, message, timestamp)
    end

    # Public: Was this revision promoted to a given state? That is, is this commit reachable
    # as a direct ancestor of the given revision? Traverses the `to` state branch backwards
    # along the first (left) parents and for each of them checks the last (right) parents for
    # the specified revision.
    # If you draw the history as a graph, where the timelines of each state are vertical and
    # the promotions go diagonally, up and to the left, you can clearly see there must be a
    # second shooter on the grassy kn... aehm... sorry. The search starts with the top of a
    # state branch and moves down stopping at each commit and searching diagonally, stopping
    # when it reaches `master`.
    #
    # to  - the final state of the promotion
    # rev - the revision to look for, default to the current revision (optional)
    def has_been_promoted?(to, rev = nil)
      rev ||= revision
      ref = repository.references["refs/heads/#{to}"]
      return false unless ref

      start = ref.target_id

      commit = repository.lookup(start)
      has_ancestor?(commit, :first) do |bc|
        has_ancestor?(bc.parents.last, :last) do |ac|
          ac && ac.oid == rev
        end
      end
    end

    # Public: Roll back the current revision in a given state to the previous one in that state.
    # If there is no previous revision in the given state, remove the state branch. Doesn't load
    # the revision rolled back to by default, you have to do it manually if required.
    #
    # state - the state to roll back (e.g. 'published')
    #
    # Returns the new current revision in the given state
    def rollback!(state)
      ref = repository.references["refs/heads/#{state}"]
      sha = ref.target_id if ref

      commit = repository.lookup(sha)

      if commit.parents.length < 2
        ref.delete!
        return nil
      end

      parent = commit.parents.first.oid
      ref.set_target(parent)

      parent
    end

    # Internal: The Rugged repository object for the given document
    def repository
      unless Colonel.config.rugged_backend.nil?
        @repo ||= Rugged::Repository.init_at(File.join(Colonel.config.storage_path, @name), :bare, backend: Colonel.config.rugged_backend)
      else
        @repo ||= Rugged::Repository.init_at(File.join(Colonel.config.storage_path, @name), :bare)
      end
    end

    # Class methods
    class << self

      # Public: Open the document specified by `name`, optionally at a revision `rev`
      #
      # name  - name of the document
      # rev   - revision to load (optional)
      #
      # Returns a Document instance
      def open(name, rev = nil)
        begin
          unless Colonel.config.rugged_backend.nil?
            repo = Rugged::Repository.bare(File.join(Colonel.config.storage_path, name), backend: Colonel.config.rugged_backend)
          else
            repo = Rugged::Repository.bare(File.join(Colonel.config.storage_path, name))
          end
        rescue Rugged::OSError
          return nil
        end

        doc = Document.new(name, repo: repo)
        doc.load!(rev)

        doc
      end
    end

    private

    # Internal: Checks whether a `start` commit has an ancestor passing the test specified by
    # the block. Stops after a commit with a single parent is tested, to avoid switching branches
    #
    # start   - Rugged commit object to start with
    # update  - the update message to send to the commit parrents to get the next one in line
    # block   - the test. Gets a commit object
    def has_ancestor?(start, update, &block)
      while start
        return true if yield(start)
        break if start.parents.length < 2

        start = start.parents.send(update)
      end

      return false
    end

    # Internal: Commit contents of the document with a given parent commits, reference to update
    # message and timestamp.
    #
    # content   - the document content, commited as a file named 'content' in the root of the repository
    # parents   - array of parent commit shas
    # author    - a Hash containing author attributes
    #             :name - the name of the author
    #             :email - the email of the author
    # message   - the commit message to store
    # timestamp - time of the commit
    #
    # Returns the sha of the new commit
    def commit!(content, parents, ref, author, message = '', timestamp = Time.Now)
      oid = repository.write(@content, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)
      author.merge! time: timestamp

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
