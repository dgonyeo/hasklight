{-# LANGUAGE OverloadedStrings #-}
module Site.Site where

import qualified Data.Vector as V
import Control.Concurrent.MVar
import Control.Applicative
import Animations.LED
import Site.RootPage
import Site.JSON
import Text.JSON
import Text.JSON.Generic
import Control.Monad.IO.Class
import Snap.Core
import Text.Blaze.Html.Renderer.Utf8
import Snap.Util.FileServe
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.ByteString.Char8 as BS
import qualified Data.Map.Lazy as Map
import System.Directory
import System.FilePath.Posix

site :: MVar (V.Vector (Animation,BlendingMode))
     -> MVar [AnimMetadata]
     -> String
     -> FilePath
     -> Snap ()
site m animmeta host presetsdir = do
        ifTop (rootHandler host presetsdir)
            <|> route [ ("newanims", newAnims m animmeta)
                      , ("getanims", getAnims animmeta)
                      , ("getpresets", getPresets presetsdir)
                      , ("savepreset/:name", savePreset presetsdir)
                      , ("getpreset/:name", getPreset presetsdir)
                      ]
            <|> dir "static" (serveDirectory "static")

lookAtPresets :: String -> IO [String]
lookAtPresets presetsdir = filter (\x -> x /= "." && x /= "..")
                               `fmap` getDirectoryContents presetsdir

rootHandler :: String -> String -> Snap ()
rootHandler host presetsdir = do
    presets <- liftIO $ lookAtPresets presetsdir
    writeBS $ BSL.toStrict $ renderHtml (rootPage host presets)

newAnims :: MVar (V.Vector (Animation,BlendingMode))
         -> MVar [AnimMetadata]
         -> Snap ()
newAnims anims animmeta = do
    req <- getRequest
    let postParams = rqPostParams req
    if Map.member "newanims" postParams
        then do let jsonblob = postParams Map.! "newanims"
                    jsonanims = jsonblob !! 0
                    newanims = decodeJSON $ BS.unpack jsonanims
                liftIO $ modifyMVar_ animmeta (\_ -> return newanims)
                liftIO $ modifyMVar_ anims
                            (\_ -> return $ V.fromList $ metaToAnims newanims)
                liftIO $ putStrLn $ "New Anims: " ++ show newanims
        else modifyResponse $ setResponseCode 500


getAnims :: MVar [AnimMetadata] -> Snap ()
getAnims animmeta = do
    anims <- liftIO $ readMVar animmeta
    writeBS $ BS.pack $ encodeJSON anims

getPresets :: FilePath -> Snap ()
getPresets presetsdir = do
    presets <- liftIO $ lookAtPresets presetsdir
    writeBS $ BS.pack $ encode presets

savePreset :: FilePath -> Snap ()
savePreset presetsdir = do
    mname <- getParam "name"
    postParams <- rqPostParams `fmap` getRequest
    case mname of
        Just n-> if Map.member "animations" postParams
                     then do let jsonblob = postParams Map.! "animations"
                                 p = jsonblob !! 0
                             liftIO $ BS.writeFile (joinPath [presetsdir,BS.unpack n]) p
                             writeBS "Success!"
                     else writeBS "Missing post parameter: animations"
        Nothing   -> writeBS "You need to specify a name. /savepreset/:name"

getPreset :: FilePath -> Snap ()
getPreset presetsdir = do
    mname <- getParam "name"
    case mname of
        Just n -> do p <- liftIO $ BS.readFile (joinPath [presetsdir,BS.unpack n])
                     writeBS p
        Nothing   -> writeBS "You need to specify a name. /getpreset/:name"
