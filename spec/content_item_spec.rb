require 'spec_helper'

describe ContentItem do
  before :each do
    ContentItem.stub(:setup_search!)
  end

  describe "config" do
    it "should create an elasticsearch client" do
      ::Elasticsearch::Client.should_receive(:new).with(host: 'localhost:9200', log: false)
      ContentItem.es_client
    end
  end

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

    before do
      ContentItem.any_instance.stub(:index!)
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
    before do
      ContentItem.any_instance.stub(:index!)
      ContentItem.any_instance.stub(:rollback_index!)
    end

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

  describe "search" do
    let :client do
      Object.new
    end

    before do
      ContentItem.stub(:es_client).and_return(client)
    end

    describe "suppport" do
      let :indices do
        Object.new
      end

      it "should create index if it doesn't exist" do
        client.stub(:indices).and_return(indices)

        indices.should_receive(:exists).with(index: 'git-cma-content').and_return(false)
        indices.should_receive(:create).with(index: 'git-cma-content', body: {
          mappings: {
            'content_item' => ContentItem.item_mapping,
            'content_item_rev' => ContentItem.send(:default_revision_mapping)
          }
        }).and_return(true)

        ContentItem.send :ensure_index!
      end

      it "should not create index if it exists" do
        client.stub(:indices).and_return(indices)

        indices.should_receive(:exists).with(index: 'git-cma-content').and_return(true)
        indices.should_not_receive(:create)

        ContentItem.send :ensure_index!
      end

      it "should have the right item item_mappings" do
        mappings = {
          properties: {
            id: {
              type: 'string',
              index: 'not_analyzed'
            },
            state: {
              type: 'string',
              index: 'not_analyzed'
            },
            updated_at: {
              type: 'date'
            }
          }
        }

        expect(ContentItem.item_mapping).to eq(mappings)
      end

      it "should have the right default mappings" do
        mappings = {
          _source: { enabled: false },
          _parent: { type: 'content_item' },
          properties: {
            id: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            revision: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            state: {
              type: 'string',
              store: 'yes',
              index: 'not_analyzed'
            },
            updated_at: {
              type: 'date'
            }
          }
        }

        expect(ContentItem.send(:default_revision_mapping)).to eq(mappings)
      end
    end

    describe "indexing" do
      let :time do
        Time.now
      end

      it "should index the document" do
        ci = ContentItem.new(body: "foobar")

        body = { id: ci.id, revision: 'yzw', state: 'master', updated_at: time.iso8601, body: "foobar" }

        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item', id: "#{ci.id}-master", body: body)
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item_rev', parent: "#{ci.id}-master", id: "#{ci.id}-yzw", body: body)

        ci.index!(state: 'master', updated_at: time, revision: 'yzw')
      end

      it "should index the document when saved" do
        ci = ContentItem.new(body: "foobar")
        ci.document.should_receive(:save!).and_return('xyz1')

        body = { id: ci.id, revision: 'xyz1', state: 'master', updated_at: time.iso8601, body: "foobar" }
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item', id: "#{ci.id}-master", body: body)
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item_rev', parent: "#{ci.id}-master", id: "#{ci.id}-xyz1", body: body)


        expect(ci.save!(time)).to eq('xyz1')
      end

      it "should index the document when promoted" do
        ci = ContentItem.new(body: "foobar")
        ci.document.should_receive(:promote!).and_return('xyz1')

        body = { id: ci.id, revision: 'xyz1', state: 'preview', updated_at: time.iso8601, body: "foobar" }
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item', id: "#{ci.id}-preview", body: body)
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item_rev', parent: "#{ci.id}-preview", id: "#{ci.id}-xyz1", body: body)

        expect(ci.promote!('master', 'preview', 'foo', time)).to eq('xyz1')
      end

      it "shoud index the document when rolled back" do
        ci = ContentItem.new(body: "foobar")
        ci.document.should_receive(:rollback!).and_return('rev1')
        ci.should_receive(:rollback_index!).with('preview').and_return('rev1')

        expect(ci.rollback!('preview')).to eq('rev1')
      end

      it "should index a complex the document" do
        ci = ContentItem.new(title: "Title", tags: ["tag", "another", "one more"], body: "foobar", author: {first: "Viktor", last: "Charypar"})

        body = {
          id: ci.id, revision: 'yzw', state: 'master', updated_at: time.iso8601,
          title: "Title", tags: ["tag", "another", "one more"], body: "foobar", author: {first: "Viktor", last: "Charypar"}
        }

        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item', id: "#{ci.id}-master", body: body)
        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item_rev', parent: "#{ci.id}-master", id: "#{ci.id}-yzw", body: body)

        ci.index!(state: 'master', updated_at: time, revision: 'yzw')
      end

      it "should rollback an indexed document" do
        ci = ContentItem.new(body: 'foobar')

        ci.should_receive(:clone).and_return(ci)

        ci.should_receive(:history).with('preview').and_return([{time: time + 100, rev: 'rev2'}, {time: time, rev: 'rev1'}])

        ci.should_receive(:load!).with('rev1')
        ci.document.should_receive(:content).and_return({body: 'old content'}.to_json)

        body = { id: ci.id, revision: 'rev1', state: 'preview', updated_at: time, body: "old content" }

        client.should_receive(:index).with(index: 'git-cma-content', type: 'content_item', id: "#{ci.id}-preview", body: body)
        client.should_receive(:delete).with(index: 'git-cma-content', type: 'content_item_rev', id: "#{ci.id}-rev2")

        ci.rollback_index!('preview')
      end
    end

    describe "Listing and searching" do
      let :results do
        {"hits" => {"hits" => []}}
      end

      it "should list all the items" do
        query = {
          query: {
            constant_score: {
              filter: {
                term: { state: 'master'}
              }
            }
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: query).and_return(results)

        ContentItem.list
      end

      it "should list items by state" do
        query = {
          query: {
            constant_score: {
              filter: {
                term: { state: 'preview'}
              }
            }
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: query).and_return(results)

        ContentItem.list(state: 'preview')
      end

      it "should list items in a given order" do
        query = {
          query: {
            constant_score: {
              filter: {
                term: { state: 'master'}
              }
            }
          },
          sort: [
            {updated_at: 'desc'}
          ]
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: query).and_return(results)

        ContentItem.list(sort: {updated_at: 'desc'})
      end

      it "should limit items and start from a given index" do
        query = {
          query: {
            constant_score: {
              filter: {
                term: { state: 'master'}
              }
            }
          },
          from: 40, size: 20
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: query).and_return(results)

        ContentItem.list(from: 40, size: 20)
      end

      it "should search with string query" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.search("query")
      end

      it "should search with DSL query" do
        body = {
          query: {
            match: {
              id: "abcdef"
            }
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.search(match: {id: 'abcdef'})
      end

      it "should sort search" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          },
          sort: [
           {updated_at: :desc}
          ]
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.search("query", sort: {updated_at: :desc})
      end

      it "should limit and skip" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          },
          from: 40, size: 20
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.search("query", from: 40, size: 20)
      end

      it "should search across all version" do
        body = {
          query: {
            has_child: {
              type: "content_item_rev",
              query: {
                query_string: {
                  query: "query"
                }
              }
            }
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.search("query", history: true)
      end

      it "should load the right id and revision" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          }
        }

        results = {
          "hits" => {
            "hits" => [
              {
                "_source" => {
                  "id" => "abc",
                  "revision" => "def"
                }
              }
            ]
          }
        }

        client.should_receive(:search).with(index: 'git-cma-content', type: 'content_item', body: body).and_return(results)
        ContentItem.should_receive(:open).with("abc", "def")

        ContentItem.search("query")
      end
    end

    describe "customized mappings" do
      let :indices do
        Object.new
      end

      it "should update mappings on demand" do
        ContentItem.attributes_mapping do
          {
            tags: {
              type: 'string',
              index: 'not_analyzed'
            }
          }
        end

        expect(ContentItem.item_mapping[:properties]).to have_key(:tags)
        expect(ContentItem.item_mapping[:properties][:tags]).to eq({type: 'string', index: 'not_analyzed'})
      end

      it "should extend mappings with user defined ones" do
        body = {
          'content_item' => {
            properties: {
              # _id is "{id}-{state}"
              id: {
                type: 'string',
                index: 'not_analyzed'
              },
              state: {
                type: 'string',
                index: 'not_analyzed'
              },
              updated_at: {
                type: 'date'
              },
              tags: {
                type: 'string',
                index: 'not_analyzed'
              }
            }
          }
        }

        rev_body = {
          'content_item_rev' => {
            _source: { enabled: false }, # you only get what you store
            _parent: { type: 'content_item' },
            properties: {
              # _id is "{id}-{rev}"
              id: {
                type: 'string',
                store: 'yes',
                index: 'not_analyzed'
              },
              revision: {
                type: 'string',
                store: 'yes',
                index: 'not_analyzed'
              },
              state: {
                type: 'string',
                store: 'yes',
                index: 'not_analyzed'
              },
              updated_at: {
                type: 'date'
              },
              tags: {
                type: 'string',
                index: 'not_analyzed'
              }
            }
          }
        }

        client.stub(:indices).and_return(indices)

        indices.should_receive(:put_mapping).with(index: 'git-cma-content', type: 'content_item', body: body)
        indices.should_receive(:put_mapping).with(index: 'git-cma-content', type: 'content_item_rev', body: rev_body)

        ContentItem.put_mapping!
      end
    end
  end
end
