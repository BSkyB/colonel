module Colonel
  class Revision
    attr_reader

    def initialize(document, content, author, message, timestamp, previous, origin = nil, commit_or_id = nil)
      @document = document

      @id = commit_or_id if commit_or_id.is_a?(String)
      @commit = commit_or_id if commit_or_id.is_a?(Rugged::Commit)

      @content = content
      @author = author
      @message = message
      @timestamp = timestamp

      @previous = previous.is_a?(String) ? Revision.from_commit(@document, previous) : previous
      @origin = origin.is_a?(String) ? Revision.from_commit(@document, origin) : origin
    end

    def id
      return @id if @id

      @id = commit.oid unless commit.nil?
    end

    def author
      return @author if @author

      @author = commit.author unless commit.nil?
    end

    def message
      return @message if @message

      @message = commit.message unless commit.nil?
    end

    def timestamp
      return @timestamp if @timestamp

      @timestamp = commit.timestamp unless commit.nil?
    end

    def content
      return @content if @content.is_a?(Content)

      # lazy load content
      tree = commit.tree
      file = @document.repository.lookup(tree.first[:oid]).read_raw

      @content = Content.from_json(file.data)
    end

    def previous
      return @previous if @previous

      @previous = Revision.from_commit(@document, commit.parent_ids[0]) unless commit.nil?
      return nil if @previous && @previous.root?

      @previous
    end

    def origin
      return @origin if @origin

      @origin = Revision.from_commit(@document, commit.parent_ids[1]) unless commit.nil?
      return nil if @origin && @origin.root?

      @origin
    end

    def state
      # state or nil "don't know"
    end

    def root?
      id == @document.revisions.root_revision.id
    end

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

    class << self
      def from_commit(document, commit)
        new(document, nil, nil, nil, nil, nil, nil, commit)
      end
    end

    private

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
