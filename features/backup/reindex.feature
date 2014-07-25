Feature: Reindex content to Elasticsearch
  The elasticsearch index is disposable. All the information
  stored inside a Colonel instance is in the git backend and you
  can rebuild the Eleasticsearch index at any point:

  ```ruby
  index = DocumentIndex.new(Colonel.config.storage_path)
  documents = DocumentIndex.documents.select {|d| d[:type] == MyClass.type_name }.map { |d| MyClass.open(d[:name]) }

  Indexer.index(documents)
  ```

  Scenario: Reindex basic documents
    Given the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
    When I recreate the Elasticsearch index
    And I reindex the documents
    And I list all documents
    Then I should get the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |

