{-# OPTIONS -fwarn-unused-imports -fno-warn-type-defaults -cpp #-}
module Llvm.Runtime.Alloc
	( allocate
	, allocThunk )
where

import DDC.Main.Error

import Llvm
import LlvmM
import Llvm.Runtime.Object
import Llvm.Runtime.Data
import Llvm.Runtime.Struct
import Llvm.Runtime.Tags
import Llvm.Util

stage = "Llvm.Runtime.Alloc"


-- | Generate LLVM code that can be inlined to allocate the given number of
-- bytes and return a pointer of the specified type.
-- The generated code will always allocate heap objects aligned to 8 byte
-- boundaries and panics if asked to allocate zero or less bytes.
allocate :: Int -> String -> LlvmType -> LlvmM LlvmVar
allocate bytes name typ
 = do	addGlobalFuncDecl allocCollect
	ptr	<- newUniqueNamedReg name typ
	r0	<- newUniqueNamedReg "r0" pChar
	r1	<- newUniqueNamedReg "r1" pChar
	r2	<- newUniqueNamedReg "r2" pChar
	r3	<- newUniqueNamedReg "r3" i1
	r4	<- newUniqueNamedReg "r4" pChar
	r5	<- newUniqueNamedReg "r5" (pLift i32)
	r6	<- newUniqueNamedReg "r6" pChar
	r7	<- newUniqueNamedReg "r7" pChar
	r8	<- newUniqueNamedReg "r8" (pLift i32)
	pre	<- newUniqueNamedReg "pre" pChar

	entry	<- newUniqueLabel "allocate"
	bb	<- newUniqueLabel "bb"
	bb1	<- newUniqueLabel "bb1"

	let count = i32LitVar $ roundUpBytes bytes

	addBlock
		[ Comment ["allocate " ++ show bytes ++ " bytes"]
		, Branch entry
		, MkLabel (uniqueOfLlvmVar entry)
		, Assignment r0 (Load ddcHeapPtr)
		, Assignment r1 (GetElemPtr True r0 [count])
		, Assignment r2 (Load ddcHeapMax)
		, Assignment r3 (Compare LM_CMP_Ugt r1 r2)
		, BranchIf r3 bb bb1

		, MkLabel (uniqueOfLlvmVar bb)
		, Expr (Call StdCall (LMGlobalVar "_allocCollect" (LMFunction allocCollect) External Nothing Nothing True) [count] [])
		, Assignment pre (Load ddcHeapPtr)
		, Branch bb1

		, MkLabel (uniqueOfLlvmVar bb1)
		, Assignment r4 (Phi pChar [(pre, bb), (r0 , entry)])

		, Assignment r5 (Cast LM_Bitcast r4 (pLift i32))
		, Assignment r6 (GetElemPtr True r4 [count])
		, Store r6 ddcHeapPtr
		]
	if typ == pChar
	  then		return r2
	  else do	addBlock [ Assignment ptr (Cast LM_Bitcast r4 typ) ]
			return	ptr


allocThunk :: LlvmVar -> Int -> Int -> LlvmM LlvmVar
allocThunk funvar arity argc
 = do	addAlias	("struct.Thunk", structThunk)
	let size	= sizeOfLlvmType structThunk + arity * sizeOfLlvmType pObj
	addComment	$ "allocThunk " ++ getName funvar ++ " " ++ show arity ++ " " ++ show argc

	pThunk		<- allocate size "pThunk" pStructThunk

	storeStructRegValue ddcThunk pThunk "tag" tagFixedThunk

	pFunSrc		<- newUniqueNamedReg "pFunSrc" (genericFunPtrType)
	addBlock	[ Assignment pFunSrc (Cast LM_Bitcast funvar genericFunPtrType) ]
	storeStructRegValue ddcThunk pThunk "funptr" pFunSrc

	storeStructRegValue ddcThunk pThunk "arity" (i32LitVar arity)
	storeStructRegValue ddcThunk pThunk "argc" (i32LitVar argc)

	if argc > 0
	  then panic stage "Need to initialize argc"
	  else return ()

	ret		<- newUniqueNamedReg "allocated.thunk" pObj
	addBlock	[ Assignment ret (Cast LM_Bitcast pThunk pObj) ]
	return		ret



storeStructRegValue :: LlvmStructDesc -> LlvmVar -> String -> LlvmVar -> LlvmM ()
storeStructRegValue desc struct field value
 = do	let (indx, typ)	= structFieldLookup desc field
	ptag		<- newUniqueNamedReg field (pLift typ)
	addBlock	[ Assignment ptag (GetElemPtr True struct [i32LitVar 0, i32LitVar indx])
			, Store value ptag ]


-- | Round up to a multiple of 8.
roundUpBytes :: Int -> Int
roundUpBytes n
 | n <= 0
 = panic stage $ "allocate with " ++ show n

 | mod n 8 == 0
 = n

 | otherwise
 = n + (8 - mod n 8)


