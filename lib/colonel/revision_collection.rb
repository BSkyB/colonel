class RevisionCollection
  ROOT_REF = 'refs/tags/root'.freeze
  SHA1 = /^[0-9a-f]{40}$/

  def initialize(document)
    @document = document
  end

  def [](rev)
    return nil if rev == root_commit_oid
    return Revision.from_commit(@document, rev) if rev =~ SHA1

    ref = @document.repository.references["refs/heads/#{rev}"]
    return nil unless ref && ref.target_id != root_commit_oid

    Revision.from_commit(@document, ref.target_id, rev)
  end

  def root_revision
    return @root_revision if @root_revision
    return nil unless root_commit_oid

    @root_revision = Revision.from_commit(@document, root_commit_oid)
  end

  private

  def root_commit_oid
    return @root_commit_oid if @root_commit_oid

    ref = @document.repository.references[ROOT_REF]
    @root_commit_oid = ref.target_id if ref

    @root_commit_oid
  end
end
