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
    allow(collection).to receive(:root_commit_oid).and_return("root")

    expect(document.repository).to receive(:lookup).with("abcdef").and_return(commit)
    expect(Revision).to receive(:from_commit).with(document, commit).and_return(revision)

    expect(collection["abcdef"]).to eq(revision)
  end

  it "finds a revision by ref" do
    ref = double(:reference).tap { |it| allow(it).to receive(:target_id).and_return("abcdef") }

    allow(collection).to receive(:root_commit_oid).and_return("root")

    expect(document.repository).to receive(:lookup).with("foo").once.and_raise(Rugged::InvalidError)

    expect(document.repository.references).to receive(:[]).with("refs/heads/foo").and_return(ref)
    expect(document.repository).to receive(:lookup).with("abcdef").once.and_return(commit)

    expect(Revision).to receive(:from_commit).with(document, commit).and_return(revision)

    expect(collection["foo"]).to eq(revision)
  end

  it "finds a root revision" do
    ref = double(:reference).tap { |it| allow(it).to receive(:target_id).and_return("root") }

    expect(document.repository.references).to receive(:[]).with(RevisionCollection::ROOT_REF).and_return(ref)
    expect(document.repository).to receive(:lookup).with("root").and_return(commit)

    expect(Revision).to receive(:from_commit).with(document, commit).and_return(revision)

    expect(collection.root_revision).to eq(revision)
  end
end
