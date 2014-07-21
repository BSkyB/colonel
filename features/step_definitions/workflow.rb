When(/^I promote "(.*?)" to "(.*?)"$/) do |from, to|
  author = {name: 'Test', email: 'test@example.com'}
  @new_revision = @document.promote!(from, to, author, 'Promoted')
end

Then(/^the "(.*?)" revision should have content:$/) do |state, table|
  state_rev = @document.revisions[state]

  expect(state_rev).to be_a(Revision)

  table.hashes.first.each do |key, value|
    expect(state_rev.content.get(key)).to eq(value)
  end
end

When(/^I save the changes to "(.*?)"$/) do |state|
  @document.save_in!(state, {name: 'Test', email: 'test@example.com'})
end
