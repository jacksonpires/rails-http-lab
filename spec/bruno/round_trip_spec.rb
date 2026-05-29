require "spec_helper"

RSpec.describe "Bruno round-trip" do
  fixtures = Dir.glob(File.join(BRUNO_CORPUS, "**", "*.bru")).sort

  if fixtures.empty?
    it "skips when no corpus is present" do
      skip "No .bru fixtures found at #{BRUNO_CORPUS}. The corpus is gitignored; " \
           "place a collection of Bruno .bru files there to exercise round-trip stability."
    end
  else
    it "discovered fixture files" do
      expect(fixtures.size).to be > 100
    end

    fixtures.each do |path|
      rel = path.sub(BRUNO_CORPUS + "/", "")
      it "round-trips #{rel}" do
        original  = File.read(path)
        doc       = RailsHttpLab::Bruno.parse(original)
        reemitted = RailsHttpLab::Bruno.dump(doc)
        expect(reemitted).to eq(original), -> {
          diff_summary(original, reemitted)
        }
      end
    end
  end

  def diff_summary(a, b)
    a_lines = a.split("\n", -1)
    b_lines = b.split("\n", -1)
    diffs = []
    [a_lines.length, b_lines.length].max.times do |i|
      if a_lines[i] != b_lines[i]
        diffs << "  line #{i + 1}: original=#{a_lines[i].inspect}  reemitted=#{b_lines[i].inspect}"
        break if diffs.length >= 5
      end
    end
    "Round-trip diverged:\n#{diffs.join("\n")}"
  end
end
