$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'scraper'
require 'planning_authority_results'

class GoldCoastScraper < Scraper
  @planning_authority_name = "Gold Coast City Council"
  @planning_authority_short_name = "Gold Coast"

  # Downloads html table and returns it, ready for the data to be extracted from it
  def raw_table(date, url)
    page = agent.get(url)
    
    # Click the Ok button on the form
    form = page.forms.first
    form.submit(form.button_with(:name => /btnOk/))

    # Get the page again
    page = agent.get(url)

    search_form = page.forms.first
    
    search_form[search_form.field_with(:name => /drDates:txtDay1/).name] = date.day
    search_form[search_form.field_with(:name => /drDates:txtMonth1/).name] = date.month
    search_form[search_form.field_with(:name => /drDates:txtYear1/).name] = date.year
    search_form[search_form.field_with(:name => /drDates:txtDay2/).name] = date.day
    search_form[search_form.field_with(:name => /drDates:txtMonth2/).name] = date.month
    search_form[search_form.field_with(:name => /drDates:txtYear2/).name] = date.year

    search_form.submit(search_form.button_with(:name => /btnSearch/)).search('span#_ctl3_lblData > table')
    # TODO: Need to handle what happens when the results span multiple pages. Can this happen?
  end
  
  def applications(date)
    results = PlanningAuthorityResults.new(:name => self.class.planning_authority_name, :short_name => self.class.planning_authority_short_name)
    table = raw_table(date, "http://pdonline.goldcoast.qld.gov.au/masterview/modules/applicationmaster/default.aspx?page=search")
    
    # Skip first row of the table
    table.search('tr')[1..-1].each do |row|
      values = row.search('td')
      
      da = DevelopmentApplication.new(
        :application_id => values[1].inner_html.strip,
        :description => values[3].inner_text.split("\n")[3..-1].join("\n").strip,
        :address => values[3].inner_text.split("\n")[1].strip,
        :info_url => agent.page.uri + URI.parse(values[0].at('a').attributes['href']),
        :date_received => values[2].inner_html)
      email_body = <<-EOF
Thank you for your enquiry.

Please complete the following details and someone will get back to you as soon as possible.  Before submitting you email request you may want to check out the Frequently Asked Questions (FAQ's) Located at http://pdonline.goldcoast.qld.gov.au/masterview/documents/FREQUENTLY_ASKED_QUESTIONS_PD_ONLINE.pdf

Name: 

Contact Email Address: 

Business Hours Contact Phone Number: 

Your query regarding this Application: 

      EOF
      email_subject = "Development Application Enquiry: #{da.application_id}"
      da.comment_url = "mailto:gcccmail@goldcoast.qld.gov.au?subject=#{URI.escape(email_subject)}&Body=#{URI.escape(email_body)}"
      results << da
    end
    results
  end
end