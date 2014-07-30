Feature: Raw results
  When a query returns a lot of results, loading all of them as full `Colonel::Document`
  is not very performant, as it means opening a git repository for each and loading the
  content. That translates to disk (or other storage) access, which is slow.

  Usually you only care about the content itself though, which is available in the
  elasticsearch results already. If that's what you want, you can ask for raw search
  results, which will only return the content

  ```ruby
  results = Document.list

  results.raw do |result|
    result # Content instance
  end
  ```

  Scenario: Getting raw results
    Given the following documents:
      | text            | comment |
      | First document  | cool    |
      | Second document | strange |
      | Third document  | nope    |
    When I search for "first nope"
    Then I should get the following raw documents:
      | text           | comment |
      | First document | cool    |
      | Third document | nope    |
