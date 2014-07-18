require 'spec_helper'

describe Revision do
  let(:time) { Time.now }

  let(:document) { double(:document) }

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
    allow(commit).to receive(:is_a?).with(Rugged::Commit).and_return(true)

    revision = Revision.new(document, Content.new(nil), "author", "message", time, "abcdef", nil, commit)

    expect(commit).to receive(:oid).and_return("id")

    expect(revision.id).to eq("id")
  end

  it "looks up a commit from a sha1 passed in" do
    commit = double(:commit).tap do |it|
      allow(it).to receive(:is_a?).with(Rugged::Commit).and_return(true)
      allow(it).to receive(:oid).and_return("the_id")
    end

    repo = double(:repository)

    revision = Revision.new(document, nil, "author", "message", time, "abcdef", nil, "abcd")

    expect(document).to receive(:repository).and_return(repo)
    expect(repo).to receive(:lookup).with("abcd").and_return(commit)

    expect(revision.id).to eq("the_id")
  end

  # read / write are tested in the cucumber features (too much mocking involved...)

  it "can create a revision from a commit" do
    commit = double(:commit).tap do |it|
      allow(it).to receive(:author).and_return(:author)
      allow(it).to receive(:message).and_return(:message)
      allow(it).to receive(:time).and_return(:time)
      allow(it).to receive(:parent_ids).and_return([:id_0, :id_1])
    end

    expect(Revision).to receive(:new).with(document, nil, :author, :message, :time, :id_0, :id_1, commit)

    Revision.from_commit(document, commit)
  end
end
