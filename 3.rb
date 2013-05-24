#!/usr/bin/env ruby -w
# -*- coding: utf-8 -*-

# Importera lexer, parser, evaluator
require './3_parser'
require './3_tree'

############################# 3.rb ###########################################
#                                                                            #
# <3 by Hannah Börjesson and Per Jonsson 2013                                #
# @Innovativ Programmering, Linköping university                             #
#                                                                            #
# A lovable interpreted imperative programming language                      #
#                                                                            #
# This file consists of tokens and grammar rules                             #
#                                                                            #
# The rest will follow in Swedish                                            #
#                                                                            #
##############################################################################

class LessThanThree 
  def initialize
    @threeParser = Parser.new(" <3 ") do

      ##### ###### #####
      ##### TOKENS #####
      ##### ###### #####

      # Namnen på tokens torde förklara deras syften #

      token( /<!-+.*-+>/)#/m) 

      token(/^"[^\"]*"/) {|str_lit| str_lit.to_s}

      token(/\s+/) # ignorera blanksteg
      token(/\t+/) # och tabbar

      token(/<3>/) {|start| :BEGIN}
      token(/<\/3>/) {|_end_| :END}

      token(/NULL/) {|null_stmt| null_stmt}
      token(/BREAK/) {|break_stmt| break_stmt}
      token(/RETURN/) {|return_stmt| return_stmt}

      token(/(\[|\])/) {|subscript| subscript}

      token(/<\/IF>/) {|end_if| end_if}
      token(/IF/) {|_if_| _if_}
      token(/ELSEIF/) {|elseif| elseif}
      token(/ELSE/) {|_else_| _else_}

      token(/<\/LOOP>/) {|end_loop| end_loop}
      token(/LOOP/) {|loop| loop}
      token(/WHILE/) {|_while_| _while_}

      token(/<\/FUNCTION>/) {|end_func| end_func}
      token(/FUNCTION/) {|function| function}
      token(/NAME/) {|name| name}
      token(/VAR/) {|var| var}
  
      token(/^[a-z_]+/) {|identifier| identifier}
      token(/\{/) {|list_left| list_left}
      token(/\{/) {|list_right| list_right}

      token(/\(\)/) {|func_call| func_call} 

      token(/PRINT/) {|print| print}
      token(/READ/) {|read| read}
  
      token(/TRUE/) {|_true_| :TRUE}
      token(/FALSE/) {|_false_| :FALSE}

      token(/-?\d+\.\d+/) {|num_lit| num_lit.to_f}
      token(/-?\d+/) {|num_lit| num_lit.to_i}

      token(/\|\|/) {|_or_| _or_}
      token(/&&/) {|_and_| _and_}
      token(/NOT/) {|_not_| _not_ }

      token(/==/) {|comp_op| comp_op}
      token(/>=/) {|comp_op| comp_op}
      token(/<=/) {|comp_op| comp_op}
      token(/!=/) {|comp_op| comp_op}
      token(/</) {|comp_op| comp_op} 
      token(/>/) {|comp_op| comp_op} 

      token(/(\+|-|\*|\/)/) {|math_op| math_op};

      token(/=/) {|assign| :assign }

      token(/;+/) {|end_stmt| :end_stmt}

      token(/./) {|match| match}


      ##### ############### #####
      ##### GRAMMATIKREGLER #####
      ##### ############### #####

      # Regler matchas,för varje matchning byggs ett syntaxträd upp
      # som evalueras när vi kommit till toppnoden Program

      # Full grammatikförteckning med förklaringar finns i projektdokumentationen

      start :PROGRAM do
        match(:BEGIN, :STATEMENTS, :END) {|_, statements, _| Program.new(statements).eval} 
      end

      rule :STATEMENTS do
        match(:STATEMENT, :STATEMENTS)  {|stmt, stmts| Statements.new(stmt, stmts)}
        match(:STATEMENT) {|stmt| Statements.new(stmt)}
      end

      rule :STATEMENT do
        match(:COMPOUND_STMT)
        match(:ASSIGNMENT_STMT)
        match(:FUNC_CALL_STMT)
	match(:BREAK_STMT)
	match(:RETURN_STMT)
	match(:NULL_STMT)
      end

      rule :NULL_STMT do
        match('NULL', :end_stmt){Null.new}
      end

      rule :BREAK_STMT do
        match('BREAK',:end_stmt){Break.new}
      end

      rule :RETURN_STMT do
         match('RETURN',:NULL_STMT) {|_,null| Return.new(null)}
         match('RETURN',:PRIMARY, :end_stmt) {|_,primary,_| Return.new(primary)}
         match('RETURN',:EXPRESSION, :end_stmt) {|_,expr,_| Return.new(expr)}
         match('RETURN',:LIST_ASSIGN, :end_stmt) {|_,expr,_| Return.new(expr)}
      end 

      rule :ASSIGNMENT_STMT do
        match(:TARGET,:assign,:LIST_ASSIGN, :end_stmt) {|target,_,list,_| Assign.new(target, list)}
        match(:TARGET,:assign,:PRIMARY,:end_stmt) {|target,_,prim,_| Assign.new(target, prim)}
        match(:TARGET,:assign,:EXPRESSION,:end_stmt) {|target,_,expr,_| Assign.new(target, expr)}
        match(:TARGET,:assign,:READ_FUNC,:end_stmt) {|target,_,input,_| Assign.new(target, input)}
      end

      rule :TARGET do
        match(:SUBSCRIPTION)
        match(:IDENTIFIER)
      end

      rule :LIST_ASSIGN do
        match('{',:LIST_VALUES,'}') {|_,list_values,_| List.new(list_values)}
        match('{', '}') {|_, _| List.new(nil)} 
      end

      rule :LIST_VALUES do
        match(:LIST_VALUE,',',:LIST_VALUES) {|value,_,values| [values] + [value] }
        match(:LIST_VALUE) {|value| value}
      end

      rule :LIST_VALUE do
        match(:LIST_ASSIGN)
        match(:EXPRESSION)
        match(:PRIMARY)
      end

      rule :FUNC_CALL_STMT do
        match(:IDENTIFIER,'()',:end_stmt) {|id,_,_| FunctionCall.new(id)}
        match(:IDENTIFIER,'(',:ARGUMENT,')',:end_stmt) {|id,_,args,_,_| FunctionCall.new(id, args)}
      end

      rule :ARGUMENT do
        match(:PRIMARY,',',:ARGUMENT) {|arg,_,args| ArgumentList.new(arg, args)}
        match(:PRIMARY) {|arg| ArgumentList.new(arg)}
      end

      rule :FUNC_CALL do
        match(:IDENTIFIER,'()') {|id,_,_| FunctionCall.new(id)}
        match(:IDENTIFIER,'(',:ARGUMENT,')') {|id,_,args,_,_| FunctionCall.new(id, args)}
      end

      rule :COMPOUND_STMT do
        match(:IF_STMT)
        match(:LOOP_STMT)
        match(:FUNC_DEF)
        match(:PRINT_STMT)
      end

      rule :IF_STMT do
        match(:IF_PART,:ELSEIF_PART,:ELSE_PART,'</IF>') {|if_p,elseif_p,else_p,_| IfStmt.new(if_p, elseif_p, else_p)}
        match(:IF_PART,:ELSEIF_PART,'</IF>') {|if_p,elseif_p,_| IfStmt.new(if_p, elseif_p) }
        match(:IF_PART,:ELSE_PART,'</IF>') {|if_p,else_p,_| IfStmt.new(if_p, nil, else_p)}
        match(:IF_PART,'</IF>') {|if_p,_| IfStmt.new(IfStmt.new(if_p))}
      end

      rule :IF_PART do
        match('<', 'IF', :EXPRESSION,'>',:STATEMENTS) {|_,_,expr,_,stmts| If.new(stmts, expr)}
      end

      rule :ELSEIF_PART do
        match(:ELSEIF_PART, :ELSEIF)  {|part, elseif| ElseIfs.new(part, elseif)}
        match(:ELSEIF) {|elseif| ElseIfs.new(elseif)}
      end

      rule :ELSEIF do
        match('<', 'ELSEIF',:EXPRESSION,'>',:STATEMENTS) {|_,_,expr,_,stmts| If.new(stmts, expr)}
      end

      rule :ELSE_PART do
        match('<', 'ELSE', '>',:STATEMENTS) {|_,_,_,stmts| If.new(stmts)}
      end

      rule :LOOP_STMT do
        match('<', 'LOOP',:assign, '"WHILE"',:EXPRESSION,'>',:STATEMENTS,'</LOOP>') {|_,_,_,_,expr,_,stmts,_| Loop.new(expr, stmts)}
      end

      rule :EXPRESSION do
        match(:EXPRESSION,'||',:AND_TEST) {|expr,op,and_test| Expression.new(expr,"or",and_test)}
        match(:AND_TEST)
      end

      rule :AND_TEST do
        match(:AND_TEST,'&&',:NOT_TEST) {|and_test,_,not_test| Expression.new(and_test,"and",not_test)}
        match(:NOT_TEST)
      end

      rule :NOT_TEST do
        match('NOT',:COMPARISON) {|_,comparison| Expression.new(comparison, "not")}
        match(:COMPARISON)
      end

      rule :COMPARISON do
        match(:MATH_PRIMARY,'==',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, "==", p2)}
        match(:MATH_PRIMARY,'>=',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, ">=", p2)}
        match(:MATH_PRIMARY,'<=',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, "<=", p2)}
        match(:MATH_PRIMARY,'!=',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, "!=", p2)}
        match(:MATH_PRIMARY,'<',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, "<", p2)}
        match(:MATH_PRIMARY,'>',:MATH_PRIMARY) {|p1,_,p2| Comparison.new(p1, ">", p2)}
        match(:BOOL_LIT) {|b| Comparison.new(b)}
        match('(',:EXPRESSION, ')') {|_,expr,_| expr}
      end

      rule :SUBSCRIPTION do
        match(:STRING_LIT, '[', :SUB, ']') {|str,_,index,_| Subscription.new(str, index)}
        match(:IDENTIFIER, '[', :SUB, ']')  {|id,_,index,_| Subscription.new(id, index)}
        match(:FUNC_CALL, '[', :SUB, ']') {|func,_,index,_| Subscription.new(func, index) }
      end

      rule :SUB do
        match(:MATH_EXPR, ']', '[', :SUB) {|m,_,_,s| SubValues.new(m,s)}
        match(:MATH_EXPR)
      end

      rule :FUNC_DEF do
        match('<', 'FUNCTION', 'NAME',:assign, String, :PARAMETERS,'>', :STATEMENTS,'</FUNCTION>')  {|_,_,_,_,id,pars,_,stmts,_|  Function.new(id[1, id.size-2], stmts, pars)}
        match('<', 'FUNCTION', 'NAME', :assign, String,'>',:STATEMENTS,'</FUNCTION>') {|_,_,_,_,id,_,stmts,_| Function.new(id[1, id.size-2], stmts) }  
      end

      rule :PARAMETERS do
        match(:PARAMETER,',',:PARAMETERS) {|par,_,pars| ParameterList.new(par, pars) }
        match(:PARAMETER)
      end

      rule :PARAMETER do
        match('VAR',:IDENTIFIER,:assign,:PRIMARY) {|_,name,_,value| Parameter.new(name, value)}
        match('VAR',:IDENTIFIER) {|_, name| Parameter.new(name)}
      end

      rule :PRINT_STMT do
        match('PRINT','(', :PRIMARY ,')', :end_stmt) {|_,_,p,_,_| Print.new(p)} 
      end

      rule :READ_FUNC do
        match('READ','(', :IDENTIFIER ,')') {|_,_,id,_,_| Read.new(id)}
        match('READ','(', :STRING_LIT ,')') {|_,_,str,_,_| Read.new(str)}
      end

      rule :PRIMARY do
        match(:MATH_EXPR)
        match(:SUBSCRIPTION)
        match(:FUNC_CALL)
        match(:ATOM)
      end

      rule :ATOM do
        match(:IDENTIFIER) 
        match(:LITERAL)
      end

      rule :LITERAL do
        match(:STRING_LIT)
        match(:BOOL_LIT)
        match(:NUM_LIT)
      end

      rule :STRING_LIT do
        match(String)  
        end

      rule :NUM_LIT do
        match(Integer) {|integer| NumLit.new(integer) }
        match(Float) {|float| NumLit.new(float) }
      end

      rule :BOOL_LIT do
        match(:TRUE) { BoolLit.new(true) }
        match(:FALSE) { BoolLit.new(false) }
      end

      rule :IDENTIFIER do
        match(/^[a-z_]+/) {|identifier| Variable.new(identifier)}
      end

      rule :MATH_EXPR do
        match(:MATH_EXPR, '+', :MULT_EXPR) {|math_expr,op,mult_expr| Mathreematics.new(math_expr, op, mult_expr)}
        match(:MATH_EXPR, '-', :MULT_EXPR) {|math_expr,op,mult_expr| Mathreematics.new(math_expr, op, mult_expr)}
        match(:MULT_EXPR)
        end

      rule :MULT_EXPR do
        match(:MULT_EXPR,'*', :UNARY_EXPR) {|mult_expr,op,unary_expr| Mathreematics.new(mult_expr, op, unary_expr)}
        match(:MULT_EXPR,'/', :UNARY_EXPR) {|mult_expr,op,unary_expr| Mathreematics.new(mult_expr, op, unary_expr)}
        match(:UNARY_EXPR)
      end

      rule :UNARY_EXPR do
        match('-',:MATH_PRIMARY) {|_,math_primary| -math_primary}
        match('+',:MATH_PRIMARY) {|_,math_primary| math_primary}
        match('(',:MATH_EXPR, ')') {|_,math_expr,_| math_expr}
        match(:MATH_PRIMARY)
      end

      rule :MATH_PRIMARY do
        match(:SUBSCRIPTION)
        match(:FUNC_CALL)
        match(:IDENTIFIER)
        match(:NUM_LIT)
        match(:BOOL_LIT)
      end
    end
  end


  ### ###################### ###
  ### <3 "MAIN"-FUNKTION 3>  ###
  ### ###################### ###

  # När three anropas körs parsningen och evalueringen #

  def three
    puts("\nWelcome to <3!\nPlease specify the source code file to be interpreted (ex: 3.three):")
    source =  gets.chomp 

    file = File.read(source)
    puts("\n--- Executing: #{source} --- \n\n")
    @threeParser.parse(file)
  end

  # Debug-utskrifter till parsern
  def log(state = false)
    if state
      @threeParser.logger.level = Logger::DEBUG
    else
      @threeParser.logger.level = Logger::WARN
    end
  end
end


###############################################
#            <3 MAIN SEQUENCE 3>              #
###############################################

t = LessThanThree.new 
t.log 

# Kör!
begin
  t.three
rescue Exception => error
  puts error.message
end

puts("\n-------------------------------------------")
puts("Reached end of program. Three you later! <3 \n")


################################################
#     THREE YOU LATER! <3++ COMING SOON        #
################################################
