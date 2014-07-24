Feature: custom type name and mappings

  Background:
    Given the following class:
      """
      class Article < Colonel::Document
        type_name 'article'

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

