# Command Line Interface

The Colonel comes with a command line interface for various maintenance tasks,
especially to perform a backup and restore and reindexing tasks.

The CLI environment can be customized in a `.colonel` file in the directory
where you run the command. For Rails applications, the basic `.colonel` could
look something like this (assuming your rails config initialises all the
`Document` subclasses).

```
require_relative "config/environment"
```
