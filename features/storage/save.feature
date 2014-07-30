Feature: Save & Load
  Documents are persistent. You save the current state
  of the document with a "save!" call.

  A save is tagged with an author and a message for auditing.

  ```ruby
  doc = Document.new({name: {first: 'John', last: 'Doe'}})
  doc.save!({name: 'Bob The Author', email: 'bob@example.com'}, 'Created a file')

  doc_id = doc.id
  ```

  Saved document gets an alphanumeric id you can use to retrieve it.

  ```ruby
  doc = Document.open(doc_id)

  doc.content.name.first # => 'John'

  doc.content.name.last # => 'Doe'
  ```

  Scenario: Save a document and get its id
    When I create a document
    And I save it as "John Doe" with email "john@example.com"
    Then the document should have an id I can use later

  Scenario: Find and open a document by id
    Given an existing document stored as "test-id" with content:
      | name | type |
      | Test | text |
    When I open a document using stored id "test-id"
    Then I should get content:
      | name | type |
      | Test | text |
