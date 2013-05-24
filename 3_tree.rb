#!/usr/bin/env ruby -w
# -*- coding: iso-8859-1 -*-

############################ 3_tree.rb #######################################
#                                                                            #
# <3 by Hannah Börjesson and Per Jonsson 2013                                #
# @Innovativ Programmering, Linköping university                             #
#                                                                            #
# A lovable interpreted imperative programming language                      #
#                                                                            #
# This file contains a syntax tree builder with eval methods for each node   #
#                                                                            #
# The rest will follow in Swedish                                            #
#                                                                            #
##############################################################################

=begin
Följande Scope-klass är inspirerat av en liknande klass i språket "Nibla"
(Albin Ekberg), som är ett av projekten från 2012 års upplaga av TDP019
=end
class Scope
  attr_accessor(:parent)
  def initialize
    @@counter = 1 
    @@scope =  {}
  end
  def reset
    set(s)
  end
  def revert
  end
  def Scope.set(s)
    @@scope = s
  end
  def Scope.get
     @@scope
  end
  def Scope.counter
    @@counter
  end
  def Scope.create
    scope = {} 
    @@counter += 1
    scope[@@counter] = Scope.get
    scope
  end
  def Scope.reset(s)
     Scope.set(s[@@counter])
    @@counter -= 1
  end
end

###########################
Scope.new ## Skapa scope ##
###########################

# Den översta noden vars eval-funktion anropas först
class Program
  attr_accessor
  def initialize(statements)
    @statements = statements
  end

  def eval
      @statements.eval 
  end
end

class Statements
  def initialize(statement, *statements)
    @statements = statements
    @statement = statement
    @return = Null.new
  end

  def eval
    @statements << @statement
    @statement = Null.new

    # Måste göra reverse för att det ska bli top-down order
    @statements.reverse_each do |s|
      return s if s.is_a?(Return || Break)
      @return = s.eval
    end
   @return
  end
end

class Null
  def eval
    self 
  end
end

class Break
  def eval
    self
  end
end


class Return
  def initialize (return_arg)
    @return_arg = return_arg
  end
  def eval
    @return_arg.eval
  end
end

class Assign
  def initialize(target, assignment)
    @target = target
    @assignment = assignment
  end

  def eval
    @scope = Scope.get
    value = @assignment.eval

    # Hämta ut variabelns värde från Scope genom att använda namnet som nyckel
    if @target.is_a?(Subscription) 
      raise "<3 Assign Error: Target is not subscriptable" unless @scope[@target.name]
      @scope[@target.name][@target.index.eval] = value  
    else
      @scope[@target.name] = value 
    end
    
    value
  end
end

=begin
Följande Variabelklass med look-up-funktion är inspirerat av en liknande klass
 i språket "Nibla" (Albin Ekberg)som är ett av projekten från 2012 års TDP019
=end
class Variable
  attr_accessor(:name)

  def initialize(id)
    @name = id
  end

  def eval
    look_up(self)
  end
end

####################
def look_up(variable)
  if variable.is_a?(Variable) then name = variable.name  else name = variable end

  scope = Scope.get

  # Sök i scope om variabeln finns i närmaste omgivningen
  if scope.has_key?(name)
    return scope[name]
  # Annars sök i en underliggande omgivning
  elsif scope[Scope.counter] != nil
    counter = Scope.counter

    while counter != 1
      if scope[counter].has_key?(name)
        return scope[counter][name]
      else
        # Återskapa underliggande omgivning
        scope = scope.values[0] # första entryn är ett scope
        scope = Hash[*scope.collect {|x| [x]}.flatten]
        counter -= 1
      end
    end
  end

  raise "<3 Name Error: The variable #{name} does not exist"
end

class List < Array 
  def initialize(values)
    self << values if values
  end

  def eval
     # Om values är nil, evaluera ej, returnera då tom List
    self.flatten!
    self.collect! {|s| s.eval } # Evaluera varje element
    self.reverse! # Rotera för att skapa rätt ordning
  end

  def subscript(index)
    if index.is_a?(Array) # indexering ser ut så här: [][], etc
      index.each do |i|
        @value_at_i = self[i.eval] 
      end
    else # Indexering med endast en []
      @value_at_i = self[index]
    end
    @value_at_i # returnera värdet på positionen i, i listan 
  end
