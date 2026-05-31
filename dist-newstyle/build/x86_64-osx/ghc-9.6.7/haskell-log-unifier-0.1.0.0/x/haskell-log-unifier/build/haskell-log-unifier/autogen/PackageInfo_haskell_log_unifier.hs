{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module PackageInfo_haskell_log_unifier (
    name,
    version,
    synopsis,
    copyright,
    homepage,
  ) where

import Data.Version (Version(..))
import Prelude

name :: String
name = "haskell_log_unifier"
version :: Version
version = Version [0,1,0,0] []

synopsis :: String
synopsis = "Log unifier with DSL for parsing and transforming logs"
copyright :: String
copyright = ""
homepage :: String
homepage = ""
