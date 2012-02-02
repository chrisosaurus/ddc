
-- | Type substitution.
module DDC.Core.Transform.SubstituteW
        ( SubstituteW(..)
        , substituteW
        , substituteWs)
where
import DDC.Core.Exp
import DDC.Core.Collect.FreeX
-- import DDC.Core.Transform.LiftW
import DDC.Type.Compounds
import DDC.Type.Transform.SubstituteT
import Data.Maybe
import qualified DDC.Type.Env   as Env
import qualified Data.Set       as Set
import Data.Set                 (Set)


-- | Wrapper for `substituteWithW` that determines the set of free names in the
--   type being substituted, and starts with an empty binder stack.
substituteW :: (SubstituteW c, Ord n) => Bind n -> Witness n -> c n -> c n
substituteW b w x
 | Just u       <- takeSubstBoundOfBind b
 = let -- Determine the free names in the type we're subsituting.
       -- We'll need to rename binders with the same names as these
       freeNames        = Set.fromList
                        $ mapMaybe takeNameOfBound 
                        $ Set.toList 
                        $ freeX Env.empty w            -- TODO: type vars won't be captured.
                                                                --       shouldn't rename them.
                                                                -- Need to split type names vs valwit names.

       stack           = BindStack [] [] 0 0
 
  in   substituteWithW u w freeNames stack x

 | otherwise    = x
 

-- | Wrapper for `substituteW` to substitute multiple things.
substituteWs :: (SubstituteW c, Ord n) => [(Bind n, Witness n)] -> c n -> c n
substituteWs bts x
        = foldr (uncurry substituteW) x bts


class SubstituteW (c :: * -> *) where
 -- | Substitute a witness into some thing.
 --   In the target, if we find a named binder that would capture a free variable
 --   in the type to substitute, then we rewrite that binder to anonymous form,
 --   avoiding the capture.
 substituteWithW
        :: forall n. Ord n
        => Bound n              -- ^ Bound variable that we're subsituting into.
        -> Witness n            -- ^ Witness to substitute.
        -> Set  n               -- ^ Names of free varaibles in the exp to substitute.
        -> BindStack n          -- ^ Bind stack.
        -> c n -> c n


-- Instances --------------------------------------------------------------------------------------
instance SubstituteW Witness where
 substituteWithW u w fns stack ww
  = let down    = substituteWithW u w fns stack
    in case ww of
        WCon{}                  -> ww
        WApp  w1 w2             -> WApp  (down w1) (down w2)
        WJoin w1 w2             -> WJoin (down w1) (down w2)
        WType{}                 -> ww

        WVar u'
         -> case substBound stack u u' of
                Left u''  -> WVar u''
                Right _n  -> w                                                  -- TODO: liftW by n


instance SubstituteW (Exp a) where 
 substituteWithW u w fns stack xx
  = let down    = substituteWithW u w fns stack 
    in case xx of
        XVar{}          -> xx
        XCon{}          -> xx
        XApp  a x1 x2   -> XApp  a   (down x1)  (down x2)
        XLam  a b x     -> XLam  a b (down x)                                   -- TODO: handle var capture on lambda
        XLet  a ls1  x2 -> XLet  a   (down ls1) (down x2)
        XCase a x alts  -> XCase a   (down x)   (map down alts)
        XCast a c x     -> XCast a   (down c)   (down x)
        XType{}         -> xx
        XWitness w1     -> XWitness (down w1)


instance SubstituteW (Lets a) where
 substituteWithW u f fns stack ll
  = let down = substituteWithW u f fns stack
    in case ll of
        LLet m b x      -> LLet (down m) b (down x)
        LRec bxs        -> LRec [ (b, down x) | (b, x) <- bxs ]
        LLetRegion{}    -> ll
        LWithRegion{}   -> ll


instance SubstituteW LetMode where
 substituteWithW u f fns stack lm
  = let down = substituteWithW u f fns stack
    in case lm of
        LetStrict        -> lm
        LetLazy Nothing  -> LetLazy Nothing
        LetLazy (Just w) -> LetLazy (Just (down w))


instance SubstituteW (Alt a) where
 substituteWithW u f fns stack alt
  = let down = substituteWithW u f fns stack
    in case alt of
        AAlt p x -> AAlt p (down x)


instance SubstituteW Cast where
 substituteWithW u w fns stack cc
  = let down    = substituteWithW u w fns stack 
    in case cc of
        CastWeakenEffect eff    -> CastWeakenEffect  eff
        CastWeakenClosure clo   -> CastWeakenClosure clo
        CastPurify w'           -> CastPurify (down w')
        CastForget w'           -> CastForget (down w')
