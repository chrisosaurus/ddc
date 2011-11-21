
module DDC.Core.Check
        ( typeOfWitness
        , typeOfWiCon)
where
import DDC.Core.Exp
import DDC.Type.Compounds

typeOfWitness :: Witness n -> Type n
typeOfWitness ww
 = case ww of
        WCon wc
         -> typeOfWiCon wc

        _ -> error "typeOfWitness: not handled yet"
        

-- | Take the type of a witness constructor.
typeOfWiCon :: WiCon -> Type n
typeOfWiCon wc
 = case wc of
        WiConMkPure     -> tPure  (tBot kEffect)
        WiConMkEmpty    -> tEmpty (tBot kClosure)

        WiConMkConst    
         -> tForall kRegion $ \r -> tConst r

        WiConMkMutable
         -> tForall kRegion $ \r -> tMutable r

        WiConMkLazy
         -> tForall kRegion $ \r -> tLazy r

        WiConMkDirect
         -> tForall kRegion $ \r -> tDirect r

        WiConMkPurify
         -> tForall kRegion $ \r -> (tConst r) `tImpl`  (tPure  $ tRead r)

        WiConMkShare
         -> tForall kRegion $ \r -> (tConst r)  `tImpl` (tEmpty $ tFree r)

        WiConMkDistinct n
         -> tForalls (replicate n kRegion) $ \rs -> tDistinct rs

