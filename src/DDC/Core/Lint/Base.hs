
module DDC.Core.Lint.Base
	( lintList
	, checkList
	, subSingleton
	, slurpClosureToMap)
where 
import DDC.Type
import DDC.Var
import DDC.Core.Lint.Env
import qualified Data.Map	as Map
import Data.Map			(Map)


-- | Check for lint in some list of things.
lintList ::  (a -> Env -> b) -> [a] -> Env -> ()
lintList lintFun xx env
 = case xx of
	[]		-> ()
	(x:xs)		
		->    lintFun  x env
		`seq` lintList lintFun xs env
		`seq` ()

checkList :: (a -> ()) -> [a] -> ()
checkList f xx
 = case xx of
	[]	-> ()
	x : xs	-> f x `seq` checkList f xs `seq` ()


subSingleton v t v'
	| TVar _ (UVar v3)	<- t
	, v == v3	= Nothing

	| TVar _ (UMore v3 _)	<- t
	, v == v3	= Nothing
	
	| v == v'	= Just t
	| otherwise	= Nothing


slurpClosureToMap :: Closure -> Map Var Type
slurpClosureToMap clo
 	| isTBot clo	= Map.empty
	
	| Just (v, t)	<- takeTFree clo
	= Map.singleton v t