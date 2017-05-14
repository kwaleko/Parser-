module Parser  where 

import                Control.Applicative (Alternative(..),(<|>))
import                Control.Monad(mapM)
import                Data.Char(isDigit)
import                Prelude hiding (break)
import                Text.Read(readMaybe)


import                Types  (Parser(..),Article(..))


--function that remove the constructer and return the parser result.
parse :: Parser a -> String -> [(a,String)]
parse (P p) inp = p inp


-- parser of character, it is the basic block in which all other parser that that consume one character will be constructed. 
item :: Parser Char
item = P (\inp -> case inp of
  [] -> []
  (x:xs) -> [(x,xs)])
 

-- a Parser that succeed if the end of the given string is reached or fail otherwise.
end :: Parser [Char]
end = P (\inp -> case inp of
  [] -> [("","")]
  otherwise -> []
  )
  

-- fmap applies a funtion to the result value of the parser if the parser succeed, and propagates the failure otherwise.
instance Functor Parser where
  -- fmap :: (a -> b) -> Parser a -> Parser b
  fmap f p = P (\inp -> case parse p inp of
    [] -> []
    [(v,out)] -> [(f v,out)])

{- pure transorm a value that always succeed with this value as its result, without consuming any of the input string 

  <*> applies a parser that returns a function to a parser that returns an argument to give a parser that 
  returns the result of applying the function to the argument, and only succed if all the compponents succeed 
-} 
    
instance Applicative Parser where
  -- pure :: a -> Parser a
  pure val = P (\inp -> [(val,inp)])
  

  -- <*> :: Parser (a -> b) -> Parser a -> Parser b 
  pf <*> pv = P (\inp -> case parse pf inp of
    [] -> []
    [(g,out)] -> parse (fmap g pv) out)
 
   
-- make the parser to be instance of Monad. 
instance Monad Parser  where
  -- (>>= ) :: Parser a -> (a -> Parser b) -> Parser c
  p >>= f = P (\inp -> case parse p inp of
    [] -> []
    [(v,out)] -> parse (f v) out)
    
  fail _ = P (\inp -> [])


-- a parse that take a predicate and parse the first character if the predicate is evluated to true and fail otherwise.
sat :: (Char -> Bool) -> Parser Char
sat f = item >>= \x -> case f x of
  False -> fail "error"
  True -> return x 
 
 
instance Alternative Parser where
  --empty :: Parser a
  empty = P (\inp -> [])
  
  -- <|> Parse a -> Parser a -> Parser a
  p1 <|> p2 = P (\inp -> case parse p1 inp of 
    [] ->  parse p2 inp
    [(v,out)] -> [(v,out)])
 
  
-- a parser that parser only digits.
digit :: Parser Char
digit = sat isDigit


-- if the character is digit the function will return True, False otherwise.
isNotDigit :: Char -> Bool
isNotDigit x = not $ isDigit x

-- a parser that parser a specific char or fail otherwise.
char :: Char -> Parser Char
char x = sat (== x)

-- string is a parser that parse a specific string
string :: String -> Parser String
string [] = return []
string (x:xs) = char x >> string xs >> return (x:xs)


{- parseDigits is a parser of string that parse all digit in a given string using the below method:
-try a parser  (end >>= \_ -> return "") that check if the list of character has been consumed, if this parser
 fail then the next parser will be executed, if succeeded then it will return a parser of empty string with the
  remaining string is empty as well.

-the second parser is ((sat isNotDigit) >>= \_ -> ) that try to parse a character and succeed as long 
as the character is not digit, or fail otherwise. when succeeded the parsed character will ignore by monadic bind 
then the function allDigit will be called again, when it fails then it will try the next parser.

-the thrid parser ((many digit) >>= \c ->   >>= \cs -> return (c++cs)) will try to parser list of 
digits, and this function will keep calling itself recusively till the end of the string then return the parsed 
characters and return it using the succeed parser. 
-}
parseDigits :: Parser [Char]
parseDigits = 
      end  
  <|> ((sat isNotDigit) >> parseDigits) 
  <|> ((many digit) >>= \c -> parseDigits >>= \cs -> return (c++cs))


{- Parser of string that parse a string till it attend a given character then stop.
for example : parser (ParseTill ';') "abc;def" will return [("abc","def")].
-}
parseTill :: Char ->  Parser String 
parseTill char = 
      end
  <|> (sat (== char) >> return [])
  <|> ( item >>= \c -> (parseTill char) >>= \cs -> return (c:cs))
  
-- "title;post;title2;post" -> ["title","post","title2","post"]
break :: Char -> Parser [String]
break val =
  (end >> return [])
  <|> (parseTill val >>= \c -> (break val) >>= \cs -> return (c:cs))
  
-- comments
chunks :: [String] -> Maybe [(String,String,String)]
chunks str = case str  of
  [] -> Just[]
  (id:title:content:xs) ->  ((id,title,content):) <$> (chunks xs)
  _ -> Nothing
  
-- comments
chunksToArticles :: Maybe [(String,String,String)] -> Maybe [Article]
chunksToArticles val =  (map performChunk) <$> val

-- comments
performChunk :: (String,String,String) -> Article
performChunk (id,title,content) = Article (readMaybe id :: Maybe Int) title content

-- comments
articlesLookup :: Maybe [Article] -> Maybe [(Maybe Int,Article)]
articlesLookup val =map (\(Article id title content) -> (id,Article id title content)) <$> val






 