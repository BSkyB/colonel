require 'spec_helper'

describe DocumentIndex do
  it "should have a name" do
    expect(DocumentIndex::INDEX_NAME).to eq('colonel/document-index')
  end

  it "should initialize with storage path" do
    expect { DocumentIndex.new('test-storage') }.not_to raise_error()
  end

  it "should have a repository" do
    index = DocumentIndex.new('test-storage')

    expect(index.repository).to be_a(Rugged::Repository)
  end

  describe "Indexing and retrieving" do
    let :repo do
      Struct.new(:references).new([])
    end

    let :head do
      Struct.new(:target_id).new("abcdef")
    end

    let :ref do
      Object.new
    end

    let :object do
      Object.new
    end

    let :raw do
      Object.new
    end

    let :index do
      index = DocumentIndex.new('test-storage')
      allow(index).to receive(:repository).and_return(repo)

      index
    end

    it "should load the documents list for empty repo" do
      expect(repo).to receive(:head).and_raise(Rugged::ReferenceError)

      expect(index.documents).to be_a(Array)
    end

    it "should load the documents list for non-empty repo" do
      expect(repo).to receive(:head).and_return(head)
      expect(repo).to receive(:lookup).with('abcdef').and_return(object)
      expect(object).to receive(:read_raw).and_return(raw)
      expect(raw).to receive(:data).and_return("one TestType\ntwo TestType\nthree TestType")

      expect(index.documents).to eq([{name: "one", type: "TestType"}, {name: "two", type: "TestType"}, {name: "three", type: "TestType"}])
    end

    it "should register a document in an empty repo" do
      allow(index).to receive(:documents).and_return([{name: "one", type: "TestType"}, {name: "two", type: "TestType"}, {name: "three", type: "TestType"}])
      expect(repo).to receive(:write).with("one TestType\ntwo TestType\nthree TestType\nfour TestType", :blob).and_return('aabbccdd')

      expect(repo.references).to receive(:[]).with('refs/heads/master').and_return(nil)
      expect(repo.references).to receive(:create).with('refs/heads/master', 'aabbccdd')

      expect(index.register("four", "TestType")).to eq(true)
    end

    it "should register a document in an non-empty repo" do
      allow(index).to receive(:documents).and_return([{name: "one", type: "TestType"}, {name: "two", type: "TestType"}, {name: "three", type: "TestType"}])
      expect(repo).to receive(:write).with("one TestType\ntwo TestType\nthree TestType\nfour TestType", :blob).and_return('aabbccdd')

      expect(repo.references).to receive(:[]).with('refs/heads/master').and_return(ref)
      expect(repo.references).to receive(:update).with(ref, 'aabbccdd')

      expect(index.register("four", "TestType")).to eq(true)
    end

    it "should lookup documents" do
      allow(index).to receive(:documents).and_return([{name: "one", type: "TestType"}, {name: "two", type: "TestType"}, {name: "three", type: "TestType"}, {name: "four", type: "TestType"}])

      expect(index.lookup("one")).to eq({name: "one", type: "TestType"})
    end

    it "should not modify a repo with document already listed" do
      allow(index).to receive(:documents).and_return([{name: "one", type: "TestType"}, {name: "two", type: "TestType"}, {name: "three", type: "TestType"}, {name: "four", type: "TestType"}])

      expect(repo).not_to receive(:write)
      expect(repo.references).not_to receive(:[])
      expect(repo.references).not_to receive(:update)

      expect(index.register("four", "TestType")).to eq(true)
    end
  end
end
