Given(/^the following documents:$/) do |table|
  table.hashes.each do |content|
    document = Document.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

Given(/^a document with the following content revisions:$/) do |table|
  document = Document.new(nil)

  table.hashes.each do |content|
    document.content = content
    document.save!({name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

Given(/^the following documents promoted to "(.*?)":$/) do |status, table|
  table.hashes.each do |content|
    document = Document.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
    document.promote!('master', status, {name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

Given(/^the following class:$/) do |string|
  eval(string)
end

Given(/^documents of class "(.*?)" with content:$/) do |klass, table|
  klass = Object.const_get(klass)
  ElasticsearchProvider.initialize!(klass)

  table.hashes.each do |content|
    document = klass.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

Given(/^an "(.*?)" with text "(.*?)" and the following history:$/) do |klass, text, table|
  klass = Object.const_get(klass)
  ElasticsearchProvider.initialize!(klass)

  @document = klass.new(text: text)

  table.hashes.each do |revision|
    case revision["change"]
    when "save"
      @document.save!({name: 'Test', email: 'test@example.com'}, revision['message'])
    when "publish"
      @document.promote!('master', 'published', {name: 'Test', email: 'test@example.com'}, revision['message'])
    when "archive"
      @document.promote!('master', 'archived', {name: 'Test', email: 'test@example.com'}, revision['message'])
    end
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

When(/^I list all documents$/) do
  @documents = Document.list
end

When(/^I list all "(.*?)" documents$/) do |arg1|
  @documents = Document.list(state: 'published')
end

When(/^I list "(.*?)" documents starting from "(.*?)" sorted by "(.*?)"$/) do |size, from, sort|
  @documents = Document.list(sort: sort, from: from.to_i, size: size.to_i)
end

When(/^I search for "(.*?)"$/) do |query|
  @documents = Document.search(query)
end

When(/^I search in history for "(.*?)"$/) do |query|
  @documents = Document.search(query, history: true)
end

When(/^I search with query:$/) do |string|
  query = JSON.parse(string)

  @documents = Document.search(query)
end

When(/^I search "(.*?)" for '(.*?)'$/) do |klass, query|
  klass = Object.const_get(klass)
  @documents = klass.search(query)
end

When(/^I search "(.*?)" for "(.*?)" with scope "(.*?)"$/) do |klass, query, scope|
  klass = Object.const_get(klass)
  @documents = klass.search(query, scope: scope)
end

Then(/^I should get the following documents:$/) do |table|
  docs = @documents.map do |doc|
    doc.content
  end

  expect(@documents.count).to eq(table.hashes.length)

  table.hashes.each do |content|
    expect(docs.any? do |d|
      content.all? do |key, value|
        d.get(key) == value
      end
    end).to be(true), "Didin't find #{content.inspect} in #{docs.inspect}"
  end
end

Then(/^I should get the following documents in order:$/) do |table|
  # table is a Cucumber::Ast::Table
  docs = @documents.each

  expect(@documents.count).to eq(table.hashes.length)

  table.hashes.each do |content|
    doc = docs.next

    content.each do |key, val|
      expect(doc.content.get(key)).to eq(val), "expected: #{table.hashes.inspect},\n     got: #{@documents.map {|d| d.content.plain}.inspect}"
    end
  end
end

Then(/^I should get the following raw documents:$/) do |table|
  docs = @documents.raw.to_a

  expect(@documents.count).to eq(table.hashes.length)

  table.hashes.each do |content|
    expect(docs.any? do |d|
      content.all? do |key, value|
        d.get(key) == value
      end
    end).to be(true), "Didin't find #{content.inspect} in #{docs.inspect}"
  end
end


Then(/^I should not get any results$/) do
  expect(@documents.total).to eq(0)
end




