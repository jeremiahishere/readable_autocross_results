require "pdf-reader"
require "pry"
require "csv"

class Runner
  def initialize(raw_filename, parsed_filename)
    @raw_filename = raw_filename
    @parsed_filename = parsed_filename
  end

  def run
    reader = PDF::Reader.new(@raw_filename)

    formatted_lines = []
    first_page = true
    reader.pages.each do |page|
      formatted_lines += page_reader(page.text, first_page)

      first_page = false
    end

    output_str = CSV.generate(headers: columns) do |csv|
      # header
      csv << columns

      formatted_lines.each do |line|
        csv << line
      end
    end

    File.write(@parsed_filename, output_str)
  end

  def columns
    [:rank, :class_pos, :class, :car_number, :driver, :vehicle, :tire, :time, :correction_factor, :corrected_time, :diff_from_first, :corrected_diff_from_first, :rtp_points]
  end

  def page_reader(text, first_page)
    lines = text.split("\n").reject { |l| l.empty? }
    # remove the first three lines because the columns are setup in a weird way for the pdf reader
    lines = lines[3..-1]  if first_page


    formatted_lines = lines.collect do |line|
      arr_line = format_line(line)

      # for now, discard the line if it doesn't match
      if columns.size == arr_line.size
        hash_line = Hash[columns.zip(arr_line)]

        hash_line
      else
        puts arr_line.inspect
        nil
      end
    end

    formatted_lines.compact
  end

  # @param [String] line
  # @returns [Array] line
  def format_line(line)
    # Replace "Lastname 1999 Mazda Miata" with "Lastname<tab>1999 Mazda Miata
    # This generally happens once per page to the person with the longest last name
    line = line.gsub(/(\w+) (\d\d\d\d)/, "\\1\t\\2")
    line = line.gsub(/(\w+) No\s*Time/, "\\1\tNo Time")
    line = line.gsub(/Canekeratne BMW/, "Canekeratne\tBMW") # no model year
    line = line.gsub(/Dirkschneider Impreza/, "Dirkschneider\tImpreza") # no model year
    line = line.gsub(/IV1972/, "IV\t1972") # missing space
    line = line.gsub(/Hesskamp Margay/, "Hesskamp\tMargay") # nomodel year (junior kart)
    line = line.gsub(/Steve Hudson\t1990\s+Mazda Miata/, "Steve Hudson\t1990 Mazda Miata") # this data was bad in the raw file
    line = line.gsub(/Datsun\t(\d\d\d\d)/, "Datsun \\1") # Datsun model numbers look like years

    # Replace "BFGoodrich 99.234" with "BFGoodrich<tab>99.234"
    # This happens on a bunch of lines depending on which tire name is longest
    line = line.gsub(/(#{tire_manufacturers}) (\d\d)/, "\\1\t\\2")
    # "2003 Chevy Corvette Z06 BFGoodrich"
    # Happens on lines with the longest car name
    line = line.gsub(/([\w\d]+) (#{tire_manufacturers})/, "\\1\t\\2")
    line = line.gsub(/([\w\d]+)(BFGoodrich)/, "\\1\t\\2") # missing space
    line = line.gsub(/(Maky Ka|Margay|Star) MG/, "\\1\tMG") # junior carts get a special case because putting MG into the tire manufacturers causes problems
    
    # the pdf reader reads these values as space separated instead of tab separated so this mess
    # converts to tabs and splits properly.  May need to add some validation later to crash/log if
    # a line gets through without the columns.size number of cells
    #
    # Note that (  )+ is a weird way to match 2 spaces but it works
    line = line.gsub(/(  )+/, "\t").split("\t").map(&:strip)

    line

  end

  def tire_manufacturers
    # note that MG is a tire manufacturer but it causes parsing problems because it is also a car
    # make
    %w(BFGoodrich Bridgestone Multi Hoosier Continental Avon).join("|")
  end
end

class ResultsParser
  def initialize(raw_dir, parsed_dir)
    @raw_dir = raw_dir
    @parsed_dir = parsed_dir
  end

  def run
    Dir.glob("#{@raw_dir}/*.pdf") do |raw_filename|
      parsed_filename = "#{@parsed_dir}/#{File.basename(raw_filename)}"

      puts "Started processing #{raw_filename}"
      runner = Runner.new(raw_filename, parsed_filename)

      runner.run
      puts "Finished processing #{parsed_filename}"
    end
  end
end

raw_dirname = File.join(File.dirname(__FILE__), "raw/2019/champ_tour_results")
parsed_dirname = File.join(File.dirname(__FILE__), "parsed/2019/champ_tour_results")
parser = ResultsParser.new(raw_dirname, parsed_dirname)
parser.run
