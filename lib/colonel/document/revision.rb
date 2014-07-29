module Colonel
  # Public: A document revision, holding it's content and all metadata including links to previous and
  # origin revisions. Revisions are immutable and lazy loaded when opened. The minimal
  # revision contains only the id. When needed, the commit is loaded from the git repository to get
  # the history links and to get content, the tree and blob are loaded from the commit.
  #
  # To create a revision, you have to supply all the attributes on creation. When you want to write
  # the revision into the repository, call `write!`.
  class Revision
    attr_reader :state

    # Public: Create a revision
    #
    # document  - required, document the revision belongs to
    # content   - Content instance - content of the revision
    # author    - hash with :name and :email keys - author of the revision
    # message   - save message for this revision
    # timestamp - time of the save
    # previous  - Revision instance or string id - previous revision
    # origin    - Revision instance or string id - origin of a promotion revision
    # state     - String, state the revision was created in
    # commit_or_id - Rugged::Commit or string id - source of the revision used internally when opening
    #
    # For previous, origin and commit_or_id, you can pass a string id instead of the instance, the instance will
    # be lazy loaded when necessary. The only require parameter is document - content, author, etc... can be lazy
    # loaded from the commit.
    def initialize(document, content, author, message, timestamp, previous, origin = nil, state = nil, commit_or_id = nil)
      @document = document

      @id = commit_or_id if commit_or_id.is_a?(String)
      @commit = commit_or_id if commit_or_id.is_a?(Rugged::Commit)

      @content = content
      @author = author
      @message = message
      @timestamp = timestamp

      @state = state

      @previous = previous.is_a?(String) ? Revision.from_commit(@document, previous, state) : previous
      @origin = origin.is_a?(String) ? Revision.from_commit(@document, origin) : origin
    end

    # Public: id of the revision - a 40 character hexadecimal number which is the sha1 hash of the
    # underlying git commit.
    def id
      return @id if @id

      @id = commit.oid unless commit.nil?
    end

    # Public: author of the revision - a hash with :name and :email keys
    def author
      return @author if @author

      @author = commit.author unless commit.nil?
    end

    # Public: message passed in when the revision was created
    def message
      return @message if @message

      @message = commit.message unless commit.nil?
    end

    # Public: time of the revision's creation
    def timestamp
      return @timestamp if @timestamp

      @timestamp = commit.time unless commit.nil?
    end

    # Public: Type of the revision, can be one of :promotion, :save, or :orphan
    #
    # Only the initial revision of the document is an `:orphan`, all other revisions
    # are either a `:save` or a `:promotion`.
    def type
      return :promotion if origin
      return :save if previous

      :orphan
    end

    # Public: Content of the revision as a Content instance. Lazy loaded from the
    # repository on demand.
    def content
      return @content if @content.is_a?(Content)

      # lazy load content
      tree = commit.tree
      file = @document.repository.lookup(tree.first[:oid]).read_raw

      @content = Content.from_json(file.data)
    end

    # Public: Previous revision in the same state of the workflow.
    def previous
      return @previous if @previous

      prev = Revision.from_commit(@document, commit.parent_ids[0], state) unless commit.nil? || commit.parent_ids[0].nil?
      return nil if prev && prev.root?

      @previous = prev
    end

    # Public: Origin revision of the promotion. Promotion revisions will have
    # both `previous` and `origin` revisions, saves will only have a `previous`.
    def origin
      return @origin if @origin

      orig = Revision.from_commit(@document, commit.parent_ids[1], state) unless commit.nil? || commit.parent_ids[1].nil?
      return nil if orig && orig.root?

      @origin = orig
    end

    # Public: Checks whether a revision is the internal root revision which provides
    # regularity to the revision graph and simplifies searches.
    def root?
      id == @document.revisions.root_revision.id
    end

    # Public: Was this revision promoted to a given state? That is, is this commit reachable
    # as a direct ancestor of the given revision? Traverses the `to` state branch backwards
    # along the first (left) parents and for each of them checks the last (right) parents for
    # the specified revision.
    #
    # You can draw the history as a planar graph, where the timelines of each state are vertical
    # lines and the promotions go diagonally, up and to the left.
    #
    # The search starts with the top of a state branch and moves down stopping at each commit
    # and searching diagonally, stopping when it reaches `master`.
    #
    # to  - the final state of the promotion
    def has_been_promoted?(to)
      rev = @document.revisions[to]

      rev.has_ancestor?(:previous) do |p_rev|
        p_rev.has_ancestor?(:origin) do |o_rev|
          o_rev && o_rev.id == self.id
        end
      end
    end

    # Public: Checks whether revision has an ancestor passing the test specified by
    # the block. Search can be performed along one of the links - previous or origin
    #
    # direction      - :previous or :origin - how to get the next revision from the current one
    # block          - the test. Gets a revision object
    def has_ancestor?(direction, &block)
      rev = self

      while rev
        return true if yield(rev)

        rev = rev.send(direction)
      end

      return false
    end

    # Public: Write the revision into the document's repository, optionally updating a
    # reference
    def write!(repository, update_ref = nil)
      return unless @id.nil?
      oid = repository.write(@content.to_json, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)

      parents = [previous, origin].compact
      parents = parents.map(&:id).compact unless parents.empty?

      commit_options = {
        tree: tree,
        author: author,
        committer: author,
        message: message,
        parents: parents,
      }
      commit_options[:update_ref] = update_ref if update_ref

      @id = Rugged::Commit.create(repository, commit_options)
    end

    def inspect
      "<Revision:#{id}>"
    end

    # Class methods
    class << self
      # Public: Create a revision from a commit (or it's sha1 id)
      #
      # Because revisions are lazy loaded, the commit will be loaded for
      # an id only when needed.
      def from_commit(document, commit, state = nil)
        new(document, nil, nil, nil, nil, nil, nil, state, commit)
      end
    end

    private

    # Internal: The underlying Rugged::Commit, lazy loaded from the
    # repository when needed
    def commit
      return @commit if @commit

      if @id
        @commit = @document.repository.lookup(@id)
        raise ArgumentError, "Revision not found #{@id}." unless @commit

        @id = @commit.oid
      end

      @commit
    end
  end
end
