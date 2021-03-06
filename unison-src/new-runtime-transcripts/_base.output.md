# Base transcript

## Overview

This transcript is meant to be a transcript which can be run as a
prelude to other transcripts, creating helper functions, and including
a minimal subset of base in order to facilitate write nicer
transcripts which contain less boilerplate.

## Usage

```unison
a |> f = f a

compose f g = a -> f (g a)
compose2 f g = a -> b -> f (g a b)
compose3 f g = a -> b -> c -> f (g a b c)

id a = a

ability Exception where
  raise: io2.Failure -> anything

Exception.reraise : Either Failure a ->{Exception} a
Exception.reraise = cases
  Left e  -> Exception.raise e
  Right a -> a

Exception.toEither.handler : Request {Exception} a -> Either Failure a
Exception.toEither.handler = cases
  { a }                         -> Right a
  {Exception.raise f -> _} -> Left f

Exception.toEither : '{ε, Exception} a -> {ε} Either Failure a
Exception.toEither a = handle !a with Exception.toEither.handler

ability Throw e where
  throw : e -> a

List.all : (a ->{ε} Boolean) -> [a] ->{ε} Boolean
List.all f = cases
  [] -> true
  h +: t -> f h && all f t

List.map : (a ->{m} b) -> [a] ->{m} [b]
List.map f xs =
  go acc = cases
    [] -> acc
    h +: t -> go (acc :+ f h) t
  go [] xs

List.filter: (a -> Boolean) -> [a] -> [a]
List.filter f all =
  go acc = cases
    [] -> acc
    a +: as -> if (f a) then go (cons a acc) as else go acc as
  go [] all

check: Text -> Boolean -> {Stream Result} ()
check msg test = if test then emit (Ok msg) else emit (Fail msg)

checks : [Boolean] -> [Result]
checks bs =
  if all id bs then [Ok "Passed"]
  else [Fail "Failed"]

hex : Bytes -> Text
hex b =
  match Bytes.toBase16 b |> fromUtf8.impl
  with Left e -> bug e
       Right t -> t

ascii : Text -> Bytes
ascii = toUtf8

fromHex : Text -> Bytes
fromHex txt =
  match toUtf8 txt |> Bytes.fromBase16
  with Left e -> bug e
       Right bs -> bs

isNone = cases
  Some _ -> false
  None -> true


ability Stream a where
   emit: a -> ()

Stream.toList.handler : Request {Stream a} r -> [a]
Stream.toList.handler =
  go : [a] -> Request {Stream a} r -> [a]
  go acc = cases
    { Stream.emit a -> k } -> handle !k with go (acc :+ a)
    { _ } -> acc

  go []

Stream.toList : '{Stream a} r -> [a]
Stream.toList s = handle !s with toList.handler

Stream.collect.handler : Request {Stream a} r -> ([a],r)
Stream.collect.handler =
  go : [a] -> Request {Stream a} r -> ([a],r)
  go acc = cases
    { Stream.emit a -> k } -> handle !k with go (acc :+ a)
    { r } -> (acc, r)

  go []

Stream.collect : '{e, Stream a} r -> {e} ([a],r)
Stream.collect s =
  handle !s with Stream.collect.handler


-- An ability that facilitates creating temoporary directories that can be 
-- automatically cleaned up
ability TempDirs where
  newTempDir: Text -> Text
  removeDir: Text -> ()

-- A handler for TempDirs which cleans up temporary directories
-- This will be useful for IO tests which need to interact with 
-- the filesystem

autoCleaned.handler: '{io2.IO} (Request {TempDirs} r -> r)
autoCleaned.handler _ =
  remover : [Text] -> {io2.IO} ()
  remover = cases
    a +: as -> match removeDirectory.impl a with 
                   Left (Failure _ e _) -> watch e ()
                   _ -> ()
               remover as
    [] -> ()

  go : [Text] -> {io2.IO} Request {TempDirs} r -> r
  go dirs = cases
   { a } -> remover dirs
            a
   { TempDirs.newTempDir prefix -> k } ->
      dir = createTempDirectory prefix
      handle k dir with go (dir +: dirs)

   { TempDirs.removeDir dir -> k } ->
      removeDirectory dir
      handle !k with go (filter (d -> not (d == dir)) dirs)

  go []

autoCleaned: '{io2.IO, TempDirs} r -> r
autoCleaned comp = handle !comp with !autoCleaned.handler

stdout = IO.stdHandle StdOut
printText : Text -> {io2.IO} Either Failure ()
printText t = putBytes.impl stdout (toUtf8 t)

-- Run tests which might fail, might create temporary directores and Stream out
-- results, returns the Results and the result of the test
evalTest: '{Stream Result, TempDirs, io2.IO, Exception} a ->{io2.IO, Exception}([Result], a)
evalTest a = handle (handle !a with Stream.collect.handler) with !autoCleaned.handler

-- Run tests which might fail, might create temporary directores and Stream out
-- results, but ignore the produced value and only return the test Results
runTest: '{Stream Result, Exception, TempDirs, Exception, io2.IO} a -> {io2.IO}[Result]
runTest t = handle evalTest t with cases
    { Exception.raise (Failure _ f _) -> _ } -> [ Fail ("Error running test: " ++ f) ]
    { (a, _) } -> a

expect : Text -> (a -> a -> Boolean) -> a -> a -> {Stream Result} ()
expect msg compare expected actual = if compare expected actual then emit (Ok msg) else emit (Fail msg)

expectU : Text -> a -> a -> {Stream Result} ()
expectU msg expected actual = expect msg (==) expected actual

startsWith: Text -> Text -> Boolean
startsWith prefix text = (eq (Text.take (size prefix) text) prefix)

contains : Text -> Text -> Boolean
contains needle haystack = if (size haystack) == 0 then false else
  if startsWith needle haystack then true else
    contains needle (drop 1 haystack)

isDirectory = compose reraise isDirectory.impl
createTempDirectory = compose reraise createTempDirectory.impl
removeDirectory = compose reraise removeDirectory.impl
fileExists = compose reraise fileExists.impl
renameDirectory = compose2 reraise renameDirectory.impl
openFile = compose2 reraise openFile.impl
isFileOpen = compose reraise isFileOpen.impl
closeFile = compose reraise closeFile.impl
isSeekable = compose reraise isSeekable.impl
isFileEOF = compose reraise isFileEOF.impl
Text.fromUtf8 = compose reraise fromUtf8.impl
getBytes = compose2 reraise getBytes.impl
handlePosition = compose reraise handlePosition.impl
seekHandle = compose3 reraise seekHandle.impl
putBytes = compose2 reraise putBytes.impl
systemTime = compose reraise systemTime.impl
decodeCert = compose reraise decodeCert.impl
serverSocket = compose2 reraise serverSocket.impl
listen = compose reraise listen.impl
handshake = compose reraise handshake.impl 
send = compose2 reraise send.impl 
closeSocket = compose reraise closeSocket.impl
clientSocket = compose2 reraise clientSocket.impl
receive = compose reraise receive.impl
terminate = compose reraise terminate.impl
newServer = compose2 reraise newServer.impl
socketAccept = compose reraise socketAccept.impl
socketPort = compose reraise socketPort.impl
newClient = compose2 reraise newClient.impl
MVar.take = compose reraise take.impl
MVar.put = compose2 reraise put.impl
MVar.swap = compose2 reraise MVar.swap.impl
```

