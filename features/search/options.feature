Feature: Search options
  Search support pagination, defaulting to a limit of 10 records

  ```ruby
  results = Document.list(from: 20, size: 50)
  ```

  and sorting by specific keys

  ```ruby
  results = Document.list(sort: 'title')
  results = Document.list(sort: ['title', 'date'])
  results = Document.list(sort: ['title', {date: { order: 'desc' }}])
  ```

  Scenario: Pagination

  Scenario: Sorting
