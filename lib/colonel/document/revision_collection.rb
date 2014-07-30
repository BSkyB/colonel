module Colonel
  # Public: Collection of revisions of a given document. Surfaced on the document
  # through the `revisions` method. Allows searching for revisions by id or state
  # name and keeps track of the internal root revision
  class RevisionCollection
    ROOT_REF = 'refs/tags/root'.freeze
    SHA1_REGEX = /^[0-9a-f]{40}$/

    # Internal: Creates a new collection for a document. You should never
    # need to call this method directly
    def initialize(document)
      @document = document
    end

    # Public: Lookup a revision.
    #
    # rev - sha1 id of the revision or a state name.
    #
    # When a state name is passed, the latest revision in that state
    # will be returned.
    def [](rev)
      return nil if rev == root_commit_oid
      return Revision.from_commit(@document, rev) if rev =~ SHA1_REGEX

      ref = @document.repository.references["refs/heads/#{rev}"]
      return nil unless ref && ref.target_id != root_commit_oid

      Revision.from_commit(@document, ref.target_id, rev)
    end

    # Internal: Root revision
    #
    # Root revision is a revision created with the document repository
    # used as a previous revision for every first revision of a given
    # state. That simplifies the search along a given state, allowing you
    # to easily tell when you reached the end and you should stop.
    def root_revision
      return @root_revision if @root_revision
      return nil unless root_commit_oid

      @root_revision = Revision.from_commit(@document, root_commit_oid)
    end

    private

    # Internal: The id of the root revision
    def root_commit_oid
      return @root_commit_oid if @root_commit_oid

      ref = @document.repository.references[ROOT_REF]
      @root_commit_oid = ref.target_id if ref

      @root_commit_oid
    end
  end
end