The test shows that `hex (fromHex str) == str` as expected.

```unison
test> hex.tests.ex1 = checks let
         s = "3984af9b"
         [hex (fromHex s) == s]
```

Lets do some basic testing of our test harness to make sure its
working.

```unison
testAutoClean : '{io2.IO}[Result]
testAutoClean _ =
  go: '{Stream Result, Exception, io2.IO, TempDirs} Text
  go _ =
    dir = newTempDir "autoclean"
    check "our temporary directory should exist" (isDirectory dir)
    dir

  handle (evalTest go) with cases
    { Exception.raise (Failure _ t _) -> _ } -> [Fail t]
    { (results, dir) } -> 
       match io2.IO.isDirectory.impl dir with
         Right b -> if b
                    then results :+ (Fail "our temporary directory should no longer exist")
                    else results :+ (Ok "our temporary directory should no longer exist")
         Left (Failure _ t _) -> results :+ (Fail t)
```

```ucm

  I found and typechecked these definitions in scratch.u. If you
  do an `add` or `update`, here's how your codebase would
  change:
  
    ⍟ These new definitions are ok to `add`:
    
      testAutoClean : '{io2.IO} [Result]

```
```ucm
.> add

  ⍟ I've added these definitions:
  
    testAutoClean : '{io2.IO} [Result]

.> io.test testAutoClean

    New test results:
  
  ◉ testAutoClean   our temporary directory should exist
  ◉ testAutoClean   our temporary directory should no longer exist
  
  ✅ 2 test(s) passing
  
  Tip: Use view testAutoClean to view the source of a test.

```
