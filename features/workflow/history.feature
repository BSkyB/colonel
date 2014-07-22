Feature: Document history in a particular state
  The same way it's possible to list the history of the master state
  to get all the draft revisions, you can list the history of any given
  state to see everything that was ever promoted to it.

  ```ruby
  document.history('published') do |revision|
    puts revision.message
    puts revision.type
    puts revision.state # becomes useful when mixing histories of two states

    puts revision.content.to_json
  end
  ```

  Note that the `state` attribute is unknown when you lookup the revision
  using `RevisionCollection#[]` (e.g `document.revisions[sha1]`).

  Scenario: Listing a specific state
    Given an document with the following history:
      | change  | message         |
      | save    | first revision  |
      | publish | first publish   |
      | save    | second revision |
      | save    | third revision  |
      | publish | second publish  |
      | save    | fourth revision |
      | hotfix  | fixed published |
    When I list the "published" history
    Then I should get the following revisions:
      | state     | type      | message         |
      | published | save      | fixed published |
      | published | promotion | second publish  |
      | published | promotion | first publish   |
    When I list the "master" history
    Then I should get the following revisions:
      | state  | type   | message         |
      | master | save   | fourth revision |
      | master | save   | third revision  |
      | master | save   | second revision |
      | master | orphan | first revision  |
