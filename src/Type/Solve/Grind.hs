
module Type.Solve.Grind
	(solveGrind)
where
import DDC.Solve.Crush.Unify
import DDC.Solve.Crush.Shape
import DDC.Solve.Crush.Effects
import DDC.Solve.Crush.Fetter
import Type.Crush.Proj
import Constraint.Exp
import Util
import DDC.Main.Error
import DDC.Solve.State
import DDC.Type.Exp
import DDC.Type.Builtin
import DDC.Var
import qualified DDC.Var.PrimId	as Var
import qualified Data.Set	as Set
import qualified Data.Map	as Map

debug	= True
stage	= "Type.Solve.Grind"
trace s = when debug $ traceM s

-- | Perform unification, resolve projections and grind out any available effects 
--	or fetters in the graph.
--
--	solveGrind may not be able to completely grind out all constraints because
--	the crushing of projections may require the projection function to be
--	instantiated, triggering generalisation and requiring another grind.
--
--	If solveGrind returns no constraints, the grind succeeded and no crushable
--	constructors remain in the graph.
--
--	If solveGrind returns constraints, then they need to be processed before
--	continuing the grind. In this case the last constraint in the list will
--	be another CGrind.
--
solveGrind 
	:: SquidM [CTree]

solveGrind
 = do	-- if there are already errors in the state then don't start the grind.
 	errs		<- gets stateErrors
	if isNil errs
	 then do 
		trace	$ ppr "-- Grind Start --------------------------------\n"
	 	cs	<- solveGrindStep
		trace	$ ppr "------------------------------------ Grind Stop\n"

		return cs

	 else return []
		
			
solveGrindStep 
 = do	trace	$ "\n"
 		% "-- Solve.grind step\n"

	 -- get the set of active classes
 	active	<- liftM Set.toList $ clearActive
	
	trace	$ "   active classes:\n"
		%> active	%  "\n"

	-- make sure all classes are unified
	progressUnify
		<- mapM crushUnifyInClass active

	errors	<- gets stateErrors
	when (length errors > 0) $ do
		liftIO $ exitWithUserError [] errors

	-- grind those classes
	(progressCrush, qssMore)
		<- liftM unzip
		$  mapM grindClass active
 	
	-- split classes into the ones that made progress and the ones that
	--	didn't. This is just for the trace stmt below.
	let activeUnify		   = zip active progressUnify
	let activeProgress	   = zip active progressCrush
	let classesWithProgress	   = [cid | (cid, True)  <- activeUnify ++ activeProgress]
	let classesWithoutProgress = [cid | (cid, False) <- activeUnify ++ activeProgress]
	
	trace	$ "   classes that made progress:\n" 
		%> classesWithProgress % "\n"

	 	% "   classes without progress:\n" 
		%> classesWithoutProgress % "\n"


	let qsMore	= concat qssMore
	errs		<- gets stateErrors
		
	trace	$ ppr "\n"
	let next
		-- if we've hit any errors then bail out now
		| not $ null errs
		= return []

		-- if we've crushed a projection and ended up with more constraints
		--	then stop grinding for now, but ask to be resumed later when
		--	new constraints are added.
		| not $ null qsMore
		= return (qsMore ++ [CGrind])
		
		-- if we've made progress then keep going.
		| or progressUnify || or progressCrush
		= solveGrindStep 
		
		-- no progress, all done.
		| otherwise
		= return []
		
	next


grindClass :: ClassId -> SquidM (Bool, [CTree])
grindClass cid
 = do	Just c	<- lookupClass cid
	grindClass2 cid c

grindClass2 cid c@ClassUnallocated{}
	= panic stage
	$ "grind2: ClassUnallocated{} " % cid

grindClass2 cid c@(ClassForward _ cid')
	= panic stage
	$ "grind2: the cids to grind should already be canonicalised."
	
	 	
-- type nodes
grindClass2 cid c@(Class	
			{ classUnified 	= mType
			, classKind	= k 
			, classFetters	= fsSrcs})
 = do	
	-- if a class contains an effect it might need to be crushed
	progressCrushE	
		<- case k of
			kE | kE == kEffect	-> crushEffectsInClass cid
			_			-> return False

	-- try and crush other fetters in this class
	progressCrush
		<- if Map.null fsSrcs
			then return False
			else crushFettersInClass cid
			
	return	( progressCrushE || progressCrush
		, [])
	
-- fetter nodes
grindClass2 cid c@ClassFetterDeleted{}
	= return (False, [])

grindClass2 cid c@(ClassFetter { classFetter = f })
 = do
	-- crush projection fetters
	qsMore	<- case f of
			FProj{}	-> crushProjInClass cid
			_	-> return Nothing
			
	let progressProj
		= isJust qsMore
		
	-- crush shape fetters
	let isFShape b
		= case b of
			Var.FShape _	-> True
			_		-> False

	progressShape
		<- case f of
			FConstraint v _
			 | VarIdPrim pid	<- varId v
			 , isFShape pid		-> crushShapeInClass cid
			_			-> return False
		
	-- crush other fetters
	progressCrush <- crushFettersInClass cid
		
	return	( progressProj || progressShape || progressCrush
		, fromMaybe [] qsMore )
