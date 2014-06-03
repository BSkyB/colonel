require 'spec_helper'

describe ContentItem do
  before :all do
    Colonel.config.index_name = 'colonel-content-index'
  end

  before :each do
    allow(ContentItem).to receive(:setup_search!)
  end

  describe "config" do
    it "should create an elasticsearch client" do
      expect(::Elasticsearch::Client).to receive(:new).with(host: 'localhost:9200', log: false)
      ContentItem.es_client
    end
  end

  describe "creating" do
    it "should create item with content from hash" do
      c = ContentItem.new({foo: 'foo', bar: 'bar'})

      expect(c.foo).to eq('foo')
      expect(c.bar).to eq('bar')
    end

    it "should create item with content from array" do
      c = ContentItem.new(['foo', 'bar'])

      expect(c[0]).to eq('foo')
      expect(c[1]).to eq('bar')
    end

    it "should get a document and surface the name as id" do
      c = ContentItem.new({foo: 'foo', bar: 'bar'})

      expect(c.document).to be_a(Document)
      expect(c.id).to eq(c.document.name)
    end

    it "should take a document in opts hash and deserialize it's content" do
      doc = Document.new('test-type', nil, content: '{"foo": "bar", "a": ["a", 1]}')
      con = ContentItem.new(nil, document: doc)

      expect(con.foo).to eq('bar')
      expect(con.a[0]).to eq('a')
      expect(con.a[1]).to eq(1)
    end
  end

  describe "updating" do
    it "should allow mass updating content" do
      con = ContentItem.new({foo: 'foo', bar: 'bar', baz: 'baz'})

      con.update(bar: 'xxx')

      expect(con.foo).to eq('foo')
      expect(con.bar).to eq('xxx')
      expect(con.baz).to eq('baz')
    end

    it "should forward delete_field to content" do
      con = ContentItem.new({foo: 'foo', bar: 'bar', baz: 'baz'})

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

    let :author do
      { name: 'The Colonel', email: 'colonel@example.com' }
    end

    let :document do
      Struct.new(:name, :content, :type).new('axbcd', '{"foo":"bar"}', 'test-type')
    end

    it "should serialize and save content without message" do
      con = ContentItem.new({key: 'value', another: ['array']})
      allow(con).to receive(:index!)

      expect(con.document).to receive(:content=).with('{"key":"value","another":["array"]}')
      expect(con.document).to receive(:save_in!).with('master', author, '', time).and_return('abcdef')

      expect(con.save!({ name: 'The Colonel', email: 'colonel@example.com' }, '', time)).to eq('abcdef')
    end

    it "should serialize and save content with message" do
      con = ContentItem.new({key: 'value', another: ['array']})
      allow(con).to receive(:index!)

      expect(con.document).to receive(:content=).with('{"key":"value","another":["array"]}')
      expect(con.document).to receive(:save_in!).with('master', author, 'save from the colonel', time).and_return('abcdef')

      expect(con.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'save from the colonel', time)).to eq('abcdef')
    end

    it "should load and deserialize content" do
      con = ContentItem.new(nil)

      expect(con.document).to receive(:load!).with('abc').and_return('abc')
      expect(con.document).to receive(:content).and_return('{"key":"value","another":["array"]}')

      expect(con.load!('abc')).to eq('abc')
      expect(con.key).to eq('value')
      expect(con.another[0]).to eq('array')
    end

    it "should open a content item by id" do
      expect(Document).to receive(:open).and_return(document)

      con = ContentItem.open('axbcd')

      expect(con.foo).to eq('bar')
    end
  end

  describe "document API" do
    before do
    end

    let :con do
      ContentItem.new(nil).tap do |con|
        allow(con).to receive(:index!)
      end
    end

    it "should delegate revision" do
      expect(con.document).to receive(:revision).and_return('xyz')

      expect(con.revision).to eq('xyz')
    end

    it "should delegate history" do
      expect(con.document).to receive(:history).with('x').and_return('foo')

      expect(con.history('x')).to eq('foo')
    end

    it "should delegate promote!" do
      expect(con.document).to receive(:promote!).with('x', 'y', {}, 'z', 't').and_return('foo')

      expect(con.promote!('x', 'y', {}, 'z', 't')).to eq('foo')
    end

    it "should delegate has_been_promoted?" do
      expect(con.document).to receive(:has_been_promoted?).with('x', 'y').and_return('foo')

      expect(con.has_been_promoted?('x', 'y')).to eq('foo')
    end
  end

  describe "search" do
    let :client do
      Object.new
    end

    before do
      allow(ContentItem).to receive(:es_client).and_return(client)
    end

    describe "returned result" do
      let(:returned_result) { ContentItem.search('*') }
      let(:es_result) do
        { "hits" => {
          "hits" => [],
          "total" => 0
        },
          "facets" => { }
        }
      end

      before(:each) do
        allow(ContentItem.es_client).to receive(:search).and_return(es_result)
      end

      it 'includes facets' do
        expect(returned_result).to have_key(:facets)
        expect(returned_result).to have_key(:hits)
      end
    end

    describe "suppport" do
      let :indices do
        Object.new
      end

      it "should create index if it doesn't exist" do
        allow(client).to receive(:indices).and_return(indices)

        expect(indices).to receive(:exists).with(index: 'colonel-content-index').and_return(false)
        expect(indices).to receive(:create).with(index: 'colonel-content-index', body: {
          mappings: {
            'content_item' => ContentItem.item_mapping,
            'content_item_latest' => ContentItem.item_mapping,
            'content_item_rev' => ContentItem.send(:default_revision_mapping)
          }
        }).and_return(true)

        ContentItem.send :ensure_index!
      end

      it "should not create index if it exists" do
        allow(client).to receive(:indices).and_return(indices)

        expect(indices).to receive(:exists).with(index: 'colonel-content-index').and_return(true)
        expect(indices).not_to receive(:create)

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

      let :author do
        { name: 'The Colonel', email: 'colonel@example.com' }
      end

      it "should index the document" do
        ci = ContentItem.new(body: "foobar")

        body = { id: ci.id, revision: 'yzw', state: 'master', updated_at: time.iso8601, body: "foobar" }

        expect(client).to receive(:bulk).with(body: [
          {index: {_index: 'colonel-content-index', _type: 'content_item_latest', _id: "#{ci.id}", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item', _id: "#{ci.id}-master", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item_rev', _id: "#{ci.id}-yzw", _parent: "#{ci.id}-master", data: body}}
        ])

        ci.index!(state: 'master', updated_at: time, revision: 'yzw')
      end

      it "should index the document when saved" do
        ci = ContentItem.new(body: "foobar")
        expect(ci.document).to receive(:save_in!).and_return('xyz1')

        body = { id: ci.id, revision: 'xyz1', state: 'master', updated_at: time.iso8601, body: "foobar" }
        expect(client).to receive(:bulk).with(body: [
          {index: {_index: 'colonel-content-index', _type: 'content_item_latest', _id: "#{ci.id}", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item', _id: "#{ci.id}-master", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item_rev', _id: "#{ci.id}-xyz1", _parent: "#{ci.id}-master", data: body}}
        ])

        expect(ci.save!("test-item", { name: 'The Colonel', email: 'colonel@example.com' })).to eq('xyz1')
      end

      it "should index the document when promoted" do
        ci = ContentItem.new(body: "foobar")
        expect(ci.document).to receive(:promote!).with('master', 'preview', author, 'foo', time).and_return('xyz1')

        body = { id: ci.id, revision: 'xyz1', state: 'preview', updated_at: time.iso8601, body: "foobar" }
        expect(client).to receive(:bulk).with(body: [
          {index: {_index: 'colonel-content-index', _type: 'content_item_latest', _id: "#{ci.id}", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item', _id: "#{ci.id}-preview", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item_rev', _id: "#{ci.id}-xyz1", _parent: "#{ci.id}-preview", data: body}}
        ])

        expect(ci.promote!('master', 'preview', { email: 'colonel@example.com', name: 'The Colonel' }, 'foo', time)).to eq('xyz1')
      end

      it "should index a complex the document" do
        ci = ContentItem.new(title: "Title", tags: ["tag", "another", "one more"], body: "foobar", author: {first: "Viktor", last: "Charypar"})

        body = {
          id: ci.id, revision: 'yzw', state: 'master', updated_at: time.iso8601,
          title: "Title", tags: ["tag", "another", "one more"], body: "foobar", author: {first: "Viktor", last: "Charypar"}
        }

        expect(client).to receive(:bulk).with(body: [
          {index: {_index: 'colonel-content-index', _type: 'content_item_latest', _id: "#{ci.id}", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item', _id: "#{ci.id}-master", data: body}},
          {index: {_index: 'colonel-content-index', _type: 'content_item_rev', _id: "#{ci.id}-yzw", _parent: "#{ci.id}-master", data: body}}
        ])

        ci.index!(state: 'master', updated_at: time, revision: 'yzw')
      end
    end

    describe "Listing and searching" do
      let :results do
        {"hits" => {"hits" => [{"_source" => {"hi" => "hi."}}]}}
      end

      let :document do
        Document.new("test-type")
      end

      before do
        allow(Document).to receive(:open).and_return(document)
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: query).and_return(results)

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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: query).and_return(results)

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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: query).and_return(results)

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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: query).and_return(results)
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
        ContentItem.search("query")
      end

      it "should hydrate the hits" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          }
        }

        allow(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
        results = ContentItem.search("query")

        expect(results).to have_key(:hits)
        expect(results[:hits].first).to be_a(Colonel::ContentItem)
      end

      it "should hydrate the raw hits" do
        body = {
          query: {
            query_string: {
              query: "query"
            }
          }
        }

        allow(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
        results = ContentItem.search("query", raw: true)

        expect(results).to have_key(:hits)
        expect(results[:hits].first).to be_a(Colonel::Content)
      end

      it "should search with DSL query" do
        body = {
          query: {
            match: {
              id: "abcdef"
            }
          }
        }

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
        ContentItem.search(query: { match: {id: 'abcdef'} })
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
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

        expect(client).to receive(:search).with(index: 'colonel-content-index', type: 'content_item', body: body).and_return(results)
        expect(ContentItem).to receive(:open).with("abc", "def")

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

        latest_body = {
          'content_item_latest' => {
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

        allow(client).to receive(:indices).and_return(indices)

        expect(indices).to receive(:put_mapping).with(index: 'colonel-content-index', type: 'content_item_latest', body: latest_body)
        expect(indices).to receive(:put_mapping).with(index: 'colonel-content-index', type: 'content_item', body: body)
        expect(indices).to receive(:put_mapping).with(index: 'colonel-content-index', type: 'content_item_rev', body: rev_body)

        ContentItem.put_mapping!
      end
    end
  end
end
