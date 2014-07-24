# Search

All content saved using the Colonel is indexed for searching.
You can search across all documents, including history, in a
given state. You can also define custom search scopes (see
below).

The Colonel supports listing as a special case of search with
no query

```ruby
results = Document.list
```

To search with a query, you can pass in either a string query
using the elasticsearch language

```ruby
results = Document.search('title:"Hello World"')
```

or the structured elasticsearch DSL

```ruby
results = Document.search({query: {term: {title: 'Hellow World'}}})
```

The results coming back are a hash with the following structure

```ruby
{
  total: 100 # number of results
  hits: ...
  facets: ...
}
```

in `hits` you get Document instances, unless you searched with
the `raw` option.

You can customise the mappings used when indexing the documents as well
as the type name to use. In order to do that, you have to subclass
the `Document` class. See <custom.feature> for details.
