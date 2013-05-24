#!/usr/bin/env ruby -w
# -*- coding: iso-8859-1 -*-

############################ 3_tree.rb #######################################
#                                                                            #
# <3 by Hannah B�rjesson and Per Jonsson 2013                                #
# @Innovativ Programmering, Link�ping university                             #
#                                                                            #
# A lovable interpreted imperative programming language                      #
#                                                                            #
# This file contains a syntax tree builder with eval methods for each node   #
#                                                                            #
# The rest will follow in Swedish                                            #
#                                                                            #
##############################################################################

=begin
F�ljande Scope-klass �r inspirerat av en liknande klass i spr�ket "Nibla"
(Albin Ekberg), som �r ett av projekten fr�n 2012 �rs upplaga av TDP019
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

# Den �versta noden vars eval-funktion anropas f�rst
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

    # M�ste g�ra reverse f�r att det ska bli top-down order
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

    # H�mta ut variabelns v�rde fr�n Scope genom att anv�nda namnet som nyckel
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
F�ljande Variabelklass med look-up-funktion �r inspirerat av en liknande klass
 i spr�ket "Nibla" (Albin Ekberg)som �r ett av projekten fr�n 2012 �rs TDP019
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

  # S�k i scope om variabeln finns i n�rmaste omgivningen
  if scope.has_key?(name)
    return scope[name]
  # Annars s�k i en underliggande omgivning
  elsif scope[Scope.counter] != nil
    counter = Scope.counter

    while counter != 1
      if scope[counter].has_key?(name)
        return scope[counter][name]
      else
        # �terskapa underliggande omgivning
        scope = scope.values[0] # f�rsta entryn �r ett scope
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
     # Om values �r nil, evaluera ej, returnera d� tom List
    self.flatten!
    self.collect! {|s| s.eval } # Evaluera varje element
    self.reverse! # Rotera f�r att skapa r�tt ordning
  end

  def subscript(index)
    if index.is_a?(Array) # indexering ser ut s� h�r: [][], etc
      index.each do |i|
        @value_at_i = self[i.eval] 
      end
    else # Indexering med endast en []
      @value_at_i = self[index]
    end
    @value_at_i # returnera v�rdet p� positionen i, i listan 
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

  # M�ste kolla s� att identifierns variabel �r subscriptable, List eller string
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

    # Kolla om vi ska skriva �ver funktionen
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

    # Vi l�gger i funktionen i scope-tabellen om den inte finns
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
  def initialize(var_name, value = nil) # value �r valfritt
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
    # Om funktionen anropas med ett v�rde, eller en Variable med ett v�rde:
    # k�r look_up om det finns en Variable (den m�ste finnas i scope redan)
    # Vi skriver d� �ver argumenten fr�n en Variabel till ett v�rde
    if @args
      0.upto(@args.flatten!.length) do |i|
        @args[i] = look_up(@args[i]) if @args[i].is_a?(Variable)
      end
    end

    # H�mta funktionskropp: statements och parametrar (lokalisera i scope)
    func_body = @func_name.eval

    # Spara undan statements separat
    statements = func_body[:statements] 

    # Skapa ett lokalt scope f�r att evaluera funktionens
    # satser och inrymma lokala variabler och v�rden
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
            # uppdatera v�r Hash med en enskild post �t g�ngen
            pars.merge!(p.eval)
          end
        else # Endast en parameter
          pars = par.eval # Spara som parameterlista
        end
      end
    end


    # Eventuellt skriva �ver motsvarande argument i Scope
    (@args) ? args_len = @args.length : args_len = 0

    # Matcha antal argument mot parameterlistan (ej f�r m�nga, ej f�r f�)
    # args.length f�r inte understiga antalet nilparametrar,
    # eller �verstiga totala antalet parametrar
    # om det �r korrekt, kan vi skriva �ver v�rdena
    nil_pars=0
    pars.each_value {|v| nil_pars+=1 unless v }

    arg_error = "<3 Argument Error: Wrong number of arguments; (#{args_len} args, expected #{nil_pars} args)"
    raise arg_error if args_len < nil_pars || args_len > pars.length

    if @args
      # F�r varje argument som kommer in, skriv �ver motsvarande parameter
      pars.each_key do |p|
        pars[p] = @args.shift unless @args.empty?
      end
    end

    # Vi beh�ver se till att parametrarna f�r sina r�tta v�rden
    # (�verskrivna eller default)
    # innan vi evaluerar satserna i funktionen.
    # Det g�r vi med hj�lp av Assign-konstruktionen
    assign_statements = [];

    # Spara f�rdiga parametrar i lokalt scope och l�gg till eventuella v�rden
    pars.each do |par_name, value|
      assign_statements << Assign.new(par_name, value.eval)
    end

    # Evaluera satser, efter att evaluering av parametrar/argument gjorts
    # S� att de har en omgivning att evalueras utifr�n
    # Se till att vi evaluerar i r�tt ordning
    assign_statements.each {|a| a.eval } # Se till s� att vi inte skriver �ver globalt

    @return = statements.eval
    @return = @return.eval # Returv�rde m�ste evalueras igen

    # �terst�ll omgivning
    Scope.reset(@scope)
    # Returnera returv�rde 
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

# Hanterar b�de Float och Integer
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
  # En if-del m�ste alltid f�rekomma, dock ej de tv� andra grenarna
  def initialize(if_part, elseif_part = nil, else_part = nil)
    self << if_part
    self << elseif_part.flatten if elseif_part
    self << else_part if else_part
    self.flatten!
  end

  def eval
     self.each do |stmt|
      # Om vi har ett stmt som inte �r nil:
      # evaluera, f�nga returv�rde, avbryt if-blocket om returv�rdet �r falskt
      # f�r d� har vi evaluerat en gren och kan stanna d�r
      if stmt then
        @return = stmt.eval
        break unless @return == true # vi har g�tt igenom en If
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
      if @expression.eval # �r uttrycket till (if|elseif) true ?
        @return = @statements.eval 
        if @return.is_a?(Break || Return) then return @return end # d.v.s. break 
        return @return # G� inte vidare till andra grenar efter evaluering 
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


