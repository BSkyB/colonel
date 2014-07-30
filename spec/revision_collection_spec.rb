require 'spec_helper'

describe RevisionCollection do
  let :document do
    double(:document).tap do |it|
      allow(it).to receive(:repository).and_return(
        double(:repository).tap { |it| allow(it).to receive(:references).and_return(double(:references)) }
      )
    end
  end

  let(:revision) { double(:revision) }
  let(:commit) { double(:commit) }

  let :collection do
    RevisionCollection.new(document)
  end

  it "finds a revision by id" do
    sha1 = "0000000000000000000000000000000000000000"

    allow(collection).to receive(:root_commit_oid).and_return("root")
    expect(Revision).to receive(:from_commit).with(document, sha1).and_return(revision)

    expect(collection[sha1]).to eq(revision)
  end

  it "finds a revision by ref" do
    ref = double(:reference).tap { |it| allow(it).to receive(:target_id).and_return("abcdef") }

    allow(collection).to receive(:root_commit_oid).and_return("root")

    expect(document.repository.references).to receive(:[]).with("refs/heads/foo").and_return(ref)
    expect(Revision).to receive(:from_commit).with(document, "abcdef", "foo").and_return(revision)

    expect(collection["foo"]).to eq(revision)
  end

  it "finds a root revision" do
    ref = double(:reference).tap { |it| allow(it).to receive(:target_id).and_return("root") }

    expect(document.repository.references).to receive(:[]).with(RevisionCollection::ROOT_REF).and_return(ref)

    expect(Revision).to receive(:from_commit).with(document, "root").and_return(revision)

    expect(collection.root_revision).to eq(revision)
  end

  describe "state handling" do
    it "doesn't set state on revisions found by id" do
      sha1 = "0000000000000000000000000000000000000000"

      allow(collection).to receive(:root_commit_oid).and_return("root")

      revision = collection[sha1]
      expect(revision.state).to be_nil
    end

    it "sets state on revisions found by state" do
      ref = double(:reference).tap { |it| allow(it).to receive(:target_id).and_return("abcdef") }

      allow(collection).to receive(:root_commit_oid).and_return("root")
      allow(document.repository.references).to receive(:[]).with("refs/heads/master").and_return(ref)

      revision = collection["master"]
      expect(revision.state).to eq("master")
    end
  end
end