end

class Subscription
  attr_accessor(:name, :index)
  def initialize(container, index)
    @container = container
    @index = index
    @name = @container
  end
  def type
    @container.class
  end

  # Måste kolla så att identifierns variabel är subscriptable, List eller string
  def eval
    container = look_up(@container)
    container.subscript(@index.eval) # Returnera resultatet
  end
end

class SubValues
  def initialize(*digits)
    @digits = digits
  end
  def eval
    @digits
  end
end

class Function 
  def initialize(func_name, statements, *pars) # pars = nil
    @func_name = func_name
    @statements = statements
    @pars = pars
  end

  def eval
    # Lokalisera omgivning att spara funktionen i
    @scope = Scope.get
    # Spara parametrar och satser (funktionskropp)
    func_body = Hash.new
    func_body[:pars] = @pars
    func_body[:statements] = @statements

    # Kolla om vi ska skriva över funktionen
    counter = Scope.counter
    while counter > 1
      if @scope[counter].has_key?(@func_name)
        @scope[counter][@func_name] = func_body
        return
      else
        @scope = @scope.values[0]
        @scope = Hash[*@scope.collect {|x| [x]}.flatten]
        counter -= 1
      end
    end

    # Vi lägger i funktionen i scope-tabellen om den inte finns
    @scope = Scope.get
    @scope[@func_name] = func_body
  end
end


class ParameterList < Array
  def initialize(*parameters)
    self << parameters
  end

  def eval
    self.each do |p|
      p = p.eval
    end
    self
  end
end

class Parameter < Hash
  def initialize(var_name, value = nil) # value är valfritt
    # Tilldela parametern en egen variabeltabell
    (value) ? self[var_name] = value.eval : self[var_name] = value
  end
  def eval
    self
  end
end

class FunctionCall
  def initialize(func_name, args = nil) # args valfritt
    @func_name = func_name
    @args = args
  end

  def eval
    # Om funktionen anropas med ett värde, eller en Variable med ett värde:
    # kör look_up om det finns en Variable (den måste finnas i scope redan)
    # Vi skriver då över argumenten från en Variabel till ett värde
    if @args
      0.upto(@args.flatten!.length) do |i|
        @args[i] = look_up(@args[i]) if @args[i].is_a?(Variable)
      end
    end

    # Hämta funktionskropp: statements och parametrar (lokalisera i scope)
    func_body = @func_name.eval

    # Spara undan statements separat
    statements = func_body[:statements] 

    # Skapa ett lokalt scope för att evaluera funktionens
    # satser och inrymma lokala variabler och värden
    @scope = Scope.create
    Scope.set(@scope)

    pars = {} # Lokal parameterlista
    # Om det finns parametrar, evaluera dessa
    if func_body[:pars] 
      # func_body[:pars] lagrar en array med parametrar
      # itererera genom varje parameter, evaluera och spara
      func_body[:pars].each do |par|
        if par.is_a?(ParameterList)
          par.flatten.each do |p|
            # uppdatera vår Hash med en enskild post åt gången
            pars.merge!(p.eval)
          end
        else # Endast en parameter
          pars = par.eval # Spara som parameterlista
        end
      end
    end


    # Eventuellt skriva över motsvarande argument i Scope
    (@args) ? args_len = @args.length : args_len = 0

    # Matcha antal argument mot parameterlistan (ej för många, ej för få)
    # args.length får inte understiga antalet nilparametrar,
    # eller överstiga totala antalet parametrar
    # om det är korrekt, kan vi skriva över värdena
    nil_pars=0
    pars.each_value {|v| nil_pars+=1 unless v }

    arg_error = "<3 Argument Error: Wrong number of arguments; (#{args_len} args, expected #{nil_pars} args)"
    raise arg_error if args_len < nil_pars || args_len > pars.length

    if @args
      # För varje argument som kommer in, skriv över motsvarande parameter
      pars.each_key do |p|
        pars[p] = @args.shift unless @args.empty?
      end
    end

    # Vi behöver se till att parametrarna får sina rätta värden
    # (överskrivna eller default)
    # innan vi evaluerar satserna i funktionen.
    # Det gör vi med hjälp av Assign-konstruktionen
    assign_statements = [];

    # Spara färdiga parametrar i lokalt scope och lägg till eventuella värden
    pars.each do |par_name, value|
      assign_statements << Assign.new(par_name, value.eval)
    end

    # Evaluera satser, efter att evaluering av parametrar/argument gjorts
    # Så att de har en omgivning att evalueras utifrån
    # Se till att vi evaluerar i rätt ordning
    assign_statements.each {|a| a.eval } # Se till så att vi inte skriver över globalt

    @return = statements.eval
    @return = @return.eval # Returvärde måste evalueras igen

    # Återställ omgivning
    Scope.reset(@scope)
    # Returnera returvärde 
    @return
  end
