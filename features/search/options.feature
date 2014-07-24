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

  # Can't simply order by text, it get's analyzed
  Scenario: Sorting and pagination
    Given the following documents:
      | text            | order |
      | First document  | 1     |
      | Second document | 2     |
      | Third document  | 3     |
    When I list "2" documents starting from "0" sorted by "order"
    Then I should get the following documents in order:
      | text            |
      | First document  |
      | Second document |
    When I list "2" documents starting from "1" sorted by "order"
    Then I should get the following documents in order:
      | text            |
      | Second document |
      | Third document  |
