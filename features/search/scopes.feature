Feature: Custom search scopes
  Custom scopes are a way of combining search results for documents across multiple
  states. This deserves some more detailed discussion:

  As long as you're searching for documents in a single state, you don't need scopes,
  but imagine the following workflow:

  ```
  master --[publish]-> published
         \-[archive]-> archived
  ```

  that is, you have published documents, but you can also archive documents, promoting
  them from master. your goal is to remove documents promoted to archive from searches
  across the board (unless specifically looking for archived).

  Since the promotion to archived happens *after* promoting an item to published,
  possibly to a different revision, you won't find any archived results by filtering
  down to published state. You could do two searches, one for published, one for archived,
  and then perform a set subtraction. But how can you tell which archive happened after a
  publish and which happened before (assuming an ability to restore archived documents)?

  What you need is a search "superstate" that tracks changes to both published and archived
  states - a scope. You can then search the scope, filter down by state and you get
  precisely the documents that were published, but not later archived.

  You can define a scope to index a specific type of change creating a revision in a certain
  state

  ```ruby
  class MyDoc < Colonel::Document
    scope 'visible', :on => 'promotion', :to => ['published', 'archived']
  end
  ```

  Background:
    Given the following class:
      """
      class CustomArticle < Colonel::Document
        type_name 'article'

        scope 'visible', on: 'promotion', to: ['published', 'archived']
      end
      """
    And an "CustomArticle" with text "First article" and the following history:
      | change  | message        |
      | save    | first revision |
      | publish | first publish  |
      | archive | archive        |
    And an "CustomArticle" with text "Second article" and the following history:
      | change  | message        |
      | save    | first revision |
      | archive | archive        |
    And an "CustomArticle" with text "Third article" and the following history:
      | change  | message        |
      | save    | first revision |
      | publish | first publish  |
    And an "CustomArticle" with text "Fourth article" and the following history:
      | change | message        |
      | save   | first revision |

  Scenario: Search for everything in the two states
    When I search "CustomArticle" for "*" with scope "visible"
    Then I should get the following documents:
      | text           |
      | First article  |
      | Second article |
      | Third article  |

  Scenario: Search for published
    When I search "CustomArticle" for "state:published" with scope "visible"
    Then I should get the following documents:
      | text          |
      | Third article |

  Scenario: Search for archived
    When I search "CustomArticle" for "state:archived" with scope "visible"
    Then I should get the following documents:
      | text           |
      | First article  |
      | Second article |





