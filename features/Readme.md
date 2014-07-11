# Colonel features

This is the living documentation for the Colonel. Each of the folders
here is an area of functionality the Colonel handles, individual features
then describe specifics of those functions.

The general areas are the following:

## Content Storage

The most basic feature of the Colonel is storing structured content.
The Colonel is schema-less and can handle any structure. It's recommended
to create different types for different content structures but you're not forced to.

[Read more about storage](storage/Readme.md)

## Revision History

Each save of a Colonel document creates a new revision. It is impossible
to modify a revision once it was created. Documents are essentially
collections of revisions. More precisely they are [directed acyclic graphs](http://en.wikipedia.org/wiki/Directed_acyclic_graph)
of revisions – each revision has a link to its previous one.

Starting from the latest revision you can go through the older
revisions and get their content, or just get a listing of them.

[Read more about revisions](revisions/Readme.md)

## Publishing Workflow

In most content management scenarios, a single revision history is not enough.
Items go through a publishing process, if only just a simple draft, then published
workflow.

The Colonel has support for arbitrary user-defined workflows specified as
a series of states. You can promote an item from one state to another, which
will always use the most recent revision of the source state. A promotion
actually creates a new revision in the target state with links to both the
previous and the source revisions. You can of cours inspect these relationships.

[Read more about workflow support](workflow/Readme.md)

## Full-text Search

The Colonel supports full-text search across all content stored within
a store. The search is powered by Elasticsearch and content is indexed in
a way that enables searching across the latest revisions, filtering by a given
state and searching through the history too.

Search indexing can be customised for more complex scenarios by defining
custom mappings and custom search scopes.

[Read more about search](search/Readme.md)

## Backup & Restore

All content in a Colonel store can be dumped to a single file and transfered
to another store (which could be backed by a different kind of storage).

As part of the restore, Colonel supports reindexing the content for search,
which can be used separately when the index is lost, or a radical change of
mappings is necessary.

[Read more about backup](backup/Readme.md)

## Command line interface

For administrative tasks, the Colonel has a command line interface (CLI).
It's the primary way to perform backup, restore and other maintanance tasks
but also to inspect the stored content (currently a work in progress).

[Read more about the CLI](cli/Readme.md)
