
module Colonel
  # Public: A versioned structured document storage with publishing pipeline support. Documents are internally
  # stored as a single file in a separate git repository for each document. Each state in the publishing
  # process is a separate branch. When saved, document serializes the content to JSON and saves it. Loading
  # a content item automatically constructs the data structure from the JSON.
  #
  # Every save to a document goes in as a commit to a master branch representing a draft stage. The
  # master branch is never reset, all changes only go forward.
  #
  # A promotion to a following state is recorded as a merge commit from the original state baranch to
  # a new state branch. New state revision is therefore not the same revision as the original revision.
  class Document
    attr_reader :id, :type

    # Public: create a new document
    #
    # content - Hash or an Array content of the document
    # options - an options Hash with extra attributes
    #           :repo    - rugged repository object when loading an existing document. (optional).
    #                      Not meant to be used directly
    def initialize(raw_content, opts = {})
      @id = opts[:id] || SecureRandom.hex(16) # FIXME check that the content id isn't already used / use UUID
      @repo = opts[:repo]
      @type = opts[:type] || DocumentType.get('document')

      unless @repo
        @content = Content.new(raw_content)
      end
    end

    # Public: Content of the latest revision in the 'master' state, or content updated
    # by the user, ready to save
    def content
      @content ||= revisions['master'].content
    end

    # Public: Replace the content with another.
    # content - Hash or Array with content (see Content#new) or Content instance
    #
    # Returns a new instance of Content
    def content=(new_content)
      @content = (new_content.is_a?(Content) ? new_content : Content.new(new_content))
    end

    # Public: RevisionCollection for this document
    #
    # Call `document.revisions[sha]` or `document.revisions[state]`
    def revisions
      @revisions ||= RevisionCollection.new(self)
    end

    # Public: List the history of a given state.
    #
    # state   - list history of a given state, e.g. `published`. (optional)
    # block   - yield each revision to the block as it's traversed. Useful for early termination
    #
    # Returns an array of revision hashes if no block was given, otherwise yields every revision
    # to the block and returns nothing.
    def history(id_or_state = 'master', &block)
      return to_enum(:history, id_or_state) unless block_given?

      revision = revisions[id_or_state]

      while(revision)
        yield revision

        revision = revision.previous
      end
    end

    # Public: save the document as a new revision. Commits the content to the top of `master`,
    # and updates `master`
    #
    # author    - a Hash containing author attributes
    #             :name - the name of the author
    #             :email - the email of the author
    # message   - message for the commit (optional)
    # timestamp - time of the save (optional), Defaults to Time.now
    #
    # Returns the sha of the created revision
    def save!(author, message = '', timestamp = Time.now)
      save_in!('master', author, message, timestamp)
    end

    # Public: save the document as a new revision. Commits the content to the top of `state`
    # and updates the Document's revision to the newly created commit.
    #
    # WARNING: Do not use this lightly. Usually, you want to only save new changes into the
    # `master` state, as it creates nice properties for working with the workflow. Sometimes
    # it is necessary to update a document in another state, and that's what this method
    # is for. Note also that saving in a later state breaks the promotion chain, so the revisions
    # promoted from `master` to the one saved over will no longer say they were promoted to
    # later states the result of the save was promoted to.
    #
    # state     - the name of the state in which to save changes
    # author    - a Hash containing author attributes
    #             :name - the name of the author
    #             :email - the email of the author
    # message   - message for the commit (optional)
    # timestamp - time of the save (optional), Defaults to Time.now
    #
    # Returns the sha of the created revision
    def save_in!(state, author, message = '', timestamp = Time.now)
      ref = "refs/heads/#{state}"
      init_repository(repository, timestamp)

      previous = revisions[state] || revisions.root_revision
      revision = Revision.new(self, content, author, message, timestamp, previous)

      revision.write!(repository, ref)

      index.register(id, type.type)
      search_provider.index!(self, revision, state, {name: :save, to: state}) if search_provider

      revision
    end

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
      ref = "refs/heads/#{to}"
      origin = revisions[from]
      previous = revisions[to] || revisions.root_revision
      raise ArgumentError, "No revision for state #{from}" unless origin

      revision = Revision.new(self, origin.content, author, message, timestamp, previous, origin)
      oid = revision.write!(repository, ref)

      search_provider.index!(self, revision, to, {name: :promotion, to: to}) if search_provider

      revision
    end

    # Internal methods

    # Internal: The Rugged repository object for the given document
    def repository
      unless Colonel.config.rugged_backend.nil?
        @repo ||= Rugged::Repository.init_at(File.join(Colonel.config.storage_path, id), :bare, backend: Colonel.config.rugged_backend)
      else
        @repo ||= Rugged::Repository.init_at(File.join(Colonel.config.storage_path, id), :bare)
      end
    end

    # Internal: Initialise the repository, creating a tagged root revision
    def init_repository(repository, timestamp = Time.now)
      return if revisions.root_revision

      # create the root revision
      revision = Revision.new(self, "", { name: 'The Colonel', email: 'colonel@example.com' }, "First Commit", timestamp, nil)

      oid = revision.write!(repository)
      repository.references.create(RevisionCollection::ROOT_REF, oid)
    end

    # Internal: Document index to register the document with when saving to keep track of it
    def index
      @index ||= self.class.index
    end

    def search_provider
      type.search_provider
    end

    # Class methods
    class << self
      def list(*args)
        DocumentType.get('document').list(*args)
      end

      def search(*args)
        DocumentType.get('document').search(*args)
      end

      def open(*args)
        DocumentType.get('document').open(*args)
      end

      # Internal: Document index to register the document with when saving to keep track of it
      def index
        DocumentIndex.new(Colonel.config.storage_path)
      end
    end
  end
end
