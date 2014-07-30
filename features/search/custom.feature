Feature: custom type name and mappings
  You can define your own document types and customize
  the attributes mapping fro elasticsearch. That will allow
  you to do different kinds of matches against the fields
  stored in your Document.

  You define document types by creating a new one

  ```
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
  ```

  Background:
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
    And documents of class "Article" with content:
      | text           | stringid   | tags      |
      | First article  | first_one  | red blue  |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |

  Scenario: Search respects the type
    When I search for "second_one"
    Then I should not get any results

  Scenario: Search for an exact match
    When I search "Article" for 'stringid:"second_one"'
    Then I should get the following documents:
      | text           | stringid   | tags      |
      | Second article | second_one | red green |

  Scenario: Search for whitespace match
    When I search "Article" for 'green pink blu one'
    Then I should get the following documents:
      | text           | stringid   | tags      |
      | Second article | second_one | red green |
      | Third article  | third_one  | pink blue |
