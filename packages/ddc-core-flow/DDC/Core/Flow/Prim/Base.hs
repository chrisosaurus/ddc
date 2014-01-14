
module DDC.Core.Flow.Prim.Base
        ( Name (..)
        , KiConFlow     (..)
        , TyConFlow     (..)
        , DaConFlow     (..)
        , OpConcrete    (..)
        , OpControl     (..)
        , OpSeries      (..)
        , OpStore       (..)
        , OpVector      (..)
        , PrimTyCon     (..)
        , PrimArith     (..)
        , PrimVec       (..)
        , PrimCast      (..))
where
import Data.Typeable
import DDC.Core.Salt.Name.PrimTyCon
import DDC.Core.Salt.Name.PrimArith
import DDC.Core.Salt.Name.PrimVec
import DDC.Core.Salt.Name.PrimCast


-- | Names of things used in Disciple Core Flow.
data Name
        -- | User defined variables.
        = NameVar               String

        -- | A name generated by modifying some other name `name$mod`
        | NameVarMod            Name String

        -- | A user defined constructor.
        | NameCon               String

        -- Fragment specific primops -----------
        -- | Fragment specific kind constructors.
        | NameKiConFlow         KiConFlow

        -- | Fragment specific type constructors.
        | NameTyConFlow         TyConFlow

        -- | Fragment specific data constructors.
        | NameDaConFlow         DaConFlow

        -- | Concrete series operators.
        | NameOpConcrete        OpConcrete

        -- | Control operators.
        | NameOpControl         OpControl

        -- | Series operators.
        | NameOpSeries          OpSeries

        -- | Store operators.
        | NameOpStore           OpStore

        -- | Vector operators.
        | NameOpVector          OpVector


        -- Machine primitives ------------------
        -- | A primitive type constructor.
        | NamePrimTyCon         PrimTyCon

        -- | Primitive arithmetic, logic, comparison and bit-wise operators.
        | NamePrimArith         PrimArith

        -- | Primitive casting between numeric types.
        | NamePrimCast          PrimCast

        -- | Primitive vector operators.
        | NamePrimVec           PrimVec


        -- Literals -----------------------------
        -- | A boolean literal.
        | NameLitBool           Bool

        -- | A natural literal.
        | NameLitNat            Integer

        -- | An integer literal.
        | NameLitInt            Integer

        -- | A word literal, with the given number of bits precision.
        | NameLitWord           Integer  Int

        -- | A float literal, with the given number of bits precision.
        | NameLitFloat          Rational Int
        deriving (Eq, Ord, Show, Typeable)


-- | Fragment specific kind constructors.
data KiConFlow
        = KiConFlowRate
        deriving (Eq, Ord, Show)


-- | Fragment specific type constructors.
data TyConFlow
        -- | @TupleN#@ constructor. Tuples.
        = TyConFlowTuple Int            

        -- | @Vector#@ constructor. Vectors. 
        | TyConFlowVector

        -- | @Series#@ constructor. Series types.
        | TyConFlowSeries

        -- | @Segd#@   constructor. Segment Descriptors.
        | TyConFlowSegd

        -- | @SelN#@   constructor. Selectors.
        | TyConFlowSel Int

        -- | @Ref#@    constructor.  References.
        | TyConFlowRef                  

        -- | @World#@  constructor.  State token used when converting to GHC core.
        | TyConFlowWorld

        -- | @RateNat#@ constructor. Naturals witnessing a type-level Rate.          
        | TyConFlowRateNat

        -- | @DownN#@ constructor.   Rate decimation. 
        | TyConFlowDown Int

        -- | @TailN#@ constructor.   Rate tail after decimation.
        | TyConFlowTail Int

        -- | @Process@ constructor.
        | TyConFlowProcess
        deriving (Eq, Ord, Show)


