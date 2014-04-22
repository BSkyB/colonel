require 'spec_helper'

describe Document do
  describe "creation" do
    before do
      Rugged::Repository.stub(:new).and_return nil
    end

    it "should create a document" do
      expect(Document.new).to be_a Document
    end

    it "should have a random name" do
      document = Document.new
      expect(document.name).to match /^[0-9a-f]{32}$/
    end

    it "should have a name if specified" do
      document = Document.new 'test'
      expect(document.name).to eq 'test'
    end

    it "should have a content if specified" do
      document = Document.new('test', content: 'my test content')
      expect(document.content).to eq 'my test content'
    end
  end

  describe "git storage" do
    it "should create a repository with the document's name when asked for repo" do
      Rugged::Repository.should_receive(:init_at).with('storage/test', :bare)

      Document.new('test').repository
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

    it "should init with a given backend" do
      Rugged::Repository.should_receive(:init_at).with('storage/test', :bare, backend: :foo)

      Document.new('test').repository
    end

    it "should open with a given backend" do
      Document.stub(:new).and_return(doc)
      doc.stub(:load!)

      Rugged::Repository.should_receive(:bare).with("storage/test", backend: :foo)

      Document.open("test")
    end
  end

  describe "saving to storage" do
    let :repo do
      Object.new
    end

    let :index do
      Object.new
    end

    let :head do
      Struct.new(:target).new('head')
    end

    let :document do
      Document.new "test", content: "some content"
    end

    let :time do
      Time.now
    end

    before do
      document.stub(:repository).and_return(repo)
    end

    it "should create a commit on first save without a commit message" do
      repo.should_receive(:write).with("some content", :blob).and_return('abcdef')

      Rugged::Index.should_receive(:new).and_return index
      index.should_receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      index.should_receive(:write_tree).with(repo).and_return 'foo'
      repo.should_receive(:empty?).and_return(true)

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: {email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: '',
        parents: [],
        update_ref: 'refs/heads/master'
      }

      Rugged::Commit.should_receive(:create).with(repo, options).and_return 'foo'

      expect(document.save!({ name: 'The Colonel', email: 'colonel@example.com' }, '', time)).to eq 'foo'
      expect(document.revision).to eq 'foo'
    end

    it "should create a commit on first save with a commit message" do
      repo.should_receive(:write).with("some content", :blob).and_return('abcdef')

      Rugged::Index.should_receive(:new).and_return index
      index.should_receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      index.should_receive(:write_tree).with(repo).and_return 'foo'
      repo.should_receive(:empty?).and_return(true)

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: 'save from the colonel',
        parents: [],
        update_ref: 'refs/heads/master'
      }

      Rugged::Commit.should_receive(:create).with(repo, options).and_return 'foo'

      expect(document.save!({ email: 'colonel@example.com', name: 'The Colonel' }, 'save from the colonel', time)).to eq 'foo'
      expect(document.revision).to eq 'foo'
    end

    it "should add a commit on subsequent saves" do
      repo.should_receive(:write).with("some content", :blob).and_return('abcdef')

      Rugged::Index.should_receive(:new).and_return index
      index.should_receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
      index.should_receive(:write_tree).with(repo).and_return 'foo'
      repo.should_receive(:empty?).and_return(false)
      repo.should_receive(:head).and_return(head)

      options = {
        tree: 'foo',
        author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
        message: 'save from the colonel',
        parents: ['head'],
        update_ref: 'refs/heads/master'
      }

      Rugged::Commit.should_receive(:create).with(repo, options).and_return 'foo'

      expect(document.save!({ email: 'colonel@example.com', name: 'The Colonel' },'save from the colonel', time)).to eq 'foo'
    end
  end

  describe "loading from storage" do
    let :repo do
      Object.new
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

    let :document do
      Document.new('test', repo: repo)
    end

    it "should open the repository and get HEAD" do
      Rugged::Repository.should_receive(:bare).with("storage/test").and_return(repo)
      repo.should_receive(:head).and_return Struct.new(:target).new('abcdef')
      repo.should_receive(:lookup).with('abcdef').and_return(commit)
      commit.should_receive(:tree).and_return(tree)
      tree.should_receive(:first).and_return({oid: '12345', name: 'content'})
      repo.should_receive(:lookup).with('12345').and_return(file)
      file.should_receive(:read_raw).and_return(robj)
      robj.should_receive(:data).and_return('foo')

      doc = Document.open("test")
      expect(doc).to be_a(Document)
      expect(doc.repository).to eq(repo)
      expect(doc.revision).to eq('abcdef')
      expect(doc.content).to eq('foo')
    end

    it "should load a given revision from sha" do
      repo.should_receive(:lookup).with('abcde').and_return(commit)
      commit.should_receive(:tree).and_return(tree)
      tree.should_receive(:first).and_return({oid: 'foo', name: 'content'})

      repo.should_receive(:lookup).with('foo').and_return(file)
      file.should_receive(:read_raw).and_return(robj)
      robj.should_receive(:data).and_return('data')

      expect(document.load!('abcde')).to eq('abcde')
      expect(document.revision).to eq('abcde')
      expect(document.content).to eq('data')
    end

    it "should load a given revision from state" do
      Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/preview').and_return(Struct.new(:target).new('abcde'))

      repo.should_receive(:lookup).with('preview').and_raise(Rugged::InvalidError)

      repo.should_receive(:lookup).with('abcde').and_return(commit)
      commit.should_receive(:tree).and_return(tree)
      tree.should_receive(:first).and_return({oid: 'foo', name: 'content'})

      repo.should_receive(:lookup).with('foo').and_return(file)
      file.should_receive(:read_raw).and_return(robj)
      robj.should_receive(:data).and_return('data')

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
      Struct.new(:target).new('xyz')
    end

    let :repo do
      Object.new
    end

    let :commit do
      commit = Struct.new(:oid, :message, :author, :time, :parents)

      commit.new('foo', 'hey', 'me', time, [
        commit.new('bar', 'bye', 'you', time, [
          commit.new('baz', 'wee', 'him', time, [])
        ]),
        commit.new('baz', 'bye', 'you', time, []),
      ])
    end

    it "should list past revisions" do
      doc = Document.new('test', revision: 'abcdefg', repo: repo)

      Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/preview').and_return(ref)
      repo.should_receive(:lookup).with('xyz').and_return(commit)

      history = []
      doc.history('preview') { |cmt| history << cmt}

      expect(history).to eq([
        {rev: 'foo', message: 'hey', author: 'me', time: time},
        {rev: 'bar', message: 'bye', author: 'you', time: time}
      ])
    end
  end


  describe "states" do
    let :repo do
      Object.new
    end

    let :index do
      Object.new
    end

    let :document do
      Document.new "test", content: "some content", repo: repo
    end

    let :ref1 do
      Struct.new(:target).new('xyz1')
    end

    let :ref2 do
      Struct.new(:target).new('xyz2')
    end

    let :time do
      Time.now
    end

    describe "promoting" do
      it "should commit with parents from master and preview and update preview" do
        repo.should_receive(:write).with("some content", :blob).and_return('abcdef')

        Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/master').and_return(ref1)
        Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/preview').and_return(ref2)

        Rugged::Index.should_receive(:new).and_return index

        index.should_receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
        index.should_receive(:write_tree).with(repo).and_return 'foo'

        options = {
          tree: 'foo',
          author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          message: 'preview from the colonel',
          parents: ['xyz2', 'xyz1'],
          update_ref: 'refs/heads/preview'
        }

        Rugged::Commit.should_receive(:create).with(repo, options).and_return 'foo'

        expect(document.promote!('master', 'preview', { name: 'The Colonel', email: 'colonel@example.com' }, 'preview from the colonel', time)).to eq 'foo'
      end

      it "should commit with parents from master and preview and create preview if it doesn't exist" do
        repo.should_receive(:write).with("some content", :blob).and_return('abcdef')

        Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/master').and_return(ref1)
        Rugged::Reference.should_receive(:lookup).with(repo, 'refs/heads/preview').and_return(nil)

        Rugged::Index.should_receive(:new).and_return index

        index.should_receive(:add).with(path: "content", oid: 'abcdef', mode: 0100644)
        index.should_receive(:write_tree).with(repo).and_return 'foo'

        options = {
          tree: 'foo',
          author: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          committer: { email: 'colonel@example.com', name: 'The Colonel', time: time },
          message: 'preview from the colonel',
          parents: ['xyz1'],
          update_ref: 'refs/heads/preview'
        }

        Rugged::Commit.should_receive(:create).with(repo, options).and_return 'foo'

        expect(document.promote!('master', 'preview', { name: 'The Colonel', email: 'colonel@example.com' }, 'preview from the colonel', time)).to eq 'foo'
      end
    end

    describe "checking future states" do
      let :time do
        Time.now
      end

      let :ref do
        Struct.new(:target).new('xyz')
      end

      let :repo do
        Object.new
      end

      let :preview_commit do
        commit = Struct.new(:oid, :message, :author, :time, :parents)

        d2 = commit.new('d2', 'x', 'x', time, [
          commit.new('d1', 'x', 'x', time, [])
        ])

          commit.new('p2', 'x', 'x', time, [
            commit.new('p1', 'x', 'x', time, [d2]),
            commit.new('d4', 'x', 'x', time, [
              commit.new('d3', 'x', 'x', time, [d2])
            ])
          ])
      end

      let :publish_commit do
        commit = Struct.new(:oid, :message, :author, :time, :parents)
        commit.new('pp1', 'x', 'x', time, [preview_commit])
      end

      it "should check whether a draft was promoted to preview" do
        doc = Document.new('test', revision: 'abcdefg', repo: repo)

        Rugged::Reference.stub(:lookup).with(repo, 'refs/heads/preview').and_return(ref)
        repo.stub(:lookup).with('xyz').and_return(preview_commit)

        expect(doc.has_been_promoted?('preview', 'd1')).to be_false
        expect(doc.has_been_promoted?('preview', 'd2')).to be_true
        expect(doc.has_been_promoted?('preview', 'd3')).to be_false
        expect(doc.has_been_promoted?('preview', 'd4')).to be_true
        expect(doc.has_been_promoted?('preview', 'd5')).to be_false
      end

      it "should check whether a draft was promoted to published" do
        doc = Document.new('test', revision: 'abcdefg', repo: repo)

        Rugged::Reference.stub(:lookup).with(repo, 'refs/heads/published').and_return(ref)
        repo.stub(:lookup).with('xyz').and_return(publish_commit)

        expect(doc.has_been_promoted?('published', 'd1')).to be_false
        expect(doc.has_been_promoted?('published', 'd2')).to be_false
        expect(doc.has_been_promoted?('published', 'd3')).to be_false
        expect(doc.has_been_promoted?('published', 'd4')).to be_true
        expect(doc.has_been_promoted?('published', 'd5')).to be_false

        expect(doc.has_been_promoted?('published', 'p1')).to be_false
        expect(doc.has_been_promoted?('published', 'p2')).to be_true
      end
    end

    describe "rolling back" do
      let :time do
        Time.now
      end

      let :ref do
        Struct.new(:target).new('xyz')
      end

      let :repo do
        Object.new
      end

      let :preview_commit do
        commit = Struct.new(:oid, :message, :author, :time, :parents)

        d2 = commit.new('d2', 'x', 'x', time, [
          commit.new('d1', 'x', 'x', time, [])
        ])

        commit.new('p2', 'x', 'x', time, [
          commit.new('p1', 'x', 'x', time, [d2]),
          commit.new('d4', 'x', 'x', time, [
            commit.new('d3', 'x', 'x', time, [d2])
          ])
        ])
      end

      it "should find given branch head's left parent and update the ref to it" do
        doc = Document.new('test', revision: 'foo', repo: repo)

        Rugged::Reference.stub(:lookup).with(repo, 'refs/heads/preview').and_return(ref)
        repo.stub(:lookup).with('xyz').and_return(preview_commit)
        ref.should_receive(:set_target).with('p1')

        expect(doc.rollback!('preview')).to eq('p1')
      end

      it "should find given branch head's and remove it if it doesn't have a parent" do
        doc = Document.new('test', revision: 'foo', repo: repo)

        Rugged::Reference.stub(:lookup).with(repo, 'refs/heads/preview').and_return(ref)
        repo.stub(:lookup).with('xyz').and_return(preview_commit.parents[0])

        ref.should_receive(:delete!)

        expect(doc.rollback!('preview')).to be_nil
      end
    end
  end
end
