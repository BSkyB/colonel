Feature: Inspect document promotions
  Because promotions create explicit revisions, for some
  operations it is necessary to find out whether a revision
  was promoted to a certain state.

  Deciding that means not only finding direct promotions
  but also transitive ones (e.g. revision was promoted to 'published'
  if it was promoted from 'master' to 'preview' and the 'preview' revision
  was then romoted to 'published').

  As an example, take a simple workflow from 'master' to 'published'. You
  can ask the following question: "Was this particular revision published?"

  ```ruby
  document = Document.open(the_id)
  revision = document.revisions[some_revision_id]

  revision.has_been_promoted?('published')
  ```

  `has_been_promoted?` returns true if there is a 'published' revision with
  `revision` as it's origin.

  In the scenario below, we use a simple workflow of

  ```
  master --publish--> published --retire--> retired
  ```

  with an additional `hotfix` action which saves changes into published
  directly

  Scenario: Checking whether a revision has been promoted
    Given an document with the following history:
      | change  | message               |
      | save    | first revision        |
      | publish | first publish         |
      | save    | second revision       |
      | retire  | retire first revision |
      | save    | third revision        |
      | publish | second publish        |
      | save    | fourth revision       |
      | hotfix  | fixed published       |
    When I list the "master" history
    Then I should get the following results of checking promotion:
      | message         | published | retired |
      | fourth revision | false     | false   |
      | third revision  | true      | false   |
      | second revision | false     | false   |
      | first revision  | true      | true    |
