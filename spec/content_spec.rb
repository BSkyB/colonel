require 'spec_helper'

describe Content do

  describe "creation" do
    it "should initalize with a simple hash" do
      c = Content.new(first: 'foo', second: 'bar')

      expect(c.first).to eq('foo')
      expect(c.second).to eq('bar')
    end

    it "should initialize with an array" do
      c = Content.new(['a', 'b', 'c'])

      expect(c[0]).to eq('a')
      expect(c[1]).to eq('b')
      expect(c[2]).to eq('c')
    end

    it "should handle nested hashes" do
      c = Content.new(first: {a: 'a', b: 'b'}, second: 'bar')

      expect(c.first.a).to eq('a')
      expect(c.first.b).to eq('b')
      expect(c.second).to eq('bar')
    end

    it "should handle hashes nested in arrays" do
      c = Content.new(first: [{a: 'a', b: 'b'}, 'foo'], second: 'bar')

      expect(c.first[0].a).to eq('a')
      expect(c.first[0].b).to eq('b')
      expect(c.first[1]).to eq('foo')
      expect(c.second).to eq('bar')
    end

    it "should handle hashes in an array with nested arrays and aliens and shit" do
      c = Content.new([{a: 'a', b: ['stuff', {doge: 'wow'}]}, 'foo', {a: ['alien', 'shit']}])

      expect(c[0].a).to eq('a')
      expect(c[0].b[0]).to eq('stuff')
      expect(c[0].b[1].doge).to eq('wow')
      expect(c[1]).to eq('foo')
      expect(c[2].a[0]).to eq('alien')
      expect(c[2].a[1]).to eq('shit')
    end

    it "should not whine when a key doesn't exist" do
      c = Content.new([])

      expect(c.foobar).to be_nil
    end
  end

  describe "update" do
    it "should allow mass updating content" do
      c = Content.new(foo: 'foo', bar: 'bar', baz: 'baz')

      c.update(bar: 'xxx')

      expect(c.foo).to eq('foo')
      expect(c.bar).to eq('xxx')
      expect(c.baz).to eq('baz')
    end
  end

  describe "serialization" do
    it "should serialize to JSON" do
      c = Content.new([{a: 'a', b: ['stuff', {doge: 'wow'}]}, 'foo', {a: ['alien', 'shit']}])
      expected = '[{"a":"a","b":["stuff",{"doge":"wow"}]},"foo",{"a":["alien","shit"]}]'

      expect(c.to_json).to eq(expected)
    end

    it "should parse JSON" do
      c = Content.from_json('[{"a":"a","b":["stuff",{"doge":"wow"}]},"foo",{"a":["alien","shit"]}]')

      expect(c[0].a).to eq('a')
      expect(c[0].b[0]).to eq('stuff')
      expect(c[0].b[1].doge).to eq('wow')
      expect(c[1]).to eq('foo')
      expect(c[2].a[0]).to eq('alien')
      expect(c[2].a[1]).to eq('shit')
    end
  end
end
