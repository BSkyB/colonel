# Bacup & Restore

The Colonel (or rather the rugged library which it uses) supports multiple
storage backends. It is therefore useful to have a common mechanism to
dump the contents of the storage into a file and load them back in, independen
of the backend used.

For that purpose the Colonel has a serialization system capable of writing
the complete contents of a Colonel instance into a file, and load it back up.
At the same time, it can reindex the content into Elasticsearch, including
simply reindexing the content from the rugged storage.
