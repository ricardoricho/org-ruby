require 'spec_helper'

describe Orgmode::Headline do

  it "should find simple headline text" do
    h = Orgmode::Headline.new "*** sample"
    expect(h.headline_text).to eql("sample")
  end

  it "should understand tags" do
    h = Orgmode::Headline.new "*** sample :tag:tag2:\n"
    expect(h.headline_text).to eql("sample")
    expect(h.tags.count).to eq(2)
    expect(h.tags[0]).to eql("tag")
    expect(h.tags[1]).to eql("tag2")
  end

  it "should understand a single tag" do
    h = Orgmode::Headline.new "*** sample :tag:\n"
    expect(h.headline_text).to eql("sample")
    expect(h.tags.count).to eq(1)
    expect(h.tags[0]).to eql("tag")
  end

  it "should understand keywords" do
    h = Orgmode::Headline.new "*** TODO Feed cat  :home:"
    expect(h.headline_text).to eql("Feed cat")
    expect(h.keyword).to eql("TODO")
  end

  it "should recognize headlines marked as COMMENT" do
    h = Orgmode::Headline.new "* COMMENT This headline is a comment"
    expect(h.comment_headline?).to_not be_nil
  end
end
