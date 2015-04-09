require 'spec_helper'

describe Indexer do
  describe "#document_commands" do
    let :time do
      Time.now
    end

    let :type do
      Colonel::DocumentType.new('test-type')
    end

    describe "document with single save" do
      let :repository do
        refs = [
          double(:reference, name: 'refs/heads/master'),
          double(:reference, name: 'refs/tags/root')
        ]
        double(:repository, references: refs)
      end

      let :revisions do
        {
          'master' => Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil)
        }
      end

      let :document do
        type.new({}).tap do |it|
          allow(it).to receive(:repository).and_return(repository)
          allow(it).to receive(:revisions).and_return(revisions)
        end
      end

      it "produces correct index commands" do
        cmds = Indexer.document_commands(document)

        save = cmds.find {|it| it[:index][:_type] == 'test-type'}
        save_rev = cmds.find {|it| it[:index][:_type] == 'test-type_rev'}

        expect(save).not_to be_nil
        expect(save_rev).not_to be_nil
      end
    end

    describe "document with multiple saves" do
      let :repository do
        refs = [
          double(:reference, name: 'refs/heads/master'),
          double(:reference, name: 'refs/tags/root')
        ]
        double(:repository, references: refs)
      end

      let :revisions do
        first_save = Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil)

        {
          'master' => Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, first_save)
        }
      end

      let :document do
        type.new({}).tap do |it|
          allow(it).to receive(:repository).and_return(repository)
          allow(it).to receive(:revisions).and_return(revisions)
        end
      end

      it "produces correct index commands" do
        cmds = Indexer.document_commands(document)

        saves = cmds.select { |it| it[:index][:_type] == 'test-type' }
        revs = cmds.select { |it| it[:index][:_type] == 'test-type_rev' }

        expect(saves.count).to eq(1)
        expect(revs.count).to eq(2)
      end
    end

    describe "document with a save and a publish" do
      let :repository do
        refs = [
          double(:reference, name: 'refs/heads/master'),
          double(:reference, name: 'refs/heads/published'),
          double(:reference, name: 'refs/tags/root')
        ]
        double(:repository, references: refs)
      end

      let :revisions do
        first_save = Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil)

        {
          'master' => first_save,
          'published' => Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil, first_save)
        }
      end

      let :document do
        type.new({}).tap do |it|
          allow(it).to receive(:repository).and_return(repository)
          allow(it).to receive(:revisions).and_return(revisions)
        end
      end

      it "produces correct index commands" do
        cmds = Indexer.document_commands(document)

        saves = cmds.select { |it| it[:index][:_type] == 'test-type' && it[:index][:_id] =~ /-master$/ }
        publishes = cmds.select { |it| it[:index][:_type] == 'test-type' && it[:index][:_id] =~ /-published$/ }
        revs = cmds.select { |it| it[:index][:_type] == 'test-type_rev' }

        expect(saves.count).to eq(1)
        expect(publishes.count).to eq(1)
        expect(revs.count).to eq(2)
      end
    end

    describe "document with custom scopes" do
      let :type do
        Colonel::DocumentType.new('test-type') do
          scope 'test-scope', on: [:promotion], to: ['published']
        end
      end

      let :repository do
        refs = [
          double(:reference, name: 'refs/heads/master'),
          double(:reference, name: 'refs/heads/published'),
          double(:reference, name: 'refs/tags/root')
        ]
        double(:repository, references: refs)
      end

      let :revisions do
        first_save = Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil)

        {
          'master' => first_save,
          'published' => Colonel::Revision.new(:doc, Colonel::Content.new({}), :author, "", time, nil, first_save)
        }
      end

      let :document do
        type.new({}).tap do |it|
          allow(it).to receive(:repository).and_return(repository)
          allow(it).to receive(:revisions).and_return(revisions)
        end
      end

      it "produces correct index commands" do
        cmds = Indexer.document_commands(document)

        saves = cmds.select { |it| it[:index][:_type] == 'test-type' && it[:index][:_id] =~ /-master$/ }
        publishes = cmds.select { |it| it[:index][:_type] == 'test-type' && it[:index][:_id] =~ /-published$/ }
        revs = cmds.select { |it| it[:index][:_type] == 'test-type_rev' }
        custom = cmds.select { |it| it[:index][:_type] == 'test-type_test-scope' }

        expect(saves.count).to eq(1)
        expect(publishes.count).to eq(1)
        expect(custom.count).to eq(1)
        expect(revs.count).to eq(2)
      end
    end
  end
end
