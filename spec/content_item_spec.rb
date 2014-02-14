require 'spec_helper'

describe ContentItem do
  describe "creating" do
    it "should create item with content from hash" do
      c = ContentItem.new(foo: 'foo', bar: 'bar')

      expect(c.foo).to eq('foo')
      expect(c.bar).to eq('bar')
    end

    it "should create item with content from array" do
      c = ContentItem.new(['foo', 'bar'])

      expect(c[0]).to eq('foo')
      expect(c[1]).to eq('bar')
    end

    it "should get a document and surface the name as id" do
      c = ContentItem.new(foo: 'foo', bar: 'bar')

      expect(c.document).to be_a(Document)
      expect(c.id).to eq(c.document.name)
    end

    it "should take a document in opts hash and deserialize it's content" do
      doc = Document.new(nil, content: '{"foo": "bar", "a": ["a", 1]}')
      con = ContentItem.new(nil, document: doc)

      expect(con.foo).to eq('bar')
      expect(con.a[0]).to eq('a')
      expect(con.a[1]).to eq(1)
    end
  end

  describe "updating" do
    it "should allow mass updating content" do
      con = ContentItem.new(foo: 'foo', bar: 'bar', baz: 'baz')

      con.update(bar: 'xxx')

      expect(con.foo).to eq('foo')
      expect(con.bar).to eq('xxx')
      expect(con.baz).to eq('baz')
    end

    it "should forward delete_field to content" do
      con = ContentItem.new(foo: 'foo', bar: 'bar', baz: 'baz')

      con.delete_field(:foo)

      expect(con.foo).to be_nil
      expect(con.bar).to eq('bar')
      expect(con.baz).to eq('baz')
    end
  end

  describe "persisting" do
    let :time do
      Time.now
    end

    let :document do
      Struct.new(:name, :content).new('axbcd', '{"foo":"bar"}')
    end

    it "should serialize and save content" do
      con = ContentItem.new(key: 'value', another: ['array'])

      con.document.should_receive(:content=).with('{"key":"value","another":["array"]}')
      con.document.should_receive(:save!).with(time).and_return('abcdef')

      expect(con.save!(time)).to eq('abcdef')
    end

    it "should load and deserialize content" do
      con = ContentItem.new(nil)

      con.document.should_receive(:load!).with('abc').and_return('abc')
      con.document.should_receive(:content).and_return('{"key":"value","another":["array"]}')

      expect(con.load!('abc')).to eq('abc')
      expect(con.key).to eq('value')
      expect(con.another[0]).to eq('array')
    end

    it "should open a content item by id" do
      Document.should_receive(:open).and_return(document)

      con = ContentItem.open('axbcd')

      expect(con.foo).to eq('bar')
    end
  end

  describe "document API" do
    it "should delegate revision" do
      con = ContentItem.new(nil)
      con.document.should_receive(:revision).and_return('xyz')

      expect(con.revision).to eq('xyz')
    end

    it "should delegate history" do
      con = ContentItem.new(nil)
      con.document.should_receive(:history).with('x').and_return('foo')

      expect(con.history('x')).to eq('foo')
    end

    it "should delegate promote!" do
      con = ContentItem.new(nil)
      con.document.should_receive(:promote!).with('x', 'y', 'z', 't').and_return('foo')

      expect(con.promote!('x', 'y', 'z', 't')).to eq('foo')
    end

    it "should delegate has_been_promoted?" do
      con = ContentItem.new(nil)
      con.document.should_receive(:has_been_promoted?).with('x', 'y').and_return('foo')

      expect(con.has_been_promoted?('x', 'y')).to eq('foo')
    end

    it "should delegate rollback!" do
      con = ContentItem.new(nil)
      con.document.should_receive(:rollback!).with('x').and_return('foo')

      expect(con.rollback!('x')).to eq('foo')
    end
  end
end
