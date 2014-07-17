class RevisionCollection
  ROOT_REF = 'refs/tags/root'.freeze

  def initialize(document)
    @document = document
  end

  def [](rev)
    begin
      return nil if rev == root_commit_oid

      commit = @document.repository.lookup(rev)
    rescue Rugged::InvalidError
      ref = @document.repository.references["refs/heads/#{rev}"]
      return nil unless ref && ref.target_id != root_commit_oid

      commit = @document.repository.lookup(ref.target_id)
    end

    Revision.from_commit(@document, commit)
  end

  def root_revision
    return nil unless root_commit_oid

    commit = @document.repository.lookup(root_commit_oid)
    Revision.from_commit(@document, commit)
  end

  private

  def root_commit_oid
    return @root_commit_oid if @root_commit_oid

    ref = @document.repository.references[ROOT_REF]
    @root_commit_oid = ref.target_id if ref

    @root_commit_oid
  end
end
