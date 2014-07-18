# Revision history

Content items in the Colonel are versioned. Each `save!` creates
a new revision with an id, content, author and other metadata.

```ruby
item = ContentItem.new(example: 'hello')
revision = item.save!({name: 'Test', email: 'test@example.com'})

revision.id       # => sha1 id of the revision
revision.author   # => {name: 'Test', email: 'test@example.com'}
revision.previous # => a Revision
... # more metadata are available
```

Content items always open with the latest revision loaded. Calls
to dynamic attribute readers are forwarded to it, calls to attribute
writers are forwarded to a "work in progress" revision dynamically
created for you. When you call `save!` that revision gets saved.

It's possible to iterate through the revision history

```ruby
item.history # => revision iterator

item.history do |revision| # => block form
  revision # => a revision
end
```

It's also possible to get history for a particular revision (all
the revisions prior to the specified one)

```ruby
# revision is a sha1 or an instance of Revision
item.history(revision) do |rev|
  rev
end
```
