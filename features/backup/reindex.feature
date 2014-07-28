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

  Scenario: Reindex custom type
    Given the following configuration:
      """
      Article = Colonel::DocumentType.new('article') do
        attributes_mapping do
          {
            stringid: {
              type: :string,
              index: :not_analyzed
            },
            tags: {
              type: :string,
              analyzer: :whitespace
            }
          }
        end
      end
      """
    And documents of class "Article" with content:
      | text           | stringid   | tags      |
      | First article  | first_one  | red blue  |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |
    When I recreate the Elasticsearch index
    And I reindex the "Article" documents
    And I search "Article" for 'green pink blu one'
    Then I should get the following documents:
      | text           | stringid   | tags      |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |
