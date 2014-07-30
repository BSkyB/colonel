Feature: Backup & Restore through CLI
  The CLI has backup and restore commands to backup all content into a file
  and later restore it from the file again, possibly on a different machine.

  To backup all content you run

  ```
  $ bundle exec colonel backup > backup_file.col
  ```

  The backup task writes to stdout.

  To load the content back, you need to pass the file contents to stdin and
  also provide a list of custom Document classes

  ```
  $ cat bacup_file.col | bundle exec colonel restore -c Article,Image
  ```

  Scenario: Complex backup & Restore
    Given the following configuration:
      """
      Article = Colonel::DocumentType.new('article') do
        attributes_mapping(
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
        )
      end
      """
    And the following .colonel file:
      """
      Colonel.config.index_name = 'colonel-test'

      Article = Colonel::DocumentType.new('article') do
        attributes_mapping(
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
        )
      end
      """
    And the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
    And documents of class "Article" with content:
      | text           | stringid   | tags      |
      | First article  | first_one  | red blue  |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |
    When I run the following command:
      """
      bundle exec colonel backup > backup.col
      """
    And I remove all files in the storage
    And I recreate the Elasticsearch index
    And I run the following command:
      """
      bundle exec colonel restore < backup.col
      """
    And I list all documents
    Then I should get the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
    When I search "Article" for 'green pink blu one'
    Then I should get the following documents:
      | text           | stringid   | tags      |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |
