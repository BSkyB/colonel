module Colonel
  class Revision
    attr_reader :id, :content, :author, :message, :previous, :origin

    def initialize(content, author, message, previous, origin = nil, id = nil)
      @id = id
      @content = content
      @author = author
      @message = message
      @previous = previous
      @origin = origin
    end

    def content=(val)
      readonly_error unless @content
      @content = val
    end

    def author=(val)
      readonly_error unless @author
      @author = val
    end

    def message=(val)
      readonly_error unless @message
      @message = val
    end

    def previous=(val)
      readonly_error unless @previous
      @previous = val
    end

    def origin=(val)
      readonly_error unless @origin
      @origin = val
    end

    def write!(repository, update_ref)
      return unless @id.nil?
      oid = repository.write(@content.to_json, :blob)

      index = Rugged::Index.new
      index.add(path: 'content', oid: oid, mode: 0100644)
      tree = index.write_tree(repository)

      commit_options = {
        tree: tree,
        author: author,
        committer: author,
        message: message,
        parents: [previous.id, origin.id].compact,
        update_ref: update_ref
      }

      @id = Rugged::Commit.create(repository, commit_options)
    end

    private

    def readonly_error
      raise RuntimeError, 'Revision is immutable.'
    end
  end
end
