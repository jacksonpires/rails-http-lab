require "spec_helper"

RSpec.describe RailsHttpLab::Storage::Tree do
  corpus_present = Dir.glob(File.join(BRUNO_CORPUS, "**", "*.bru")).any?

  context "with the Bruno corpus fixture" do
    before { skip "no corpus at #{BRUNO_CORPUS} (gitignored — clone a Bruno collection there to run these)" unless corpus_present }

    it "builds a tree from the Bruno corpus fixture" do
      tree = described_class.new(root: BRUNO_CORPUS).build
      expect(tree[:type]).to eq("collection")
      expect(tree[:name]).to eq("All APIs")
      expect(tree[:children]).not_to be_empty

      folder_names = tree[:children].select { |c| c[:type] == "folder" }.map { |c| c[:name] }
      expect(folder_names).to include("Airtable", "Bernhoeft")

      airtable = tree[:children].find { |c| c[:name] == "Airtable" }
      expect(airtable[:children].first[:type]).to eq("request")
      expect(airtable[:children].first[:method]).to eq("GET")
    end

    it "lists environments separately" do
      tree = described_class.new(root: BRUNO_CORPUS).build
      env_names = tree[:environments].map { |e| e[:name] }
      expect(env_names).to include("Local")
    end

    it "sorts top-level collections alphabetically (case-insensitive)" do
      tree = described_class.new(root: BRUNO_CORPUS).build
      top_names = tree[:children].map { |c| c[:name] }
      expect(top_names).to eq(top_names.sort_by(&:downcase))
    end
  end

  it "respects seq ordering inside a nested folder" do
    Dir.mktmpdir do |root|
      fs = RailsHttpLab::Storage::Filesystem.new(root: root)
      fs.ensure_root!
      fs.create_folder("Coll")

      [["b.bru", "B", "1"], ["a.bru", "A", "2"]].each do |file, name, seq|
        doc = RailsHttpLab::Bruno::Document.new(blocks: [
          RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", name], ["seq", seq]]),
          RailsHttpLab::Bruno::Block.new(name: "get",  mode: :kv, pairs: [["url", "https://example.com"], ["body", "none"], ["auth", "none"]])
        ])
        fs.write_bru("Coll/#{file}", doc)
      end

      tree = described_class.new(root: root).build
      coll = tree[:children].find { |c| c[:name] == "Coll" }
      # B (seq 1) before A (seq 2), since nested entries still follow seq.
      names = coll[:children].reject { |c| c[:name].nil? }.map { |c| c[:name] }
      expect(names).to eq(["B", "A"])
    end
  end
end
