# The Colonel

Git backed content storage library for ruby.

The Colonel is essentially a NoSQL database which supports versioned structured content storage with a publishing workflow (currently draft (master) -> published) and automatic indexing for querying and search (full-text).

## Installation

Add this line to your application's Gemfile:

    gem 'colonel', git: 'git://github.com/bskyb-commerce/colonel.git

And then execute:

    $ bundle

### Dependencies

The Colonel requires at least [elasticsearch](http://www.elasticsearch.org) 1.0 to work.

## Usage

Require `colonel` where you need to use it

```ruby
require 'colonel'
```

and optionally

```
include Colonel
```

### Configuration

The `Colonel` module exposes a `config` struct for configuration options

```ruby
Colonel.config.storage_path = 'tmp/colonel_storage/'
Colonel.config.elasticsearch_uri = 'elasticsearch.myapp.com:9200'
Colonel.config.rugged_backend = backend_instance # optional, see below
```

### Create or open a ContenItem

You can start using The Colonel without deriving your own content type. It can handle any kind
of content structure and has sensible defaults for indexing.

To create a new ContentItem just create a new instance of the class

```ruby
doc = ContentItem.new({title: 'My Item', tags: ['Test', 'Content'], body: 'Some text.'})
```

You can now access the attributes

```ruby
doc.title
# => 'My Item'

doc.tags[1]
# => 'Content'

doc.body = 'Some other text'
doc.body
# => 'Some other text'

doc.id
# => 'b1ff909250a5fda83042abc86f7033f9' # randomly generated
```

And you can also save the item, you are required to supply an author with an optional message and timestamp paramater. For example you can do the following:

```ruby
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' })
```


or using the optional parameters:

```ruby
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'My save message.')
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'My save message.', Time.now)
```

You now have an item that has a single revision in `master` state (draft). You can
update the document's content and save again with or without a commit message.

```ruby
doc.tags << "Updated"
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' })
```

or

```ruby
doc.tags << "Updated"
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'My comment for the update.')
```

The document now has two revisions. Every save creates a new revision. All saves
update the `master` state (draft).

To open the document later do

```ruby
ContentItem.open('b1ff909250a5fda83042abc86f7033f9')
# => #<ContentItem:9656a765>
```

### Promoting draft to published

Once the document is ready to be seen you can publish it

```ruby
doc.promote!('master', 'published', { name: 'The Colonel', email: 'colonel@example.com' }, 'Published the document!')
```

That takes the current revision of `master` and creates a `published` revision from it.
You can continue editing and saving and the preview will be kept the same, until you
call `promote!` again.

There is no possibility to drop a revision from either state. The Colonel is only moving
forward. If you need to take the content down entirely for any reason, you need to implement
it as an application level concept.


### Viewing version history

```ruby
doc.history('published')
# => [{:rev => 'fb8d8b4369c084668ab8c62cc50dbc184ff23cc', ... }, {...}, ...]
```

Will give you a history of all published versions of the item, skipping the intermediate
draft versions. Passing `master` will do the same with preview versions skipping draft
versions.

### Showing content at a given revision / state

You can load any revision of the existing item by it's sha1 or the state name

```ruby
doc.load!('fb8d8b4369c084668ab8c62cc50dbc184ff23cc')
doc.load!('published')
```

You can also open an item specifying the revision/state

```ruby
ContentItem.open('b1ff909250a5fda83042abc86f7033f9', 'published')
```

### Listing and searching

You can list all the content items using the `list` class method. It supports sorting and
pagination.

```ruby
ContentItem.list(state: 'published', size: 10, from: 50, sort: {updated_at: 'desc'})
# => { total: 43, hits: [ ... ContentItem instances ... ] }
```

If you need more than that, you can search across all of the content. You can do a simple query string search or you can provide a query object (ElasticSearch Query DSL) for more complex searches.  There are two arguments the `query` and optional `opts`.

##### Opts
* `size` - Size for a single page
* `from` - Start from a certain number of results
* `latest` - Denotes searching across only the current state of a document rather than including its revisions.
* `sort` - sort specification from elastic search.

#### Query using DSL
```ruby
query = {
  query: { 
    filtered: { 
      query: {
        query_string: { query: "My Document" } 
      }
    }
  }
}

ContentItem.search(query, { size: 10 })
```

#### Query using strings
```ruby
ContentItem.search('How to use the Colonel?', { size: 10 })
````

The query can be either a string or a Hash. It gets passed through to the underlying Elasticsearch
index, so you can use all the power that [Elasticsearch provides]().

### Custom content type

In most cases you'd want to derive from the content item and create your own content type.
That allows you to customize the Elasticsearch indexing options

```ruby
class DocumentItem < Colonel::ContentItem
  index_name 'colonel-app'
  item_type_name 'document'

  attributes_mapping do
    {
      tags: {
        type: "string",
        index: "not_analyzed", # we only want exact matches
        boost: 2 # boost tags when searching
      },
      slug: {
        type: "string"
        index: "not_analyzed"
      }
    }
  end
end
```

### Alternative backends

Internally, Colonel uses rugged for content item storage. Apart from the default file storage it supports
alternative storage backends for rugged. For example, you could use [rugged-redis](http://github.com/redbadger/rugged-redis) to store to redis.

To set the backend, use the configuration

```ruby
require 'rugged-redis'

redis_backend = Rugged::Redis::Backend.new(host: '127.0.0.1', port: 6379, password: 'muchsecretwow')
Colonel.config.rugged_backend = redis_backend
```

### Integrating with ActiveModel

Typicaly, you'd want to treat your content items as ActiveModel instances to integrate well
with Ruby on Rails. The best option is probably to have your ContentItem instance as an instance
variable in it.

An example implementation could look like this

```ruby
class Document
  include ActiveModel::Model
  include ActiveModel::Validations

  def initialize(attributes = {}, opts = {})
    if opts[:document]
      @document = opts[:document]
      return
    end

    @new_record = true

    @document = DocumentItem.new({})
    attributes.each do |k, v|
      send("#{k}=", v)
    end
  end

  # Attributes

  def title
    @document.title
  end

  def title=(val)
    @document.title = val
  end

  def tags
    @document.tags || []
  end

  def tags=(val)
    val = [] if val.nil?
    val = val.split(/\s*,\s*/).map { |t| t.strip } if val.is_a?(String)

    @document.tags = val
  end

  def body
    @document.body
  end

  def body=(val)
    @document.body = val
  end

  # Lifecycle

  def save
    @new_record = false
    @document.save!(Time.now)
  end

  def update(opts)
    opts.each do |k, v|
      send("#{k}=", v)
    end

    save
  end

  # Revisions & States

  def versions(state, &block)
    @document.history(state, &block).map do |rev|
      rev[:was_published] = published?(rev[:rev])
      rev
    end
  end

  def at_revision(rev)
    doc = @document.clone
    doc.load!(rev)

    self.class.new(nil, document: doc)
  end

  # States

  def publish!
    @document.promote!('master', 'published', 'publish from the colonel', Time.now)
  end

  def draft_rev
    @document.history('master') do |c|
      return c[:rev]
    end
  end

  # returns the first draft rev that was later published
  def published_rev
    @document.history('master') do |c|
      return c[:rev] if published?(c[:rev])
    end
  end

  def published?(rev = nil)
    rev ||= @document.revision
    @document.has_been_promoted?('published', rev)
  end

  # Active Model

  def persisted?
    !@new_record
  end

  def to_key
    [@document.id]
  end

  def to_param
    @document.id
  end

  class << self
    def all(opts = {})
      in_state('master', opts)
    end

    def published(opts = {})
      in_state('published', opts)
    end

    def in_state(state, opts = {})
      list_opts = {state: state}.merge(opts)

      hits = DocumentItem.list(list_opts)
      docs = hits[:hits].map do |hit|
        Document.new(nil, document: hit)
      end

      [docs, hits[:total]]
    end

    def find(name, state = 'master')
      item = DocumentItem.open(name)
      return nil unless item

      item.load!(state) unless state == 'master'

      Document.new(nil, document: item)
    end
  end
end
```

This is indeed quite verbose, but most of the more general things will be abstracted into a mixin
in the near future. Stay tuned.

## Internals

### Storage

Internally each document is stored in it's own git repository as a single file called `content`.
The repository has two branches: `master` and `published`.

Every time you save the document a new commit is created in `master`. When you promote it, a merge
commit is created from `master` to `published`. No fast forwarding is done. You can suport more
stages in the publishing pipeline.

Listing history *always* follows only the first parent of a commit and stops with the first commit
that only has one parent, thus staying in a branch you ask for. That way you can list the history
of just the published versions easily. As a trade-off, it's a bit more involved to find a revision
in `maser` that was published (see example above).

### Indexing & search

Indexing and search is provided by Elastisearch. There is basic mapping provided out of the box and
the documents and their revisions are indexed separately with a parent-child relationship that allows
searching through the history as well.

The default mapping is as follows (you can override all of it)

Revision

```ruby
{
  _source: { enabled: false }, # you only get what you store
  _parent: { type: item_type_name },
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
    }
  }
}
```

Item

```ruby
{
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
    }
  }
}
```

## Contributing

1. Fork it ( http://github.com/[my-github-username]/colonel/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
