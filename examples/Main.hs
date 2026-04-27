module Main where

import Anthropic.Client   (fromEnv)
import Anthropic.Messages (sendMessage)
import Anthropic.Types

main :: IO ()
main = do
    client <- fromEnv
    let req = MessageRequest
            { reqModel         = claude3_5Sonnet
            , reqMessages      = [userMessage "Say hello in one sentence."]
            , reqMaxTokens     = 256
            , reqSystem        = Nothing
            , reqStopSequences = Nothing
            , reqTemperature   = Nothing
            , reqTools         = Nothing
            , reqToolChoice    = Nothing
            }
    msg <- sendMessage client req
    mapM_ print (msgContent msg)