-- | Primitive data constructors.
data DaConFlow
        -- | @TN@ data constructor.
        = DaConFlowTuple Int            
        deriving (Eq, Ord, Show)


-- | Fusable Flow operators that work on Series.
data OpSeries
        -- | Project out a component of a tuple,
        --   given the tuple arity and index of the desired component.
        --   TODO: shift this somewhere else.
        = OpSeriesProj Int Int

        -- | Replicate a single element into a series.
        | OpSeriesRep

        -- | Segmented replicate.
        | OpSeriesReps

        -- | Segmented indices
        | OpSeriesIndices

        -- | Gather  (read) elements from a vector.
        | OpSeriesGather

        -- | Make a selector.
        | OpSeriesMkSel Int

        -- | Make a segment descriptor.
        | OpSeriesMkSegd

        -- | Apply a worker to corresponding elements of some series.
        | OpSeriesMap Int

        -- | Pack a series according to a flags vector.
        | OpSeriesPack

        -- | Reduce a series with an associative operator,
        --   updating an existing accumulator.
        | OpSeriesReduce

        -- | Segmented fold.
        | OpSeriesFolds

        -- | Fill an existing vector from a series.
        | OpSeriesFill

        -- | Scatter (write) elements into a vector.
        | OpSeriesScatter

        -- | Convert vector(s) into series, all with same length with runtime check.
        | OpSeriesRunProcess Int

        -- | Join two series processes.
        | OpSeriesJoin
        deriving (Eq, Ord, Show)


-- | Series related operators.
--   These operators work on series after the code has been fused.
--   They do not appear in the source program.
data OpConcrete
        -- | Take the rate of a series.
        = OpConcreteRateOfSeries

        -- | Take the underlying @Nat@ of a @RateNat@.
        | OpConcreteNatOfRateNat

        -- | Take some elements from a series.
        | OpConcreteNext Int

        -- | Decimate the rate of a series.
        | OpConcreteDown Int

        -- | Take the tail rate of a decimated series.
        | OpConcreteTail Int
        deriving (Eq, Ord, Show)


-- | Control operators.
data OpControl
        -- Top level loop, indexed by a rate type.
        = OpControlLoop

        -- Top level loop, taking a RateNat.
        | OpControlLoopN

        -- Evaluate some function when a flag is true.
        | OpControlGuard

        -- Evaluate some function a given number of times.
        | OpControlSegment

        -- Used for producing SIMD code.
        | OpControlSplit Int
        deriving (Eq, Ord, Show)


-- | Store operators.
data OpStore
        -- Assignables ----------------
        -- | Allocate a new reference.
        = OpStoreNew            

        -- | Read from a reference.
        | OpStoreRead

        -- | Write to a reference.
        | OpStoreWrite

        -- Vectors --------------------
        -- | Allocate a new vector (taking a @Nat@ for the length)
        | OpStoreNewVector

        -- | Allocate a new vector (taking a @Rate@ for the length)
        | OpStoreNewVectorR     

        -- | Allocate a new vector (taking a @RateNat@ for the length)
        | OpStoreNewVectorN     

        -- | Read a packed Vec of values from a Vector buffer.
        | OpStoreReadVector     Int

        -- | Write a packed Vec of values to a Vector buffer.
        | OpStoreWriteVector    Int

        -- | Window a target vector to the tail of some rate.
        | OpStoreTailVector     Int

        -- | Truncate a vector to a smaller length.
        | OpStoreTruncVector
        deriving (Eq, Ord, Show)


-- | Fusable flow operators that work on Vectors.
data OpVector
        -- | Apply worker function to @n@ vectors zipped.
        = OpVectorMap Int

        -- | Filter a vector according to a predicate.
        | OpVectorFilter

        -- | Associative fold.
        | OpVectorReduce

        -- | Create a new vector from an index function.
        | OpVectorGenerate

        -- | Get a vector's length.
        | OpVectorLength
        deriving (Eq, Ord, Show)

