Feature: Listing
  The most basic kind of search is plain listing.

  Default state to list is master, with the assumption that
  that's where all the different content is anyway. You can
  also specify a different state

  ```ruby
  results = Document.list(state: 'published')
  ```

  Scenario: Simple listing
    Given the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
    When I list all documents
    Then I should get the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |

  Scenario: Listing published documents
    Given the following documents:
      | text            |
      | First document  |
      | Second document |
    Given the following documents promoted to "published":
      | text                      |
      | First published document  |
      | Second published document |
      | Third published document  |
    When I list all "published" documents
    Then I should get the following documents:
      | text                      |
      | First published document  |
      | Second published document |
      | Third published document  |
