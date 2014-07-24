Feature: Searching by query
  For any kind of more specialized search there is the
  full search method.

  It takes the same arguments as list, plus an extra query
  as the first one. Query can be an elasticsearch DSL or
  a string query.

  ```ruby
  results = Document.search("Give me results")
  ```

  and

  ```ruby
  results = Document.search({query: {match: {_all: "Give me results"}})
  ```

  would return the same results.

  You can also extend your search to all history of the documents

  ```ruby
  results = Document.search("Give me results", history: true)
  ```

  Scenario: String search
    Given the following documents:
      | text            | comment |
      | First document  | cool    |
      | Second document | strange |
      | Third document  | nope    |
    When I search for "first nope"
    Then I should get the following documents:
      | text           | comment |
      | First document | cool    |
      | Third document | nope    |

  Scenario: DSL search
    Given the following documents:
      | text            | comment |
      | First document  | cool    |
      | Second document | strange |
      | Third document  | nope    |
    When I search with query:
      """
      { "query": { "match": { "_all": "cool third" } } }
      """
    Then I should get the following documents:
      | text           | comment |
      | First document | cool    |
      | Third document | nope    |


  Scenario: History search
    Given a document with the following content revisions:
      | text           |
      | First content  |
      | Second content |
      | Third content  |
    When I search in history for "first"
    Then I should get the following documents:
      | text          |
      | Third content |

