require 'spec_helper'
require 'base64'

describe Serializer do
  RSpec::Matchers.define :be_a_valid_dump do
    match do |dump|
      expect(dump).to be_a(String)
      lines = dump.split("\n")

      expect(lines.first).to match_regex(/^document:\s*.+$/)
      expect(lines[1]).to match_regex(/^references:$/)

      lines[2..-1].each do |line|
        expect(line).to satisfy { |it| (it =~ /^objects:$/) || (is_valid_json?(it)) }
      end
    end

    def is_valid_json?(string)
      JSON.parse(string); true rescue false
    end
  end

  let :time do
    Time.now
  end

  let :document do
    double(:document).tap do |doc|
      allow(doc).to receive(:repository).and_return(repository)
      allow(doc).to receive(:name).and_return("testdoc")
    end
  end

  let :repository do
    double(:repository).tap do |repo|
      allow(repo).to receive(:references)
      allow(repo).to receive(:lookup)
    end
  end

  let :author do
    { email: 'test@example.com', name: "Foo Bar", time: time }
  end

  let :master do
    double(:master).tap do |master|
      allow(master).to receive(:name).and_return("refs/heads/master")
      allow(master).to receive(:target_id)
    end
  end

  let :root_tag do
    double(:master).tap do |master|
      allow(master).to receive(:name).and_return("refs/tags/root")
      allow(master).to receive(:target_id).and_return(root_oid)
    end
  end

  let :raw do
    double(:raw).tap do |raw|
      allow(raw).to receive(:oid)
      allow(raw).to receive(:type)
      allow(raw).to receive(:data).and_return("abc")
      allow(raw).to receive(:len).and_return(3)
    end
  end

  let :tree_oid do
    "tree_id"
  end

  let :tree do
    double(:tree).tap do |tree|
      entry = { type: :blob, oid: blob_oid, mode: 33188, path: "content" }
      allow(tree).to receive(:oid).and_return(tree_oid)
      allow(tree).to receive(:first).and_return(entry)
      allow(tree).to receive(:read_raw).and_return(raw)
    end
  end

  let :blob_oid do
    "blob_id"
  end

  let :blob do
    double(:blob).tap do |blobg|
      allow(blobg).to receive(:read_raw).and_return(raw)
    end
  end

  let :first_commit do
    double(:first_commit).tap do |fc|
      allow(fc).to receive(:message)
      allow(fc).to receive(:time)
      allow(fc).to receive(:author)
      allow(fc).to receive(:tree_id).and_return(tree_oid)
      allow(fc).to receive(:tree).and_return(tree)
      allow(fc).to receive(:parent_ids).and_return([root_oid])
      allow(fc).to receive(:read_raw).and_return(raw)
    end
  end

  let :root_commit do
    double(:root_commit).tap do |rc|
      allow(rc).to receive(:message).and_return("message")
      allow(rc).to receive(:author).and_return(author)
      allow(rc).to receive(:tree_id).and_return(tree_oid)
      allow(rc).to receive(:tree).and_return(tree)
      allow(rc).to receive(:parent_ids).and_return([])
      allow(rc).to receive(:read_raw).and_return(raw)
    end
  end

  let :root_oid do
    "root"
  end

  it "should serialize a document with a single edit" do
    refs = [master, root_tag]
    allow(refs).to receive(:[]).with("refs/tags/root").and_return(root_tag)

    allow(repository).to receive(:references).and_return(refs)
    allow(master).to receive(:target_id).and_return("abcdef")

    expect(repository).to receive(:lookup).once.ordered.with(root_oid).and_return(root_commit)
    expect(repository).to receive(:lookup).once.ordered.with(blob_oid).and_return(blob)

    expect(repository).to receive(:lookup).once.ordered.with("abcdef").and_return(first_commit)
    expect(repository).to receive(:lookup).once.ordered.with(blob_oid).and_return(blob)

    stream = StringIO.new
    Serializer.generate(document, stream)
    dump = stream.string

    expect(dump).to be_a_valid_dump

    lines = dump.split("\n")

    expect(lines[0]).to eq("document: testdoc")
    expect(lines[1]).to eq("references:")

    head_ref = JSON.parse(lines[2])
    expect(head_ref).to have_key("name")
    expect(head_ref["name"]).to eq("HEAD")
    expect(head_ref).to have_key("type")
    expect(head_ref["type"]).to eq("symbolic")
    expect(head_ref).to have_key("target")
    expect(head_ref["target"]).to eq("refs/heads/master")

    master_ref = JSON.parse(lines[3])
    expect(master_ref).to have_key("name")
    expect(master_ref["name"]).to eq("refs/heads/master")
    expect(master_ref).to have_key("type")
    expect(master_ref["type"]).to eq("oid")
    expect(master_ref).to have_key("target")
    expect(master_ref["target"]).to eq("abcdef")

    root_tag = JSON.parse(lines[4])
    expect(root_tag).to have_key("name")
    expect(root_tag["name"]).to eq("refs/tags/root")
    expect(root_tag).to have_key("type")
    expect(root_tag["type"]).to eq("oid")
    expect(root_tag).to have_key("target")
    expect(root_tag["target"]).to eq(root_oid)
  end
end
