# AUDIODHARMA.ORG
# A very large collection of dharma talks, given at the Insight Meditation Center in California.
# We make use of the fact that Audidharma paginates all its talks on a consistent URL.
# Audidharma also has a rich archive of teachers; with bios, pics and website links, these
# pages are kept on seperate pages which we can easily parse.

# May all beings be from suffering

class Audiodharma < Spider
  BASE_DOMAIN = 'http://audiodharma.org'.freeze
  BASE_URL = BASE_DOMAIN + '/talks/?page='
  LICENSE = 'http://creativecommons.org/licenses/by-nc-nd/3.0/'.freeze

  def open_multitalk_doc(url)
    open(url)
  end

  # Parse a speaker's page for relevant info
  def scrape_speaker(doc, speaker_name)
    table = doc.at_css('.teacher_bio_table')

    unless table
      log.warn "DOM elements for speaker not found :: #{speaker_name}"
      return false
    end

    {
      name: speaker_name, # Use the name from the original talk page in case there's nothing else
      bio: clean_long_text(table.tolerant_css('.teacher_bio')),
      website: table.parent.tolerant_css('div + table + div a', 'href'),
      picture: table.tolerant_css('.teacher_photo img', 'src')
    }
  end

  # There's an edge case where a talk will contain multiple files or parts
  def check_multitalk_edge_case
    @multiple_talk = false
    # This identifies the fragment containing the links to the actual mp3s
    fifth_td = @talk_fragment.css('td + td + td + td a').first
    !fifth_td && (return false)
    if fifth_td.text == 'View Series'
      @multiple_talk = fifth_td.attr('href')
      d "This 'talk' is a reference to a series of talks (#{@multiple_talk})"
    end
    @multiple_talk
  end

  # Find the speaker for the current talk.
  # The full speaker details are kept on a seperate page which we need to fetch.
  # But we keep a track of which speakers we've already fetched on this crawl so we only
  # scrape them once.
  def parse_speaker
    # No need to continue if we can't even find a speaker name
    speaker_name = @talk_fragment.tolerant_css('.talk_teacher') || ''
    if speaker_name.empty?
      log.warn "Couldn't find the speaker in :: " + @talk_fragment
      return false
    end

    # Only parse this speaker if we haven't done so on this crawl already
    if @parsed_speakers.include? speaker_name
      d "Speaker already parsed (#{speaker_name})"
      @speaker = Speaker.find_by(name: speaker_name)
      return @speaker
    end

    d 'Unparsed speaker :: ' + speaker_name
    href = @talk_fragment.tolerant_css('.talk_teacher a', 'href')
    doc = Nokogiri::HTML(open_speaker_doc(BASE_DOMAIN + href))
    unless speaker_scraped = scrape_speaker(doc, speaker_name)
      log.warn "Couldn't parse the speaker target page :: " + href
      return false
    end

    # See if there's a record of the speaker in the db and create one if there isn't
    @speaker = Speaker.find_or_initialize_by(name: speaker_name) || Speaker.new
    @speaker.update_attributes!(speaker_scraped)
    @parsed_speakers << speaker_name # Make a note of this so we don't do it again on this crawl

    @speaker
  end

  def parse_talk
    # There has to be a permalink to a talk
    unless permalink = @talk_fragment.tolerant_css('.talk_links a', 'href')
      log.warn "Couldn't get talk's permalink"
      return false
    end

    # Some talks are external links and some are relative internal ones
    permalink = BASE_DOMAIN + permalink unless permalink.include? 'http://'

    talk = Talk.find_or_initialize_by(permalink: permalink)

    # If the talk exists and we're not doing a recrawl then we end it here.
    if talk.persisted? && !@recrawl
      @finished = true
      d 'Found existing talk, ending crawl.'
      return false
    end

    @talk_scraped = {
      title: @talk_fragment.tolerant_css('.talk_title'),
      speaker_id: @speaker._id,
      permalink: permalink,
      duration: colon_time_to_seconds(@talk_fragment.tolerant_css('.talk_length')),
      date: @talk_fragment.tolerant_css('.talk_date'),
      description: clean_long_text(@talk_fragment.tolerant_css('.the_talk_description', 'title')),
      venue: 'Insight Meditation Centre, Redwood, California',
      event: nil, # TODO: Detect when a talk is part of a series
      source: BASE_DOMAIN,
      license: LICENSE
    }

    talk.update_attributes!(@talk_scraped)
    d 'Talk :: ' + talk.title

    talk
  end

  def talks(doc)
    talks = Nokogiri::HTML(doc).css('.talklist tr')
    # Remove the first row if it's just table headers
    talks.shift if talks.first.tolerant_css('th')
    talks
  end

  # Take a page and extract data from it
  def scrape_page(doc)
    # A page typically contains 50 or so talks
    talks(doc).each do |talk_fragment|
      d '---------------------------------------'

      @talk_fragment = talk_fragment

      # First check if this is just a link to a series of talks
      if series_url = check_multitalk_edge_case
        d 'Entering Series page'
        scrape_page(open_multitalk_doc(BASE_DOMAIN + series_url))
        d 'Exiting Series page'
        next
      end

      parse_talk if parse_speaker
      break if @finished
    end
  end

  # Loop over all of audiodharma's pages
  def run
    d "Crawling AUDIODHARMA, starting on page #{@page}"
    log.info 'Crawl initiated on ' + Time.now.inspect
    while
      @page += 1
      full_link = BASE_URL + @page.to_s
      d "\n#######################################"
      d 'Link to current page :: ' + full_link
      doc = open(full_link).read
      doc =~ /No matching talks are available/ && break # Fin
      scrape_page(doc)
      break if @finished
    end
  end
end
