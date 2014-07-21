# Publishing Workflow

Because the Colonel is aimed at storing document for content management
systems, at it's core, it supports building editing workflows for documents.

By editing workflow, we mean that documents are not only edited to create
new revisions, but also promoted through a series of stages, called states
in the colonel, as they are approved by stakeholders.

```ruby
document = Document.open('xyz')
document.promote!('master', 'published', {name: 'John', email: 'john@example.com'}, 'Good to go!')
```

Each promotion creates a new revision in the target state, linking to the
`previous` revision in that state and the `origin` revision that was promoted.

You can access the latest revision in a given state by the same mechanism you access
all revisions

```ruby
document.revisions['published']
```

and get a history of a given state (following the `previous` links) by passing an
argument to the history method

```ruby
document.history('published')
```

Finally, you can query a revision to see whether it was later promoted to a certain
state.

```ruby
revision.has_been_promoted?('published')
```

What this means exactly requires a little discussion. You're encouraged to read
the [cucumber feature](has_been_promoted.feature).