end

class ArgumentList < Array
  def initialize(*args)
    self << args
  end
  def eval
    self
  end
end

class String 
  def name
    self
  end
  def eval
    self
  end
end

class Integer
  def eval
    self
  end
end

class Float 
  def eval
    self
  end
end

class TrueClass
  def eval
    true
  end
end

# Hanterar både Float och Integer
class NumLit 
  def initialize(value)
    @value = value
  end
  def eval
    @value
  end
end

class BoolLit
  def initialize (value)
    @value = value
  end
  def eval
    @value
  end
end

class Expression
  def initialize(lhs, op, rhs = nil) # nil om not-test
    @lhs = lhs
    @op = op
    @rhs = rhs
  end

  def eval
    if not @rhs
      return (not @lhs.eval)
    else
      Kernel.eval("#{@lhs.eval} #{@op} #{@rhs.eval}")
    end
  end
end

class Comparison
  def initialize(lhs, op=nil, rhs=nil)
    @lhs = lhs
    @op = op
    @rhs = rhs 
  end

  def eval
    if @lhs.is_a?(BoolLit) 
      @lhs.eval
    else
      Kernel.eval("#{@lhs.eval} #{@op} #{@rhs.eval}")
    end
  end
end

class Mathreematics
  def initialize(lhs, op, rhs)
    @op = op
    @lhs = lhs
    @rhs = rhs
  end

  def eval
     Kernel.eval("#{@lhs.eval} #{@op} #{@rhs.eval}")
  end
end

class IfStmt < Array
  # En if-del måste alltid förekomma, dock ej de två andra grenarna
  def initialize(if_part, elseif_part = nil, else_part = nil)
    self << if_part
    self << elseif_part.flatten if elseif_part
    self << else_part if else_part
    self.flatten!
  end

  def eval
     self.each do |stmt|
      # Om vi har ett stmt som inte är nil:
      # evaluera, fånga returvärde, avbryt if-blocket om returvärdet är falskt
      # för då har vi evaluerat en gren och kan stanna där
      if stmt then
        @return = stmt.eval
        break unless @return == true # vi har gått igenom en If
        return @return.eval if @return.is_a?(Break || Return) # break:a/return:a
      end
    end
    @return 
  end
end

class ElseIfs < Array
  def initialize(*parts)
    self << parts.flatten
  end
end

class If
  def initialize(statements, expression = nil)
    @expression = expression
    @statements = statements
  end

  def eval
    if @expression # expression ej nil
      if @expression.eval # Är uttrycket till (if|elseif) true ?
        @return = @statements.eval 
        if @return.is_a?(Break || Return) then return @return end # d.v.s. break 
        return @return # Gå inte vidare till andra grenar efter evaluering 
      else # @expression == false
      end
    else # else-grenen (ej if/elseif => inget villkor (@expression))
      return @statements.eval
    end
    true
  end
end

class Loop
  def initialize(expression, statements)
    @statements = statements
    @expression = expression
  end

  def eval
    while @expression.eval
      @return = @statements.eval
      return Null.new if @return.is_a?(Break) # break:a
      return @return if @return.is_a?(Return) # returnera
    end
    # Returnera
    @return
  end
end

class Print
  def initialize(print_item)
    @p = print_item
  end

  def eval
    @p = @p.eval
  
    if @p.is_a?(String) # ta bort escape:ade citationstecken 
      puts @p.gsub(/"/, '')
    else 
      puts @p
    end
  end
end

class Read
  def initialize(msg)
    @msg = msg
  end

  def eval
    @msg = @msg.eval
    if @msg.is_a?(String) # ta bort escape:ade citationstecken 
      puts @msg.gsub(/"/, '') 
    else 
      puts @msg
    end
    input = gets.chomp
    input
  end
end


