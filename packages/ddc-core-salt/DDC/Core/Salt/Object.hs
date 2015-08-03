
module DDC.Core.Salt.Object
        (objectsOfExp)
where
import DDC.Core.Exp
import qualified DDC.Core.Salt                  as A
import qualified DDC.Core.Salt.Compounds        as A
import Data.Map                 (Map)
import qualified Data.Map       as Map

-- Exp ------------------------------------------------------------------------
objectsOfExp
        :: Exp a A.Name
        -> Map A.Name (Type A.Name)

objectsOfExp xx
 = case xx of
        XVar  _ _       -> Map.empty
        XCon  _ _       -> Map.empty
        XLAM  _ _ x     -> objectsOfExp x
        XLam  _ b x     -> Map.union  (objectsOfBind b)   (objectsOfExp x)
        XApp  _ x1 x2   -> Map.union  (objectsOfExp x1)   (objectsOfExp x2)
        XLet  _ lts x   -> Map.union  (objectsOfLets lts) (objectsOfExp x)
        XCase _ x alts  -> Map.unions (objectsOfExp x : map objectsOfAlt alts)
        XCast _ _ x     -> objectsOfExp x
        XType{}         -> Map.empty
        XWitness{}      -> Map.empty

-- Let ------------------------------------------------------------------------
objectsOfLets
        :: Lets a A.Name
        -> Map A.Name (Type A.Name)

objectsOfLets lts
 = case lts of
        LLet b x        -> Map.union (objectsOfBind b) (objectsOfExp x)
        LRec bxs        -> Map.unions [Map.union (objectsOfBind b) (objectsOfExp x) | (b, x) <- bxs]
        LPrivate{}      -> Map.empty


-- Alt ------------------------------------------------------------------------
objectsOfAlt
        :: Alt a A.Name
        -> Map A.Name (Type A.Name)

objectsOfAlt aa
 = case aa of
        AAlt p x        -> Map.union (objectsOfPat p) (objectsOfExp x)


-- Alt ------------------------------------------------------------------------
objectsOfPat
        :: Pat A.Name
        -> Map A.Name (Type A.Name)

objectsOfPat pp
 = case pp of
        PDefault        -> Map.empty
        PData _ bs      -> Map.unions (map objectsOfBind bs)


-- Bind -----------------------------------------------------------------------
objectsOfBind
        :: Bind A.Name
        -> Map  A.Name (Type A.Name)

objectsOfBind bb
 = case bb of
        BNone _
         -> Map.empty

        BAnon t
         | isHeapObject t
         -> error "objectsOfBind: found anonymous heap object"
         -- TODO how to report this error correctly

         | otherwise
         -> Map.empty

        BName n t
         | isHeapObject t
         -> Map.singleton n t

         | otherwise
         -> Map.empty


-- Utils ----------------------------------------------------------------------
-- | Checks if we have a `Ptr# r Obj`.
isHeapObject :: Type A.Name -> Bool
isHeapObject t
 = case A.takeTPtr t of
        Nothing      -> False
        Just (_, tp) -> tp == A.tObj


