Feature: Document history
  Document has a `history` method iterating through all the revisions
  on the document, following the previous links.

  ```ruby
  document = Document.open("xyz")

  document.history do |revision| # block form
    puts revison.message
    puts revisin.content.to_json
  end

  document.history.to_a # returns an array [Revision, Revision, Revision, ...]

  history = document.history # returns an Enumerator
  history.each do |revision|
    puts revison.message
    puts revisin.content.to_json
  end

  document.history do |revision|
  ```

  Scenario: Listing document history
    Given an existing document with revisions with content:
      | text            |
      | First revision  |
      | Second revision |
      | Third revision  |
      | Fourth revision |
    When I get the document history
    Then I should be able to iterate through revisions with content:
      | text            |
      | Fourth revision |
      | Third revision  |
      | Second revision |
      | First revision  |
