require 'spec_helper'

describe Document do
  let(:root_oid) { 'root-oid' }

  let(:root_ref) do
    double(:root_ref).tap do |root_ref|
      allow(root_ref).to receive(:target_id).and_return(root_oid)
    end
  end

  let(:root_commit) do
    double(:root_commit,
      oid: root_oid,
      message: 'First Commit',
      author: {},
      time: time,
      parents: [])
  end

  describe "creation" do
    before do
      allow(Rugged::Repository).to receive(:new).and_return nil
    end

    it "should create a document" do
      expect(Document.new(nil)).to be_a Document
    end

    it "should have a random name" do
      document = Document.new(nil)
      expect(document.id).to match /^[0-9a-f]{32}$/
    end

    it "should have a content if specified" do
      document = Document.new({content: 'my test content'})
      expect(document.content.content).to eq 'my test content'
    end
  end

  describe "git storage" do
    it "should create a repository with the document's name when asked for repo" do
      doc = Document.new(nil)
      expect(Rugged::Repository).to receive(:init_at).with("storage/#{doc.id}", :bare)

      doc.repository
    end
  end

  describe "alternative storage" do
    let :doc do
      double(:document).tap do |it|
        allow(it).to receive(:id).and_return("foo")
      end
    end

    before :each do
      Colonel.config.rugged_backend = :foo
    end

    after :each do
      Colonel.config.rugged_backend = nil
    end

    let :index do
      double(:index).tap do |index|
        allow(index).to receive(:lookup).with("test").and_return({name: "test", type: "test-type"})
      end
    end

    it "should init with a given backend" do
      doc = Document.new(nil)
      expect(Rugged::Repository).to receive(:init_at).with("storage/#{doc.id}", :bare, backend: :foo)

      doc.repository
    end

    it "should open with a given backend" do
      allow(Document).to receive(:new).and_return(doc)
      allow(doc).to receive(:load!)
      allow(Document).to receive(:index).and_return(index)

      expect(Rugged::Repository).to receive(:bare).with("storage/test-id", backend: :foo)

      Document.open("test-id")
    end
  end

  describe "saving to storage" do
    let :document do
      Document.new(nil).tap do |it|
        allow(it).to receive(:repository).and_return(repository)
        allow(it).to receive(:revisions).and_return(double(:revisions))
      end
    end

    let :repository do
      double(:repository).tap do |it|
        allow(it).to receive(:references).and_return(double(:references))
      end
    end

    let :time do
      Time.now
    end

    let :revision do
      double(:revision).tap do |it|
        allow(it).to receive(:write!)
      end
    end

    let :previous_revision do
      double(:previous_revision)
    end

    let :head_ref do
      double(:head_ref)
    end

    let :root_ref do
      double(:root_ref).tap do |it|
        allow(it).to receive(:target_id).and_return("root_id")
      end
    end

    let :root_revision do
      double(:root_revision).tap do |it|
        allow(it).to receive(:id).and_return("root_id")
        allow(it).to receive(:write!)
      end
    end

    it 'should create a tagged root revision' do
      allow(document.revisions).to receive(:root_revision).and_return(nil)
      allow(document.revisions).to receive(:[]).with('master').and_return(nil)

      allow(Revision).to receive(:new).and_return(revision)

      the_colonel = { name: 'The Colonel', email: 'colonel@example.com' }

      expect(Revision).to receive(:new).with(document, "", the_colonel, "First Commit", time, nil).and_return(root_revision)
      expect(root_revision).to receive(:write!).and_return("foo")
      expect(repository.references).to receive(:create).with('refs/tags/root', "foo")

      document.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'Second Commit', time)
    end

    it "should create a commit on first save" do
      allow(document.revisions).to receive(:root_revision).and_return(root_revision)
      allow(document.revisions).to receive(:[]).with('master').and_return(nil)

      allow(revision).to receive(:write!)

      expect(Revision).to receive(:new).with(document, document.content, :author, "", time, root_revision).and_return(revision)

      rev = document.save!(:author, "", time)

      expect(rev).to eq(revision)
    end

    it "should add a commit on subsequent saves" do
      allow(document.revisions).to receive(:root_revision).and_return(root_revision)
      allow(document.revisions).to receive(:[]).with('master').and_return(previous_revision)
      allow(document).to receive(:init_repository).with(repository, time)

      allow(revision).to receive(:write!)

      expect(Revision).to receive(:new).with(document, document.content, :author, "", time, previous_revision).and_return(revision)

      rev = document.save!(:author, "", time)

      expect(rev).to eq(revision)
    end
  end

  describe "registering with index" do
    let :repo do
      Struct.new(:references).new(
        double(:references).tap do |refs|
          allow(refs).to receive(:[]).with("refs/heads/master").and_return(head)
        end
      )
    end

    let :index do
      double(:index)
    end

    let :head do
      Struct.new(:target_id).new('head')
    end

    let :document do
      Document.new(content: "some content")
    end

    let :time do
      Time.now
    end

    let :mock_index do
      index = Object.new
      allow(index).to receive(:register).with(document.id, document.type).and_return(true)
    end

    let :revisions do
      double(:revisions)
    end

    before do
      allow(document).to receive(:repository).and_return(repo)
      allow(document).to receive(:revisions).and_return(revisions)
    end

    it "shoud have a document index" do
      expect(document.index).to be_a(DocumentIndex)
      expect(document.index.storage_path).to eq(Colonel.config.storage_path)
    end

    it "should register with document index when saving" do
      revision = double(:revision)

      allow(document).to receive(:init_repository).and_return(true)
      allow(revisions).to receive(:[]).with('master').and_return(true)
      allow(Revision).to receive(:new).and_return(revision)
      allow(revision).to receive(:write!)

      expect(document.index).to receive(:register).with(document.id, document.type).and_return(true)

      rev = document.save!({ email: 'colonel@example.com', name: 'The Colonel' }, 'save from the colonel', time)
      expect(rev).to eq(revision)
    end
  end

  describe "loading from storage" do
    let :repo do
      double(:repo).tap do |it|
        allow(it).to receive(:references).and_return(double(:references))
      end
    end

    let :index do
      double(:index).tap do |index|
        allow(index).to receive(:lookup).with("test").and_return({type: "test-type", name: "test"})
      end
    end

    let :revision do
      double(:revision)
    end

    let :document do
      Document.new(nil, repo: repo).tap do |it|
        allow(it).to receive(:revisions).and_return(double(:revisions))
      end
    end

    it "should open the repository and get content for master" do
      expect(Rugged::Repository).to receive(:bare).with("storage/test").and_return(repo)
      expect(Document).to receive(:new).with(nil, {id: 'test', repo: repo}).and_return(document)
      expect(document.revisions).to receive(:[]).with('master').and_return(revision)
      expect(revision).to receive(:content).and_return(Content.new({content: 'foo'}))

      doc = Document.open("test")

      expect(doc).to be_a(Document)
      expect(doc.content.content).to eq('foo')
    end
  end

  describe "listing revisions" do

    let :time do
      Time.now
    end

    let :ref do
      Struct.new(:target_id).new('xyz')
    end

    let :references do
      double(:references)
    end

    let :repo do
      double(:repo).tap do |repo|
        allow(repo).to receive(:references).and_return(references)
      end
    end

    let :commit do
      commit = Struct.new(:oid, :message, :author, :time, :parents)

      # This is the structure here
      #
      #       o p3
      #       |
      #    p2 o
      #     / |
      # m2 o  o p1
      #    |/ |
      # m1 o  |
      #    | /
      #    0
      #

      m1 = commit.new('m1', 'wee', 'him', time, [root_commit])

      commit.new('p3', 'meow', 'aliens', time, [
        commit.new('p2', 'hey', 'me', time, [
          commit.new('p1', 'bye', 'you', time, [root_commit, m1]),
          commit.new('m2', 'bye', 'you', time, [m1])
        ])
      ])
    end

    it "should list past revisions" do
      pending

      doc = Document.new(nil, revision: 'abcdefg', repo: repo)

      allow(repo.references).to receive(:[])

      expect(repo.references).to receive(:[]).once.with(Document::ROOT_REF).and_return(root_ref)
      expect(repo.references).to receive(:[]).once.with('refs/heads/preview').and_return(ref)
      expect(repo).to receive(:lookup).with('xyz').and_return(commit)

      history = []
      doc.history('preview') { |cmt| history << cmt}

      expect(history).to eq([
        {rev: 'p3', message: 'meow', author: 'aliens', time: time, type: :save, parents: {previous: 'p2'}},
        {rev: 'p2', message: 'hey', author: 'me', time: time, type: :promotion, parents: {previous: 'p1', source: 'm2'}},
        {rev: 'p1', message: 'bye', author: 'you', time: time, type: :promotion, parents: {source: 'm1'}}
      ])
    end
  end

  describe "states" do
    let :repo do
      Struct.new(:references).new(Object.new)
    end

    let :index do
      Object.new
    end

    let :document do
      Document.new({content: "some content"}, repo: repo)
    end

    let :ref1 do
      Struct.new(:target_id).new('xyz1')
    end

    let :ref2 do
      Struct.new(:target_id).new('xyz2')
    end

    let :time do
      Time.now
    end

    describe "promoting" do
      it "should commit with parents from master and preview and update preview" do
        pending

        expect(repo).to receive(:write).with('{"content":"some content"}', :blob).and_return('abcdef')

        expect(repo.references).to receive(:[]).with('refs/heads/master').and_return(ref1)
        expect(repo.references).to receive(:[]).with('refs/heads/preview').and_return(ref2)

        expect(Rugged::Index).to receive(:new).and_return index

        expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
        expect(index).to receive(:write_tree).with(repo).and_return 'foo'

        options = {
          tree: 'foo',
          author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          message: 'preview from the colonel',
          parents: ['xyz2', 'xyz1'],
          update_ref: 'refs/heads/preview'
        }

        expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

        expect(document.promote!('master', 'preview', { name: 'The Colonel', email: 'colonel@example.com' }, 'preview from the colonel', time)).to eq 'foo'
      end

      it "should commit with parents from master and preview and create preview if it doesn't exist" do
        pending

        expect(repo).to receive(:write).with('{"content":"some content"}', :blob).and_return('abcdef')

        expect(repo.references).to receive(:[]).with('refs/heads/master').and_return(ref1)
        expect(repo.references).to receive(:[]).with('refs/heads/preview').and_return(nil)
        expect(repo.references).to receive(:[]).with('refs/tags/root').and_return(root_ref)

        expect(Rugged::Index).to receive(:new).and_return index

        expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
        expect(index).to receive(:write_tree).with(repo).and_return 'foo'

        options = {
          tree: 'foo',
          author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          message: 'preview from the colonel',
          parents: [root_oid, 'xyz1'],
          update_ref: 'refs/heads/preview'
        }

        expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

        expect(document.promote!('master', 'preview', { name: 'The Colonel', email: 'colonel@example.com' }, 'preview from the colonel', time)).to eq 'foo'
      end
    end

    describe "checking future states" do
      let :time do
        Time.now
      end

      let :ref do
        Struct.new(:target_id).new('xyz')
      end

      let :repo do
        Struct.new(:references).new(Object.new)
      end

      let :preview_commit do
        commit = Struct.new(:oid, :message, :author, :time, :parents)

        #              o pp1
        #     p3 o   / |
        #        | /   |
        #     p2 o     |
        #      / |     |
        # d4 o   |     |
        #    |   |     |
        # d3 o   o p1  |
        #    | / |     |
        # d2 o   |   /
        #    |   | /
        # d1 o   |
        #    | /
        #    0

        d2 = commit.new('d2', 'x', 'x', time, [
          commit.new('d1', 'x', 'x', time, [root_commit])
        ])

        commit.new('p3', 'x', 'x', time, [
          commit.new('p2', 'x', 'x', time, [
            commit.new('p1', 'x', 'x', time, [root_commit, d2]),
            commit.new('d4', 'x', 'x', time, [
              commit.new('d3', 'x', 'x', time, [d2])
            ])
          ])
        ])
      end

      let :publish_commit do
        commit = Struct.new(:oid, :message, :author, :time, :parents)
        commit.new('pp1', 'x', 'x', time, [root_commit, preview_commit.parents.first])
      end

      it "should check whether a draft was promoted to preview" do
        doc = Document.new(nil, revision: 'abcdefg', repo: repo)

        allow(repo.references).to receive(:[]).with('refs/tags/root').and_return(root_ref)
        allow(repo.references).to receive(:[]).with('refs/heads/preview').and_return(ref)
        allow(repo).to receive(:lookup).with('xyz').and_return(preview_commit)

        expect(doc.has_been_promoted?('preview', 'd1')).to be false
        expect(doc.has_been_promoted?('preview', 'd2')).to be true
        expect(doc.has_been_promoted?('preview', 'd3')).to be false
        expect(doc.has_been_promoted?('preview', 'd4')).to be true
        expect(doc.has_been_promoted?('preview', 'd5')).to be false
      end

      it "should check whether a draft was promoted to published" do
        doc = Document.new(nil, revision: 'abcdefg', repo: repo)

        allow(repo.references).to receive(:[]).with('refs/tags/root').and_return(root_ref)
        allow(repo.references).to receive(:[]).with('refs/heads/published').and_return(ref)
        allow(repo).to receive(:lookup).with('xyz').and_return(publish_commit)

        expect(doc.has_been_promoted?('published', 'd1')).to be false
        expect(doc.has_been_promoted?('published', 'd2')).to be false
        expect(doc.has_been_promoted?('published', 'd3')).to be false
        expect(doc.has_been_promoted?('published', 'd4')).to be true
        expect(doc.has_been_promoted?('published', 'd5')).to be false

        expect(doc.has_been_promoted?('published', 'p1')).to be false
        expect(doc.has_been_promoted?('published', 'p2')).to be true
      end
    end
  end
end
