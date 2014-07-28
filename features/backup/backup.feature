Feature: Backup and restore
  To backup content in the colonel, you first have to get the list of
  all content using the `DocumentIndex` and then the `Serializer` to
  dump it.

  ```ruby
  index = DocumentIndex.new(Colonel.config.storage_path)
  docs = index.documents.map { |doc| Document.open(doc[:name]) }

  File.open(my_file, "w") do |f|
    Serializer.dump(docs, f)
  end
  ```

  To restore the documents use the `restore` method, supplying a type map
  to

  ```ruby
  File.open(my_file, "r") do |f|
    Serializer.load(f, {'my_type' => MyClass})
  end
  ```

  Note that to be able to search again, you need to reindex the content
  after loading.

  Scenario: Full cycle backup and restore
    Given the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
    When I dump documents into a file named "test-dump.col"
    And I remove all files in the storage
    And I restore documents from a file named "test-dump.col"
    And I list all documents in the document index
    Then I should get the following documents:
      | text            |
      | First document  |
      | Second document |
      | Third document  |
