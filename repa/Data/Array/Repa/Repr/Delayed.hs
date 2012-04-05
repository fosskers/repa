{-# LANGUAGE MagicHash #-}
module Data.Array.Repa.Repr.Delayed
        ( D, Array(..)
        , fromFunction, toFunction
        , delay)
where
import Data.Array.Repa.Eval.Elt
import Data.Array.Repa.Eval.Cursored
import Data.Array.Repa.Eval.Chunked
import Data.Array.Repa.Eval.Fill
import Data.Array.Repa.Index
import Data.Array.Repa.Shape
import Data.Array.Repa.Base
import Debug.Trace
import GHC.Exts

-- | Delayed arrays are represented as functions from the index to element value.
data D
data instance Array D sh e
        = ADelayed  
                sh 
                (sh -> e) 


-- Repr -----------------------------------------------------------------------
-- | Compute elements of a delayed array.
instance Repr D a where
 {-# INLINE index #-}
 index       (ADelayed _  f) ix  = f ix

 {-# INLINE linearIndex #-}
 linearIndex (ADelayed sh f) ix  = f (fromIndex sh ix)

 {-# INLINE extent #-}
 extent (ADelayed sh _)
        = sh

 {-# INLINE deepSeqArray #-}
 deepSeqArray (ADelayed sh f) y
        = sh `deepSeq` f `seq` y


-- Fill -----------------------------------------------------------------------
-- | Compute all elements in an array.
instance (Fillable r2 e, Shape sh) => Fill D r2 sh e where
 {-# INLINE [4] fillP #-}
 fillP (ADelayed sh getElem) marr
  = marr `deepSeqMArr` 
    do  traceEventIO "Repa.fillP[Delayed]: start"
        fillChunkedP (size sh) (unsafeWriteMArr marr) (getElem . fromIndex sh) 
        traceEventIO "Repa.fillP[Delayed]: end"

 {-# INLINE [4] fillS #-}
 fillS (ADelayed sh getElem) marr
  = marr `deepSeqMArr` 
    do  traceEventIO "Repa.fillS[Delayed]: start"
        fillChunkedS (size sh) (unsafeWriteMArr marr) (getElem . fromIndex sh)
        traceEventIO "Repa.fillS[Delayed]: end"


-- | Compute a range of elements in a rank-2 array.
instance (Fillable r2 e, Elt e) => FillRange D r2 DIM2 e where
 {-# INLINE [1] fillRangeP #-}
 fillRangeP  (ADelayed (Z :. _h :. w) getElem) marr
             (Z :. y0 :. x0) (Z :. y1 :. x1)
  = marr `deepSeqMArr` 
    do  traceEventIO "Repa.fillRangeP[Delayed]: start"
        fillBlock2P (unsafeWriteMArr marr) 
                        getElem
                        w x0 y0 x1 y1
        traceEventIO "Repa.fillRangeP[Delayed]: end"

 {-# INLINE [1] fillRangeS #-}
 fillRangeS  (ADelayed (Z :. _h :. (I# w)) getElem) marr
             (Z :. (I# y0) :. (I# x0)) (Z :. (I# y1) :. (I# x1))
  = marr `deepSeqMArr`
    do  traceEventIO "Repa.fillRangeS[Delayed]: start"
        fillBlock2S (unsafeWriteMArr marr) 
                getElem
                w x0 y0 x1 y1
        traceEventIO "Repa.fillRangeS[Delayed]: end"


-- Conversions ----------------------------------------------------------------
-- | O(1). Wrap a function as a delayed array.
fromFunction :: sh -> (sh -> a) -> Array D sh a
{-# INLINE fromFunction #-}
fromFunction sh f 
        = ADelayed sh f 


-- | O(1). Produce the extent of an array and a function to retrieve an
--         arbitrary element.
toFunction 
        :: (Shape sh, Repr r1 a)
        => Array r1 sh a -> (sh, sh -> a)
{-# INLINE toFunction #-}
toFunction arr
 = case delay arr of
        ADelayed sh f -> (sh, f)


-- | O(1). Delay an array.
--   This wraps the internal representation to be a function from
--   indices to elements, so consumers don't need to worry about
--   what the previous representation was.
--
delay   :: (Shape sh, Repr r e)
        => Array r sh e -> Array D sh e
{-# INLINE delay #-}
delay arr = ADelayed (extent arr) (unsafeIndex arr)


