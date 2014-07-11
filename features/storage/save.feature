Feature: Save & Load
  Content items are persistent. You save the current state
  of the document with a "save!" call.

  A save is tagged with an author and a message for auditing.

  ```ruby
  item = ContentItem.new({name: {first: 'John', last: 'Doe'}})
  item.save!({name: 'Bob The Author', email: 'bob@example.com'}, 'Created a file')

  item_id = item.id
  ```

  Saved item gets an alphanumeric content id you can use to retrieve it.

  ```ruby
  item = ContentItem.open(item_id)

  item.name.first # => 'John'

  item.name.last # => 'Doe'
  ```

  Scenario: Save a content item and get its id

  Scenario: Find and open a content item by id
