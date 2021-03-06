{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Tests.Readers.HTML (tests) where

import Prelude
import Data.Text (Text)
import qualified Data.Text as T
import Test.Tasty
import Test.Tasty.QuickCheck
import Tests.Helpers
import Text.Pandoc
import Text.Pandoc.Arbitrary ()
import Text.Pandoc.Builder
import Text.Pandoc.Walk (walk)

html :: Text -> Pandoc
html = purely $ readHtml def

htmlNativeDivs :: Text -> Pandoc
htmlNativeDivs = purely $ readHtml def { readerExtensions = enableExtension Ext_native_divs $ readerExtensions def }

makeRoundTrip :: Block -> Block
makeRoundTrip CodeBlock{} = Para [Str "code block was here"]
makeRoundTrip LineBlock{} = Para [Str "line block was here"]
makeRoundTrip RawBlock{} = Para [Str "raw block was here"]
makeRoundTrip x           = x

removeRawInlines :: Inline -> Inline
removeRawInlines RawInline{} = Str "raw inline was here"
removeRawInlines x           = x

roundTrip :: Blocks -> Bool
roundTrip b = d'' == d'''
  where d = walk removeRawInlines $ walk makeRoundTrip $ Pandoc nullMeta $ toList b
        d' = rewrite d
        d'' = rewrite d'
        d''' = rewrite d''
        rewrite = html . T.pack . (++ "\n") . T.unpack .
                  purely (writeHtml5String def { writerWrapText = WrapPreserve })

tests :: [TestTree]
tests = [ testGroup "base tag"
          [ test html "simple" $
            "<head><base href=\"http://www.w3schools.com/images/foo\" ></head><body><img src=\"stickman.gif\" alt=\"Stickman\"></head>" =?>
            plain (image "http://www.w3schools.com/images/stickman.gif" "" (text "Stickman"))
          , test html "slash at end of base" $
            "<head><base href=\"http://www.w3schools.com/images/\" ></head><body><img src=\"stickman.gif\" alt=\"Stickman\"></head>" =?>
            plain (image "http://www.w3schools.com/images/stickman.gif" "" (text "Stickman"))
          , test html "slash at beginning of href" $
            "<head><base href=\"http://www.w3schools.com/images/\" ></head><body><img src=\"/stickman.gif\" alt=\"Stickman\"></head>" =?>
            plain (image "http://www.w3schools.com/stickman.gif" "" (text "Stickman"))
          , test html "absolute URL" $
            "<head><base href=\"http://www.w3schools.com/images/\" ></head><body><img src=\"http://example.com/stickman.gif\" alt=\"Stickman\"></head>" =?>
            plain (image "http://example.com/stickman.gif" "" (text "Stickman"))
          ]
        , testGroup "anchors"
          [ test html "anchor without href" $ "<a name=\"anchor\"/>" =?>
            plain (spanWith ("anchor",[],[]) mempty)
          ]
        , testGroup "lang"
          [ test html "lang on <html>" $ "<html lang=\"es\">hola" =?>
            setMeta "lang" (text "es") (doc (plain (text "hola")))
          , test html "xml:lang on <html>" $ "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"es\"><head></head><body>hola</body></html>" =?>
            setMeta "lang" (text "es") (doc (plain (text "hola")))
          ]
        , testGroup "main"
          [ test htmlNativeDivs "<main> becomes <div role=main>" $ "<main>hello</main>" =?>
            doc (divWith ("", [], [("role", "main")]) (plain (text "hello")))
          , test htmlNativeDivs "<main role=X> becomes <div role=X>" $ "<main role=foobar>hello</main>" =?>
            doc (divWith ("", [], [("role", "foobar")]) (plain (text "hello")))
          , test htmlNativeDivs "<main> has attributes preserved" $ "<main id=foo class=bar data-baz=qux>hello</main>" =?>
            doc (divWith ("foo", ["bar"], [("role", "main"), ("data-baz", "qux")]) (plain (text "hello")))
          , test htmlNativeDivs "<main> closes <p>" $ "<p>hello<main>main content</main>" =?>
            doc (para (text "hello") <> divWith ("", [], [("role", "main")]) (plain (text "main content")))
          , test htmlNativeDivs "<main> followed by text" $ "<main>main content</main>non-main content" =?>
            doc (divWith ("", [], [("role", "main")]) (plain (text "main content")) <> plain (text "non-main content"))
          ]
        , testProperty "Round trip" roundTrip
        ]
