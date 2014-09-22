require 'pathname'

module Sudoku

  #A Specific Location on the Board
  class Location
    attr_reader :index

    def initialize(value, index)
      @index = index
      value = value.to_i
      @possible_values = []
      if value > 0
        @possible_values = [value]
      else
        @possible_values = (1..9).to_a
      end
      @sets = []
    end

    def eliminate
      changes = false
      if !is_solved?
        @sets.each do |group|
          group.each do |location|
            if location != self
              if location.is_solved?
                if @possible_values.include? location.solved_value
                  @possible_values.delete location.solved_value
                  changes = true
                end
              end
            end
          end
        end
      end
      changes
    end

    def available_guesses
      @possible_values
    end

    def remove_possibility value
      @possible_values.delete value
    end

    def is_valid?
      if @possible_values.length > 0
        if is_solved?
          @sets.each do |group|
            group.each do |location|
              if location != self
                if location.is_solved?
                  return false if location.solved_value == self.solved_value
                end
              end
            end
          end
        end
        true
      else
        false
      end
    end

    def make_guess guess
      @possible_values = [guess]
    end

    def is_solved?
      @possible_values.length == 1
    end

    def raw_value
      if is_solved?
        solved_value
      else
        0
      end
    end

    def solved_value
      raise "NOT SOLVED!" unless is_solved?
      @possible_values[0]
    end


    def difficulty_to_guess
      if is_solved?
        0
      else
        sets_of_9.reduce(1.0) do |memo, set|
          memo * difficulty_of_set(set)
        end
      end
    end

    def difficulty_of_set set
      set.reduce(1.0) do |memo, location|
        memo * (location.available_guesses.length + 1)
      end
    end

    def set_row row
      @sets[0] = row
    end

    def set_column col
      @sets[1] = col
    end

    def set_box box
      @sets[2] = box
    end

    def sets_of_9
      @sets
    end

  end

  #The State of the Board
  class Board

    attr_reader :locations

    def initialize(board_string)
      @locations = board_string.chars.each_with_index.map {
          |value, index|
        Location.new value, index
      }
      #Set up so each Location knows it's place so
      # that it can estimate it's difficulty
      rows.each do |row|
        row.each do |location|
          location.set_row row
        end
      end
      columns.each do |column|
        column.each do |location|
          location.set_column column
        end
      end
      boxes.each do |box|
        box.each do |location|
          location.set_box box
        end
      end
    end

    def clone
      Board.new self.to_s
    end

    def best_guess_location_with_limit current_guess_limit
      guessable = @locations.select { |location|
        !location.is_solved? && location.available_guesses.length == current_guess_limit
      }.sort_by { |location|
        location.difficulty_to_guess
      }[0]
    end

    #Start with locations that have 2 guesses and if none available go to 3
    def best_guess_location
      current_guess_limit = 2
      while (location = best_guess_location_with_limit current_guess_limit).nil?
        current_guess_limit = current_guess_limit + 1
      end

      location
    end

    def apply_guess location_index, guess
      @locations[location_index].make_guess guess
    end

    def exclude_guess location_index, guess
      @locations[location_index].remove_possibility guess
    end

    def eliminate
      begin
        changes = false
        @locations.each do |location|
          if location.eliminate
            changes = true
          end
        end
      end while changes
      is_valid?
    end

    def to_s
      @locations.reduce("") do |memo, location|
        memo + location.raw_value.to_s
      end
    end

    def is_solved?
      @locations.each do |location|
        return false unless location.is_solved?
      end
      is_valid?
    end

    def is_valid?
      @locations.each do |location|
        return false unless location.is_valid?
      end
      true
    end


    private

    def rows
      @locations.each_slice(9)
    end

    def columns
      rows.to_a.transpose
    end

    def boxes
      boxes = Array.new(9)
      3.times do |index|
        offset = 27 * index
        boxes[index * 3] = [
            @locations[0 + offset], @locations[1 + offset], @locations[2 + offset],
            @locations[9 + offset], @locations[10 + offset], @locations[11 + offset],
            @locations[18 + offset], @locations[19 + offset], @locations[20 + offset]
        ];

        boxes[(index * 3) + 1] = [
            @locations[3 + offset], @locations[4 + offset], @locations[5 + offset],
            @locations[12 + offset], @locations[13 + offset], @locations[14 + offset],
            @locations[21 + offset], @locations[22 + offset], @locations[23 + offset]
        ];

        boxes[(index * 3) + 2] = [
            @locations[6 + offset], @locations[7 + offset], @locations[8 + offset],
            @locations[15 + offset], @locations[16 + offset], @locations[17 + offset],
            @locations[24 + offset], @locations[25 + offset], @locations[26 + offset]
        ];
      end
      boxes
    end
  end

  #The Record of a single solve attempt
  class LogBook
    attr_reader :eliminations, :guesses, :starting_board, :finished_board, :solved, :valid

    def initialize
      @eliminations = 0
      @guesses = 0
    end

    def start starting_board
      @start = Time.now
      @starting_board = starting_board.to_s
    end

    def guess
      @guesses = @guesses + 1
    end

    def elimination
      @eliminations = @eliminations + 1
    end

    def finish finished_board
      @finish = Time.now
      @finished_board = finished_board.to_s
      @solved = finished_board.is_solved?
      @valid = finished_board.is_valid?
    end

    def duration
      @finish - @start
    end

  end

  #Sudoku Solver
  class Sudoku

    attr_reader :board, :logbook

    def initialize(board_string)
      @board = Board.new board_string
      @logbook = LogBook.new
    end

    def solve!
      logbook.start board
      @board = solve_with_guesses board
      logbook.finish board
      @board
    end


    #Return a solved board if possible
    #Return the board param if not
    def solve_with_guesses board, depth=0

      @logbook.elimination
      board.eliminate

      return board if board.is_solved?
      return board unless board.is_valid?

      location = board.best_guess_location

      unless location.nil?

        location.available_guesses.each do |guess|

          #Clone the board so we can try the experiment
          scratch_pad = board.clone

          # a guess can result in a board that:
          # SOLVED -> is_solved? - We are done
          # BROKEN -> !is_valid? - We can exclude the guess
          # UNSOLVED -> is_valid? && !is_solved - Requires Recursive Guessing

          @logbook.guess
          scratch_pad.apply_guess location.index, guess
          guess_solved = solve_with_guesses(scratch_pad, depth + 1)
          return guess_solved if guess_solved.is_solved?

          unless guess_solved.is_valid?
            board.exclude_guess location.index, guess
            updated_solved = solve_with_guesses(board, depth + 1)
            return updated_solved if updated_solved.is_solved?
          end
        end
      else
        puts "NO AVAILABLE GUESSES!"
      end

      board
    end


    def is_solved?
      board.is_solved?
    end

    def is_valid?
      board.is_valid?
    end

    def export_board
      board.to_s
    end

    def clone_board
      board.clone
    end

    def dump_difficulties
      board.dump_difficulties
    end

  end

  # Renderer for the Logbooks
  class View
    UNSOLVED = '*'
    DUO = '.'
    TRIO = '+'

    def self.footer logbook
      "#{(logbook.solved) ? "SOLVED  " : (logbook.valid ? "        " : "INVALID ")} Duration=#{logbook.duration} Guesses=#{logbook.guesses}  Eliminations=#{logbook.eliminations}  "
    end

    def self.summary label, board
      "#{label} #{board}"
    end

    def self.combine_board_display logbook
      result = []
      result << view(Board.new(logbook.starting_board))
      result << view(Board.new(logbook.finished_board))
      result << footer(logbook)
      result << "\n"
      result.join("\n")
    end

    def self.combine_board_summary logbook
      result = []
      result << summary("START ", logbook.starting_board)
      result << summary("END   ", logbook.finished_board)
      result << footer(logbook)
      result << "\n"
      result.join("\n")

    end

    def self.draw_location location
      if location.is_solved?
        location.available_guesses[0]
      elsif location.available_guesses.length == 2
        DUO
      elsif location.available_guesses.length == 3
        TRIO
      else
        UNSOLVED
      end
    end


    # Returns a string representing the current state of the board
    # Don't spend too much time on this method; flag someone from staff
    # if you are.
    def self.view board
      raw = board.locations.map { |location|
        draw_location location
      }

      result = ["\n"]

      result << (raw.each_slice(9).map { |row|
        row.join(" | ")
      }.join("\n---------------------------------\n"))
      result << ["\n"]

      result.join()
    end
  end


  #Runner for the Sudoku solver so it can handle multiple files with multiple puzzles
  class Runner

    SOURCE_DIR = Pathname.new(__FILE__).dirname.realpath

    def initialize filenames
      @filenames = filenames
      @filenames = [@filenames] unless @filenames.class == Array
    end

    def run
      failures = []
      successes = []
      @filenames.each do |filename|
        File.readlines(SOURCE_DIR.join(filename)).each_with_index do |puzzle, index|

          puzzle = puzzle.chomp

          unless puzzle.empty?

            game = Sudoku.new(puzzle)

            puts "WORKING ON ##{index} from #{filename}"

            game.solve!

            puts View.combine_board_display game.logbook

            unless game.is_solved?
              failures << game.logbook
            else
              successes << game.logbook
            end
          end
        end
      end
      unless failures.empty?
        puts "Failures from #{@filename}"
        puts failures.map { |logbook| View.combine_board_summary(logbook) }
      else
        puts "NO FAILURES!"
        puts successes.map { |logbook| View.combine_board_summary(logbook) }

        totaltime = successes.reduce(0) { |memo, logbook| memo + logbook.duration }
        maxtime = successes.reduce(0) { |memo, logbook| [memo, logbook.duration].max }
        average = totaltime / successes.length.to_f

        puts "Summary: #{successes.length()} puzzles solved in #{ '%.3f' % totaltime} seconds (Worst #{'%.4f' % maxtime} seconds, Average #{'%.4f' % average} seconds)"
      end
    end
  end

end

Sudoku::Runner.new(['puzzles/http_magictour.free.fr_top2365.txt']).run
#Sudoku::Runner.new(['puzzles/samples.txt']).run
