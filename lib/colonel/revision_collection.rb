class RevisionCollection
  ROOT_REF = 'refs/tags/root'.freeze

  def initialize(document)
    @document = document
  end

  def [](rev)
    begin
      commit = @document.repository.lookup(rev)
    rescue Rugged::InvalidError
      ref = @document.repository.references["refs/heads/#{rev}"]
      return nil unless ref

      commit = @document.repository.lookup(ref.target_id)
    end

    Revision.from_commit(@document, commit)
  end

  def root_revision
    self[root_commit_oid]
  end

  private

  def root_commit_oid
    @root_commit_oid ||= @document.repository.references[ROOT_REF].target_id
  end
end
