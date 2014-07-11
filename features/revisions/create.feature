Feature: Create a new revision of a content item
  All content in the Colonel is versioned with every save creating a new revision.
  Revisions have a unique id (git commit id) derived from their content, author
  and history.

  Every `save!` call on a document creates a *new* revision based on the current
  latest revision.

  ```ruby
  author = {name: 'Bob The Author', email: 'bob@example.com'}
  item = ContentItem.new({name: {first: 'John', last: 'Doe'}})
  first_revision = item.save!(author, 'Created a person')

  item.name.first = 'Bob'
  second_revision = item.save!(author, 'Changed name to Bob')

  second_revision.previous # => first_revision
  ```

  Revision has the following attributes:

  *  id         - unique revision id
  *  previous   - previous revision
  *  author     - author of the revision (hash with `:name` and `:email`)
  *  message    - optional message passed in by the revision author
  *  created_at - time when the revision was created

  Scenario: Updating a content item
    Given an existing document with content:
      | text                |
      | This is just a test |
    When I change the content to:
      | text                      |
      | This is just another test |
    And I save the document
    Then I should get a new revision with content:
      | text                      |
      | This is just another test |
    And the previous revision should have content:
      | text                |
      | This is just a test |
