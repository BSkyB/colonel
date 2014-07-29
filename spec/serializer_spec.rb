require 'spec_helper'
require 'base64'

describe Serializer do
  RSpec::Matchers.define :be_a_valid_dump do
    match do |dump|
      expect(dump).to be_a(String)
      lines = dump.split("\n")

      expect(lines.first).to match_regex(/^document:\s*(\S+)\s+(.+)$/)
      expect(lines[1]).to match_regex(/^objects:$/)

      lines[2..-1].each do |line|
        expect(line).to satisfy { |it| (it =~ /^references:$/) || (is_valid_json?(it)) }
      end
    end

    def is_valid_json?(string)
      JSON.parse(string); true rescue false
    end
  end

  describe "writing" do
    let :time do
      Time.now
    end

    let :document do
      double(:document).tap do |doc|
        allow(doc).to receive(:repository).and_return(repository)
        allow(doc).to receive(:name).and_return("testdoc")
        allow(doc).to receive(:type).and_return("test-type")
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
      pending "fix for new API"

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

      expect(lines[0]).to eq("document: testdoc test-type")
      expect(lines[1]).to eq("objects:")

      i = 2
      until(lines[i] == "references:" || lines[i].nil?)
        i += 1
      end

      head_ref = JSON.parse(lines[i+1])
      expect(head_ref).to have_key("name")
      expect(head_ref["name"]).to eq("HEAD")
      expect(head_ref).to have_key("type")
      expect(head_ref["type"]).to eq("symbolic")
      expect(head_ref).to have_key("target")
      expect(head_ref["target"]).to eq("refs/heads/master")

      master_ref = JSON.parse(lines[i+2])
      expect(master_ref).to have_key("name")
      expect(master_ref["name"]).to eq("refs/heads/master")
      expect(master_ref).to have_key("type")
      expect(master_ref["type"]).to eq("oid")
      expect(master_ref).to have_key("target")
      expect(master_ref["target"]).to eq("abcdef")

      root_tag = JSON.parse(lines[i+3])
      expect(root_tag).to have_key("name")
      expect(root_tag["name"]).to eq("refs/tags/root")
      expect(root_tag).to have_key("type")
      expect(root_tag["type"]).to eq("oid")
      expect(root_tag).to have_key("target")
      expect(root_tag["target"]).to eq(root_oid)
    end
  end

  describe "reading" do
    let :dump do
      <<-EOF
document: test-document document
objects:
{"oid":"top-commit","type":"commit","data":"dGVzdGRhdGE=","len":8}
{"oid":"top-tree","type":"tree","data":"dGVzdGRhdGE=","len":8}
{"oid":"top-content","type":"blob","data":"dGVzdGRhdGE=","len":8}
{"oid":"root-commit","type":"commit","data":"dGVzdGRhdGE=","len":8}
{"oid":"root-tree","type":"tree","data":"dGVzdGRhdGE=","len":8}
{"oid":"root-content","type":"blob","data":"dGVzdGRhdGE=","len":8}
references:
{"name":"HEAD","type":"symbolic","target":"refs/heads/master"}
{"name":"refs/heads/master","type":"oid","target":"top-commit"}
{"name":"refs/tags/root","type":"oid","target":"root-commit"}
EOF
    end

    let :repo do
      double(:repository).tap do |it|
        allow(it).to receive(:references).and_return(refs)
      end
    end

    let :refs do
      double(:references).tap do |it|
        allow(it).to receive(:create)
        allow(it).to receive(:[])
      end
    end

    let :document do
      double(:document).tap do |it|
        allow(it).to receive(:repository).and_return(repo)
        allow(it).to receive(:id).and_return("test-document")
      end
    end

    let :index do
      double(:index).tap do |it|
        allow(it).to receive(:register)
      end
    end

    it "should load a simple document" do
      allow(Document).to receive(:new).with(nil, id: "test-document", type: DocumentType.get('document')).and_return(document)

      # TODO make sure objects are loaded too
      expect(repo).to receive(:write).once.ordered.with("testdata", :commit).and_return("top-commit")
      expect(repo).to receive(:write).once.ordered.with("testdata", :tree).and_return("top-tree")
      expect(repo).to receive(:write).once.ordered.with("testdata", :blob).and_return("top-content")
      expect(repo).to receive(:write).once.ordered.with("testdata", :commit).and_return("root-commit")
      expect(repo).to receive(:write).once.ordered.with("testdata", :tree).and_return("root-tree")
      expect(repo).to receive(:write).once.ordered.with("testdata", :blob).and_return("root-content")

      expect(refs).to receive(:create).once.ordered.with("refs/heads/master", "top-commit")
      expect(refs).to receive(:create).once.ordered.with("refs/tags/root", "root-commit")

      expect(document).to receive(:index).and_return(index)

      stream = StringIO.new
      stream.write(dump)
      stream.rewind

      documents = nil
      Serializer.load(stream) do |doc|
        document = doc
      end
      expect(document).to eq(document)
    end
  end
end
