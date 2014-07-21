require 'spec_helper'

describe Revision do
  let(:time) { Time.now }

  let(:document) do
    double(:document).tap { |it| allow(it).to receive(:revisions).and_return(double(:revisions)) }
  end

  let :revision do
    Revision.new(double(:document), Conent.new({foo: "bar"}), {name: "Author", email: "me@example.com"}, "Saved", time)
  end

  it "stores content, author, message and timestamp" do
    revision = Revision.new(document, Content.new({foo: "bar"}), "author", "message", time, "abcdef")

    expect(revision.content.foo).to eq("bar")
    expect(revision.author).to eq("author")
    expect(revision.message).to eq("message")
    expect(revision.timestamp).to eq(time)
  end

  it "takes a commit and can use its id" do
    commit = double(:commit)

    allow(commit).to receive(:is_a?).with(String).and_return(false)
    allow(commit).to receive(:is_a?).with(Rugged::Commit).and_return(true)

    revision = Revision.new(document, Content.new(nil), "author", "message", time, "abcdef", nil, commit)

    expect(commit).to receive(:oid).and_return("id")

    expect(revision.id).to eq("id")
  end

  it "can check it's a root revision" do
    revision = Revision.new(document, Content.new(nil), "author", "message", time, nil)
    root_revision = double(:root_revision).tap do |it|
      allow(it).to receive(:id).and_return("root_id")
    end

    allow(revision).to receive(:id).and_return("root_id")
    allow(document.revisions).to receive(:root_revision).and_return(root_revision)

    expect(revision.root?).to eq(true)
  end

  describe "lazy loading" do
    it "can create a revision from a sha1 without touching the repository" do
      sha = "abcdef"

      expect(document).not_to receive(:repository)

      rev = Revision.from_commit(document, sha)
      expect(rev.id).to eq("abcdef")
    end

    it "can create a revision from just a sha1 and load the commit for details" do
      sha = "abcdef"
      repo = double(:repository)

      commit = double(:commit).tap do |it|
        allow(it).to receive(:message).and_return("hi")
        allow(it).to receive(:oid).and_return("xyz")
      end

      expect(document).to receive(:repository).and_return(repo)
      expect(repo).to receive(:lookup).with("abcdef").and_return(commit)

      rev = Revision.from_commit(document, sha)

      expect(rev.id).to eq("abcdef") # id from the passed string

      expect(rev.message).to eq("hi")
      expect(rev.id).to eq("xyz") # id from the loaded commit. In reality the two ids will be the same
    end

    # it "loads content from the commit when necessary" - tested through cucumber
  end
end
