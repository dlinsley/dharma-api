require_relative './spec_helper'

describe Dharmaseed do
  describe '.scrape_page' do
    before :all do
      doc = open(File.dirname(__FILE__) + '/fixtures/page_sample_with_multitalk.html')
      Dharmaseed.new.scrape_page(doc)
    end

    it 'should find and store the 11 talks in the sample' do
      expect(Talk.all.count).to eq 11
    end

    # Even though there are more speakers in the sample the above Dharmaseed.open_speaker_doc()
    # patch always returns the same speaker sample
    it 'should find and store the 8 speakers from the samples' do
      expect(Speaker.all.count).to eq 8
    end

    after :all do
      Talk.destroy_all
      Speaker.destroy_all
    end
  end

  describe '.parse_talk' do
    before :all do
      @doc = open(File.dirname(__FILE__) + '/fixtures/page_sample_with_multitalk.html')
      @spider = Dharmaseed.new(recrawl: true)
    end

    it 'should find and store a talk from a given talklist table' do
      @spider.talk_fragment = Nokogiri::HTML(@doc).css('.talklist table')[0]
      @spider.isolate_table_rows
      @spider.speaker = Speaker.create(name: 'test')
      talk = @spider.parse_talk
      expect(talk.date.to_s).to eq '2012-01-26'
      expect(talk.duration).to eq 3446
      expect(talk.permalink).to eq 'http://dharmaseed.org/teacher/222/talk/15378/20120126-Anushka_Fernandopulle-SR-love_ethics_and_leadership.mp3'
      expect(talk.title).to eq 'Love, Ethics and Leadership'
      expect(talk.venue).to eq 'Spirit Rock Meditation Center'
      expect(talk.event).to eq 'Waking Up As Leaders'
      expect(talk.description.start_with?('Spirit Rock Meditation Center')).to be true
    end
  end

  describe '.parse_speaker' do
    before :all do
      @doc = open(File.dirname(__FILE__) + '/fixtures/page_sample_with_multitalk.html')
      @spider = Dharmaseed.new
    end

    it 'should find and store the speaker from the speaker sample' do
      # Just take the first talk
      @spider.talk_fragment = Nokogiri::HTML(@doc).css('.talklist table')[0]
      @spider.isolate_table_rows
      speaker = @spider.parse_speaker
      # This is the name from the the main page, as the spider uses that name rather then the name from the speaker page.
      # And as we've hardcoded the Sayadaw's page as the remote speaker page the name and bio don't match here.
      expect(speaker.name).to eq 'Anushka Fernandopulle'
      expect(speaker.bio.start_with?('Sayadaw U Tejaniya began his Buddhist training as a young teenager')).to be true
      expect(speaker.website).to eq 'http://sayadawutejaniya.org/'
      expect(speaker.picture).to eq 'http://media.dharmaseed.org/uploads/photos/teacher_246_125_0.png'
    end
  end

  # You can skip out these slower remote test with `rspec --tag ~@depends_on_remote [specs]'
  # Test to see whether the live site has changed to the extent that we're no longer getting any talks or speakers on a crawl
  describe 'Scrapability of current live site', depends_on_remote: true do
    before :all do
      Speaker.destroy_all
      Talk.destroy_all
      doc = open(Dharmaseed::BASE_URL + '1')
      @spider = Dharmaseed.new(recrawl: true)
      # TODO: Maybe loop over the first few, it's fair enough if the occasioanl talk doesn't parse
      @spider.talk_fragment = @spider.talklist_tables(doc).first
      @spider.isolate_table_rows
      @spider.parse_talk if @spider.parse_speaker
    end

    it 'should find at least 1 talk from the first crawled page' do
      expect(Talk.all.count).to be > 0
    end

    it 'should find at least 1 speaker from the first crawled page' do
      expect(Speaker.all.count).to be > 0
    end
  end
end
