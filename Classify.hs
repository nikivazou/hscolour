module Classify
  ( TokenType(..)
  , tokenise
  ) where

import Char
import List

-- Lex Haskell source code into an annotated token stream, without
-- discarding any characters or layout.
tokenise :: String -> [(TokenType,String)]
tokenise = map (\s-> (classify s,s)) . glue . chunk

-- Basic Haskell lexing, except we keep whitespace.
chunk :: String -> [String]
chunk []    = []
chunk ('\n':s) = "\n": chunk s
chunk (c:s) | isLinearSpace c
            = (c:ss): chunk rest where (ss,rest) = span isLinearSpace s
chunk s = case Prelude.lex s of
              []             -> [head s]: chunk (tail s) -- e.g. inside comment
              ((tok,rest):_) -> tok: chunk rest

isLinearSpace c = c `elem` " \t" -- " \t\xa0"

-- Glue sequences of tokens into more useful blobs
--glue (q:".":n:rest) | Char.isUpper (head q)	-- qualified names
--                    = glue ((q++"."++n): rest)
glue ("`":rest) =				-- `varid` -> varop
  case glue rest of
    (qn:"`":rest) -> ("`"++qn++"`"): glue rest
    _             -> ("`": rest)
glue (s:ss)       | all (=='-') s && length s >=2	-- eol comment
                  = (s++concat c): glue rest
                  where (c,rest) = break ('\n'`elem`) ss
glue ("{":"-":ss)  = ("{-"++c): glue rest	-- nested comment
                  where (c,rest) = nestcomment 0 ss
glue (s:ss)       = s: glue ss
glue []           = []

-- Deal with comments.
nestcomment :: Int -> [String] -> (String,[String])
nestcomment n ("{":"-":ss) | n>=0 = (("{-"++cs),rm)
                                  where (cs,rm) = nestcomment (n+1) ss
nestcomment n ("-":"}":ss) | n>0  = (("-}"++cs),rm)
                                  where (cs,rm) = nestcomment (n-1) ss
nestcomment n ("-":"}":ss) | n==0 = ("-}",ss)
nestcomment n (s:ss)       | n>=0 = ((s++cs),rm)
                                  where (cs,rm) = nestcomment n ss
nestcomment n [] = error "no closing comment -}"

-- Classify tokens
data TokenType =
  Space | Keyword | Keyglyph | Layout | Comment | Conid | Varid |
  Conop | Varop   | String   | Char   | Number  | Error
  deriving (Eq,Show)

classify :: String -> TokenType
classify s@(h:_)
    | isSpace h              = Space
    | all (=='-') s          = Comment
    | "--" `isPrefixOf` s
      && any isSpace s       = Comment		-- not fully correct
    | "{-" `isPrefixOf` s    = Comment
    | s `elem` keywords      = Keyword
    | s `elem` keyglyphs     = Keyglyph
    | s `elem` layoutchars   = Layout
    | isUpper h              = Conid
    | isLower h              = Varid
    | h `elem` symbols       = Varop
    | h==':'                 = Conop
    | h=='`'                 = Varop
    | h=='"'                 = String
    | h=='\''                = Char
    | isDigit h              = Number
    | otherwise              = Error

-- Haskell keywords
keywords =
  ["case","class","data","default","deriving","do","else"
  ,"if","import","in","infix","infixl","infixr","instance","let","module"
  ,"newtype","of","then","type","where","_","foreign","ccall","as"]
keyglyphs =
  ["..","::","=","\\","|","<-","->","@","~","=>","[","]"]
layoutchars =
  map (:[]) ";{}(),"
symbols =
  "!#$%&*+./<=>?@\\^|-~"
