#Sudoku Solver

## Some Puzzles
* [http://magictour.free.fr/top2365](http://magictour.free.fr/top2365)

## Overview
The idea with this solver was to have the cells on the grid (Locations) know their own state and be able to figure out how guessable they were

* Simple elimination of possible guesses
* An estimated 'best guess Location'
  * Each Location knows about it's membership in 3 'SetsOfNine' 
  * Each Location can use this information to know:
    * If it is solved
    * If it is valid
    * The 'difficulty' of guessing this Location's solution
* Taking a guess for a location followed by an elimination may result in either  
 * A solved board - We are done
 * A broken board - The guess is proven to be wrong
 * An unsolved board - Future guesses may help (recursion required)
* A challenge is that recursive wrong guesses need to be 'undone' so:
  * The state of the board needs to be included in the stack
  * A board solved by recursion needs to be passed back up while broken boards are not

## Types

* Everything is contained within ``module Sudoku``
* ``class Location`` A specific Location on the Board
* ``class Board`` The state of the Board (81 Locations)
* ``class LogBook`` The record of a single attempt to solve 1 puzzle
* ``class Sudoku`` The solver
* ``class View`` The renderer for Logbooks so users can see the results
* ``class Runner`` Runner for the Sudoku solver so it can handle multiple files with multiple puzzles

