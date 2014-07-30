Feature: Promoting to a new state
  Revisions are moved through the series of states forming your
  workflow by being promoted. A promotion creates a new revision
  in the target state, linked back to the original state and the
  previous revision in the target state.

  That extends the linear history to a full directed acyclic graph
  of revisions which can be searched.

  It's important to understand that the promotion revision cannot
  change content - it is a copy of the origin revision - yet it is
  a physical revision. Having actual revisions for each promotion
  makes listing the history of individual states much easier (or
  even possible) and simpler to follow.

  It does have other consequences though, namely the fact that
  when you promote a revision, the revision you find through the
  target state is NOT the samer revision you promoted in the original
  state. It has the same content, but a different id.

  Scenario: Promoting a revision
    Given an existing document with content:
      | text                |
      | This is just a test |
    When I promote "master" to "published"
    Then I should get a new revision with content:
      | text                |
      | This is just a test |
    And the "published" revision should have content:
      | text                |
      | This is just a test |

  Scenario: Saving over a promoted revision
    Given an existing document with content:
      | text                |
      | This is just a test |
    When I promote "master" to "published"
    And I change the content to:
      | text                      |
      | This is just another test |
    And I save the document
    Then the "published" revision should have content:
      | text                |
      | This is just a test |
    And the "master" revision should have content:
      | text                      |
      | This is just another test |

  Scenario: Saving into a different state branch
    Given an existing document with content:
      | text                |
      | This is just a test |
    When I promote "master" to "archived"
    And I change the content to:
      | text                      |
      | This is just another test |
    And I save the changes to "archived"
    Then the "master" revision should have content:
      | text                |
      | This is just a test |
    And the "archived" revision should have content:
      | text                      |
      | This is just another test |
