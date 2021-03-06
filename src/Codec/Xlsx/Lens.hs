{-# LANGUAGE CPP          #-}
{-# LANGUAGE RankNTypes   #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}

-- | lenses to access sheets, cells and values of 'Xlsx'

module Codec.Xlsx.Lens
    ( ixSheet
    , atSheet
    , ixCell
    , ixCellRC
    , ixCellXY
    , atCell
    , atCellRC
    , atCellXY
    , cellValueAt
    , cellValueAtRC
    , cellValueAtXY
 ) where

import GHC.Generics (Generic)

import           Codec.Xlsx.Types
import           Control.Lens
import           Data.Function       (on)
import           Data.List           (deleteBy)
import           Data.Text
import           Data.Tuple          (swap)

#if !MIN_VERSION_base(4,8,0)
import           Control.Applicative
#endif

newtype SheetList = SheetList{ unSheetList :: [(Text, Worksheet)] }
    deriving (Eq, Show, Generic)

type instance IxValue (SheetList) = Worksheet
type instance Index (SheetList) = Text

instance Ixed SheetList where
    ix k f sl@(SheetList l) = case lookup k l of
        Just v  -> f v <&> \v' -> SheetList (upsert k v' l)
        Nothing -> pure sl
    {-# INLINE ix #-}

instance At SheetList where
  at k f (SheetList l) = f mv <&> \r -> case r of
      Nothing -> SheetList $ maybe l (\v -> deleteBy ((==) `on` fst) (k,v) l) mv
      Just v' -> SheetList $ upsert k v' l
    where
      mv = lookup k l
  {-# INLINE at #-}

upsert :: (Eq k) => k -> v -> [(k,v)] -> [(k,v)]
upsert k v [] = [(k,v)]
upsert k v ((k1,v1):r) =
    if k == k1
    then (k,v):r
    else (k1,v1):upsert k v r

sheetList :: Iso' [(Text, Worksheet)] SheetList
sheetList = iso SheetList unSheetList

-- | lens giving access to a worksheet from 'Xlsx' object
-- by its name
ixSheet :: Text -> Traversal' Xlsx Worksheet
ixSheet s = xlSheets . sheetList . ix s

-- | 'Control.Lens.At' variant of 'ixSheet' lens
--
-- /Note:/ if there is no such sheet in this workbook then new sheet will be
-- added as the last one to the sheet list
atSheet :: Text -> Lens' Xlsx (Maybe Worksheet)
atSheet s = xlSheets . sheetList . at s

-- | lens giving access to a cell in some worksheet
-- by its position, by default row+column index is used
-- so this lens is a synonym of 'ixCellRC'
ixCell :: (Int, Int) -> Traversal' Worksheet Cell
ixCell = ixCellRC

-- | lens to access cell in a worksheet
ixCellRC :: (Int, Int) -> Traversal' Worksheet Cell
ixCellRC i = wsCells . ix i

-- | lens to access cell in a worksheet using more traditional
-- x+y coordinates
ixCellXY :: (Int, Int) -> Traversal' Worksheet Cell
ixCellXY = ixCellRC . swap

-- | accessor that can read, write or delete cell in a worksheet
-- synonym of 'atCellRC' so uses row+column index
atCell :: (Int, Int) -> Lens' Worksheet (Maybe Cell)
atCell = atCellRC

-- | lens to read, write or delete cell in a worksheet
atCellRC :: (Int, Int) -> Lens' Worksheet (Maybe Cell)
atCellRC i = wsCells . at i

-- | lens to read, write or delete cell in a worksheet
-- using more traditional x+y or row+column index
atCellXY :: (Int, Int) -> Lens' Worksheet (Maybe Cell)
atCellXY = atCellRC . swap

-- | lens to read, write or delete cell value in a worksheet
-- with row+column coordinates, synonym for 'cellValueRC'
cellValueAt :: (Int, Int) -> Lens' Worksheet (Maybe CellValue)
cellValueAt = cellValueAtRC

-- | lens to read, write or delete cell value in a worksheet
-- using row+column coordinates of that cell
cellValueAtRC :: (Int, Int) -> Lens' Worksheet (Maybe CellValue)
cellValueAtRC i = atCell i . non def . cellValue

-- | lens to read, write or delete cell value in a worksheet
-- using traditional x+y coordinates
cellValueAtXY :: (Int, Int) -> Lens' Worksheet (Maybe CellValue)
cellValueAtXY = cellValueAtRC . swap
