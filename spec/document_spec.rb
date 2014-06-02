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
      expect(Document.new('test-type')).to be_a Document
    end

    it "should have a random name" do
      document = Document.new('test-type')
      expect(document.name).to match /^[0-9a-f]{32}$/
    end

    it "should have a name if specified" do
      document = Document.new('test-type', 'test')
      expect(document.name).to eq 'test'
    end

    it "should have a content if specified" do
      document = Document.new('test-type', 'test', content: 'my test content')
      expect(document.content).to eq 'my test content'
    end
  end

  describe "git storage" do
    it "should create a repository with the document's name when asked for repo" do
      expect(Rugged::Repository).to receive(:init_at).with('storage/test', :bare)

      Document.new('test-type', 'test').repository
    end
  end

  describe "alternative storage" do
    let :doc do
      Object.new
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
      expect(Rugged::Repository).to receive(:init_at).with('storage/test', :bare, backend: :foo)

      Document.new('test-type', 'test').repository
    end

    it "should open with a given backend" do
      allow(Document).to receive(:new).and_return(doc)
      allow(doc).to receive(:load!)
      allow(Document).to receive(:index).and_return(index)

      expect(Rugged::Repository).to receive(:bare).with("storage/test", backend: :foo)

      Document.open("test")
    end
  end

  describe "saving to storage" do
    let(:root_oid) { 'rootid12' }

    let(:references) do
      double(:references).tap do |references|
        allow(references).to receive(:[]).with('refs/heads/master').and_return(head)
      end
    end

    let :repo do
      double(:repo).tap do |repo|
        allow(repo).to receive(:references).and_return(references)
      end
    end

    let :index do
      Object.new
    end

    let :head do
      Struct.new(:target_id).new(root_oid)
    end

    let :document do
      Document.new 'test-type', "test", content: "some content"
    end

    let :time do
      Time.now
    end

    let :mock_index do
      index = Object.new
      allow(index).to receive(:register).with(document.name, document.type).and_return(true)

      index
    end

    before do
      allow(document).to receive(:repository).and_return(repo)
      allow(document).to receive(:index).and_return(mock_index)
    end

    it "should create a commit on first save without a commit message" do
      expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

      expect(Rugged::Index).to receive(:new).and_return index
      expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      expect(index).to receive(:write_tree).with(repo).and_return 'foo'

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: {email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: '',
        parents: [root_oid],
        update_ref: 'refs/heads/master'
      }

      expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

      expect(document).to receive(:init_repository).with(repo, time)

      expect(document.save!({ name: 'The Colonel', email: 'colonel@example.com' }, '', time)).to eq 'foo'
      expect(document.revision).to eq 'foo'
    end

    it "should create a commit on first save with a commit message" do
      expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

      expect(Rugged::Index).to receive(:new).and_return index
      expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      expect(index).to receive(:write_tree).with(repo).and_return 'foo'

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: 'save from the colonel',
        parents: [root_oid],
        update_ref: 'refs/heads/master'
      }

      expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

      expect(document).to receive(:init_repository).with(repo, time)

      expect(document.save!({ email: 'colonel@example.com', name: 'The Colonel' }, 'save from the colonel', time)).to eq 'foo'
      expect(document.revision).to eq 'foo'
    end

    it 'should create a tagged root commit' do
      allow(repo).to receive(:empty?).and_return(true)

      the_colonel = { name: 'The Colonel', email: 'colonel@example.com' }

      expect(document).to receive(:commit!).with('', [], 'refs/heads/master', the_colonel, 'First Commit', time).ordered.and_return(root_oid)
      expect(document).to receive(:commit!).with('some content', [root_oid], 'refs/heads/master', the_colonel, 'Second Commit', time).ordered.once

      expect(repo.references).to receive(:create).with('refs/tags/root', root_oid)

      document.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'Second Commit', time)
    end

    it "should add a commit on subsequent saves" do
      expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

      expect(Rugged::Index).to receive(:new).and_return index
      expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      expect(index).to receive(:write_tree).with(repo).and_return 'foo'
      expect(repo).to receive(:references).and_return(references)

      expect(document).to receive(:init_repository).with(repo, time)

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: 'save from the colonel',
        parents: [root_oid],
        update_ref: 'refs/heads/master'
      }

      expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

      expect(document.save!({ email: 'colonel@example.com', name: 'The Colonel' },'save from the colonel', time)).to eq 'foo'
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
      Document.new 'test-type', "test", content: "some content"
    end

    let :time do
      Time.now
    end

    let :mock_index do
      index = Object.new
      allow(index).to receive(:register).with(document.name, document.type).and_return(true)
    end

    before do
      allow(document).to receive(:repository).and_return(repo)
    end

    it "shoud have a document index" do
      expect(document.index).to be_a(DocumentIndex)
      expect(document.index.storage_path).to eq(Colonel.config.storage_path)
    end

    it "should register with document index when saving" do
      expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

      expect(Rugged::Index).to receive(:new).and_return index
      expect(index).to receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      expect(index).to receive(:write_tree).with(repo).and_return 'foo'

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: 'save from the colonel',
        parents: ["head"],
        update_ref: 'refs/heads/master'
      }

      expect(Rugged::Commit).to receive(:create).with(repo, options).and_return 'foo'

      expect(document.index).to receive(:register).with(document.name, document.type).and_return(true)

      allow(document).to receive(:init_repository).and_return(true)

      expect(document.save!({ email: 'colonel@example.com', name: 'The Colonel' }, 'save from the colonel', time)).to eq 'foo'
      expect(document.revision).to eq 'foo'
    end
  end

  describe "loading from storage" do
    let :repo do
      Struct.new(:references).new(Object.new)
    end

    let :commit do
      Object.new
    end

    let :tree do
      Object.new
    end

    let :file do
      Object.new
    end

    let :robj do
      Object.new
    end

    let :index do
      double(:index).tap do |index|
        allow(index).to receive(:lookup).with("test").and_return({type: "test-type", name: "test"})
      end
    end

    let :document do
      Document.new('test-type', 'test', repo: repo)
    end

    it "should open the repository and get HEAD" do
      expect(Rugged::Repository).to receive(:bare).with("storage/test").and_return(repo)
      expect(repo).to receive(:head).and_return Struct.new(:target_id).new('abcdef')
      expect(repo).to receive(:lookup).with('abcdef').and_return(commit)
      expect(commit).to receive(:tree).and_return(tree)
      expect(tree).to receive(:first).and_return({oid: '12345', name: 'content'})
      expect(repo).to receive(:lookup).with('12345').and_return(file)
      expect(file).to receive(:read_raw).and_return(robj)
      expect(robj).to receive(:data).and_return('foo')

      allow(Document).to receive(:index).and_return(index)

      doc = Document.open("test")
      expect(doc).to be_a(Document)
      expect(doc.repository).to eq(repo)
      expect(doc.revision).to eq('abcdef')
      expect(doc.content).to eq('foo')
    end

    it "should load a given revision from sha" do
      expect(repo).to receive(:lookup).with('abcde').and_return(commit)
      expect(commit).to receive(:tree).and_return(tree)
      expect(tree).to receive(:first).and_return({oid: 'foo', name: 'content'})

      expect(repo).to receive(:lookup).with('foo').and_return(file)
      expect(file).to receive(:read_raw).and_return(robj)
      expect(robj).to receive(:data).and_return('data')

      expect(document.load!('abcde')).to eq('abcde')
      expect(document.revision).to eq('abcde')
      expect(document.content).to eq('data')
    end

    it "should load a given revision from state" do
      expect(repo.references).to receive(:[]).with('refs/heads/preview').and_return(Struct.new(:target_id).new('abcde'))

      expect(repo).to receive(:lookup).with('preview').and_raise(Rugged::InvalidError)

      expect(repo).to receive(:lookup).with('abcde').and_return(commit)
      expect(commit).to receive(:tree).and_return(tree)
      expect(tree).to receive(:first).and_return({oid: 'foo', name: 'content'})

      expect(repo).to receive(:lookup).with('foo').and_return(file)
      expect(file).to receive(:read_raw).and_return(robj)
      expect(robj).to receive(:data).and_return('data')

      expect(document.load!('preview')).to eq('abcde')
      expect(document.revision).to eq('abcde')
      expect(document.content).to eq('data')
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
      doc = Document.new('test-type', 'test', revision: 'abcdefg', repo: repo)

      allow(repo.references).to receive(:[])

      expect(repo.references).to receive(:[]).once.with(Document::ROOT_REF).and_return(root_ref)
      expect(repo.references).to receive(:[]).once.with('refs/heads/preview').and_return(ref)
      expect(repo).to receive(:lookup).with('xyz').and_return(commit)

      history = []
      doc.history('preview') { |cmt| history << cmt}

      expect(history).to eq([
        {rev: 'p3', message: 'meow', author: 'aliens', time: time, type: :save},
        {rev: 'p2', message: 'hey', author: 'me', time: time, type: :promotion},
        {rev: 'p1', message: 'bye', author: 'you', time: time, type: :promotion}
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
      Document.new 'test-type', "test", content: "some content", repo: repo
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
        expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

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
        expect(repo).to receive(:write).with("some content", :blob).and_return('abcdef')

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
        doc = Document.new('test-type', 'test', revision: 'abcdefg', repo: repo)

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
        doc = Document.new('test-type', 'test', revision: 'abcdefg', repo: repo)

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
