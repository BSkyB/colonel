#Git::Cma

Git backed content storage library for ruby. Supports versioned document storage with publishing workflow
(currently draft -> preview -> published).

## Installation

Add this line to your application's Gemfile:

    gem 'git_cma', git: 'git://github.com/bskyb-commerce/git-cma.git

And then execute:

    $ bundle

## Usage

```ruby
require 'git_cma'

include GitCma
```

### Create and edit a document

To create a new document named `test_document`

```ruby
doc = Document.new('test_document')
doc.content = 'Testing initial content'

doc.save(Time.now)
```

You now have a document that has a single version in draft state. You can
update the document's content

```ruby
doc.content = "Testing another content"
doc.save(Time.now)
```

The document now has two versions. Every save creates a version. All saves
create begin as a draft.

### Promoting draft to preview and preview to publish

Once the document is ready to be seen you can advance it to preview

```ruby
doc.preview!(Time.now)
```

That takes the current draft and creates a preview version from it. You can continue
editing and saving and the preview will be kept the same, until you call `preview!` again.

The same is true about publishing, the only difference is that publishing takes the current
preview version and publishes it.

```ruby
doc.publish!(Time.now)
```

### Viewing version history

```ruby
doc.history('published')
```

Will give you a history of all published versions of the document, skipping the intermediate
preview and draft versions. Passing `'preview'` will do tha same with preview versions
skipping draft versions.

### Showing content at a given revision / state

TODO

## Internals

Internally each document is stored in it's own git repository as a single file called `content`.
The repository has three branches: `master`, `preview` and `published`.

Every time you save the document a new commit is created in `master`. When you promote it, a merge
commit is created from the lower state to the higher state. No fast forwarding is done.

Listing history always follows only the first parent of a commit and stops with the first commit
that only has one parent, thus staying in a branch you ask for.

## Contributing

1. Fork it ( http://github.com/[my-github-username]/git-cma/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
