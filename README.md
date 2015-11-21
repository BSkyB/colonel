# The Colonel

Versioned content storage library for ruby.

The Colonel is a versioned document storage library, publishing workflow support and and automatic indexing for querying and search (full-text). It is meant to serve as a backend for applications that store user editable documents in a
multi-user environment. (These are usually called Content Management Systems, but the term is too general to just throw around).

Internally, The Colonel uses git for storage and Elasticsearch for search and querying. By default it saves to disk, but it also supports alternative backends.

## Installation

Add this line to your application's Gemfile:

    gem 'colonel', git: 'git://github.com/bskyb-commerce/colonel.git, tag: `[version_you_want]`

And then execute:

    $ bundle

### Dependencies

The Colonel requires at least [elasticsearch](http://www.elasticsearch.org) 1.0 to work.

NOTE: The Colonel currently doesn't work with elasticsearch 1.2 or later, which is a known issue
that will be fixed. (Watch issue [#44](https://github.com/bskyb-commerce/colonel/issues/44) pull requests welcome)

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

### Initialization

Before you can use the Colonel, you also need to initialise the search provider, which idempotently
creates the search index and registers all custom types.

```
Colonel::ElasticsearchProvider.initialize!
```

### Create or open a Document

You can start using The Colonel without deriving your own content type. It can handle any kind
of content structure and has sensible defaults for indexing.

To create a new document just create a new instance of the class

```ruby
doc = Document.new({title: 'My Item', tags: ['Test', 'Content'], body: 'Some text.'})
```

You can now access the attributes

```ruby
doc.content.title
# => 'My Iem'

doc.content.tags[1]
# => 'Content'

doc.content.body = 'Some other text'
doc.content.body
# => 'Some other text'

doc.id
# => 'b1ff909250a5fda83042abc86f7033f9' # randomly generated
```

You can save the document, creating a revision. You have to supply an author with an optional message and timestamp paramater. For example you can do the following:

```ruby
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' })
```

or using the optional parameters:

```ruby
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'Totally saved this.')
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'Totally saved this just now.', Time.now)
```

You now have an document that has a single revision in `master` state (draft). You can
update the document's content and save again with or without a commit message.

```ruby
doc.content.tags << "Updated"
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' })
```

or

```ruby
doc.content.tags << "Updated"
doc.save!({ name: 'The Colonel', email: 'colonel@example.com' }, 'My comment for the update.')
```

The document now has two revisions. Every save creates a new revision. All saves
update the `master` state (default, draft). There is also a `save_in!` method when you absolutely need to
save into a different state.

To open the document later do

```ruby
Document.open('b1ff909250a5fda83042abc86f7033f9')
# => #<Document: ...>
```

### Promoting draft to published

Once the document is ready to be seen you can publish it

```ruby
doc.promote!('master', 'published', { name: 'The Colonel', email: 'colonel@example.com' }, 'Published the document!')
```

That takes the current revision of `master` and creates a `published` revision from it.
You can continue editing and saving and the published revision will be kept the same, until you
call `promote!` again. You can view the published revision using

```ruby
revision = doc.revisions['published'] # => #<Revision ...>
revision.content # => published content
```

There is no possibility to drop a revision from either state. The Colonel is only moving
forward. If you need to take the content down entirely for any reason, you need to implement
it as an application level concept.

### Viewing version history

```ruby
doc.history('published').each do |rev|
  # rev is a Revision
end
```

Will give you a history of all published versions of the document, skipping the draft versions.
Passing `master` will do the same with preview versions skipping draft versions. You can call
history without an argument - the default is `master`.

### Showing content at a given revision / state

You can get any revision of the existing document by it's sha1 or the state name

```ruby
doc.revisions['fb8d8b4369c084668ab8c62cc50dbc184ff23cc']
doc.revisions['published']
```

### Listing and searching

You can list all the documents using the `list` method. It supports sorting and
pagination.

```ruby
results = Document.list(state: 'published', size: 10, from: 50, sort: {updated_at: 'desc'})
# => #<ElasticsearchResultSet: ...>

results.total # => 67
results.each do |result|
  # result is a Document
end
```

If you need more than that, you can search across all of the content. You can do a simple query string search or you can provide a query object (ElasticSearch Query DSL) for more complex searches.  There are two arguments the `query` and optional `opts`.

##### Opts

* `size` - Size for a single page
* `from` - Start from a certain number of results
* `latest` - Denotes searching across only the current state of a document rather than including its revisions.
* `sort` - sort specification from elastic search.
* `raw` - when `true`, returns only fields available in ElasticSearch in a `Content` rather than a `ContentItem` instance

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

Document.search(query, { size: 10 })
```

#### Query using strings

```ruby
Document.search('How to use the Colonel?', { size: 10 })
````

The query can be either a string or a Hash. It gets passed through to the underlying Elasticsearch
index, so you can use all the power that [Elasticsearch provides]().

### Custom content type

In most cases you'd want to create your own content type. That allows you to customize the Elasticsearch
indexing options

```ruby
Document = Colonel::DocumentType.new('document') do
  index_name 'colonel-app'

  attributes_mapping({
    tags: {
      type: "string",
      index: "not_analyzed", # we only want exact matches
      boost: 2 # boost tags when searching
    },
    slug: {
      type: "string"
      index: "not_analyzed"
    }
  })
end
```

### Custom indexing scopes

For some workflows, the default indexing the Colonel does is not enough and you need your own special "revision logs".
Let's say you have a workflow that promotes articles from a `master` state to `published` or `archived` state. To
quickly list all articles that were published **and not later archived**, you can't rely on just the state listings.
For one you'd have to compare the timestamps on the records to find out which is more recent, and you'd also need
two queries to do the job.

In this case it's much better to define a custom scope for the events, like this

```ruby
DocumentType = Colonel::DocumentType.new('my_type') do
  ...
  scope 'visible', on: [:save, :promotion], to: ['published', 'archived']
```

This will index the document with a scope 'visible', every time it is saved or promoted into the listed states.
You can pass a single state or multiple states and the same for events (there are just two - `:save`, and `:promotion`).
The visible scope will therefore include just the latest of all the selected changes.

Then you can search with the `visible` scope and narrow the results by state

```ruby
DocumentType.search('state:published', scope: 'visible')
```

### Alternative backends

> This feature is still fairly experimental. It is used in production and works perfectly fine, but
you may have some difficulties installing dependencies and building all the binary extensions needed. Consider yourself
warned.

Internally, Colonel uses rugged for document storage. Apart from the default file storage it supports
alternative storage backends for rugged. For example, you could use [rugged-redis](http://github.com/redbadger/rugged-redis) to store to redis.

To set the backend, use the configuration

```ruby
require 'rugged-redis'

redis_backend = Rugged::Redis::Backend.new(host: '127.0.0.1', port: 6379, password: 'muchsecretwow')
Colonel.config.rugged_backend = redis_backend
```

## Documentation

See the <features> folder for more detailed documentation.

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
in `master` that was published (see example above).

### Indexing & search

Indexing and search is provided by Elastisearch. There is basic mapping provided out of the box and
the documents and their revisions are indexed separately with a parent-child relationship that allows
searching through the history as well.

The default mapping is as follows (you can override all of it)

Revision

```ruby
{
  _source: { enabled: false }, # you only get what you store
  _parent: { type: type_name },
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
