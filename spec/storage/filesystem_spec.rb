require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsHttpLab::Storage::Filesystem do
  let(:root) { Pathname.new(Dir.mktmpdir("rhl-")) }
  let(:fs)   { described_class.new(root: root) }

  after { FileUtils.rm_rf(root) }

  describe "#ensure_root!" do
    it "creates the root and a default bruno.json" do
      fs.ensure_root!
      expect((root + "bruno.json")).to be_file
      manifest = JSON.parse((root + "bruno.json").read)
      expect(manifest["type"]).to eq("collection")
    end
  end

  describe "#write_bru / #read_bru" do
    it "writes and reads back a request" do
      fs.ensure_root!
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "Ping"], ["type", "http"], ["seq", "1"]]),
        RailsHttpLab::Bruno::Block.new(name: "get",  mode: :kv, pairs: [["url", "https://example.com"], ["body", "none"], ["auth", "none"]])
      ])
      fs.write_bru("MyAPI/ping.bru", doc)

      reread = fs.read_bru("MyAPI/ping.bru")
      expect(reread.http_method).to eq("GET")
      expect(reread.url).to eq("https://example.com")
    end
  end

  describe "path safety" do
    it "rejects absolute paths" do
      fs.ensure_root!
      expect { fs.read_bru("/etc/passwd") }.to raise_error(RailsHttpLab::OutsideStorageError)
    end

    it "rejects path traversal" do
      fs.ensure_root!
      expect { fs.read_bru("../../etc/passwd") }.to raise_error(RailsHttpLab::OutsideStorageError)
    end
  end

  describe "#create_folder" do
    it "creates dir with folder.bru" do
      fs.ensure_root!
      fs.create_folder("Stuff")
      expect((root + "Stuff/folder.bru")).to be_file
    end
  end

  describe "#delete" do
    it "removes a file" do
      fs.ensure_root!
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "X"]])
      ])
      fs.write_bru("x.bru", doc)
      expect(fs.delete("x.bru")).to be true
      expect((root + "x.bru")).not_to exist
    end

    it "removes a directory recursively" do
      fs.ensure_root!
      fs.create_folder("Stuff")
      fs.write_bru("Stuff/x.bru", RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "X"]])
      ]))
      expect(fs.delete("Stuff")).to be true
      expect((root + "Stuff")).not_to exist
    end
  end

  describe "#rename" do
    it "moves a file to a new sibling" do
      fs.ensure_root!
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "Old"]])
      ])
      fs.write_bru("Stuff/old.bru", doc)
      fs.rename("Stuff/old.bru", "Stuff/new.bru")
      expect((root + "Stuff/new.bru")).to be_file
      expect((root + "Stuff/old.bru")).not_to exist
    end

    it "moves a directory and its contents" do
      fs.ensure_root!
      fs.create_folder("Old")
      fs.write_bru("Old/x.bru", RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "X"]])
      ]))
      fs.rename("Old", "New")
      expect((root + "New/x.bru")).to be_file
      expect((root + "Old")).not_to exist
    end

    it "refuses to overwrite an existing destination" do
      fs.ensure_root!
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "A"]])
      ])
      fs.write_bru("a.bru", doc)
      fs.write_bru("b.bru", doc)
      expect { fs.rename("a.bru", "b.bru") }.to raise_error(RailsHttpLab::Error, /destination exists/)
    end

    it "rejects paths outside the storage root" do
      fs.ensure_root!
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "A"]])
      ])
      fs.write_bru("a.bru", doc)
      expect { fs.rename("a.bru", "../escape.bru") }.to raise_error(RailsHttpLab::OutsideStorageError)
    end
  end
end
