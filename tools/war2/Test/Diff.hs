
module Test.Diff
	(testDiff)
where

import Test.TestResult
import Test.TestFail
import Test.TestWin
import War
import Command

import Util.FilePath

import Control.Monad.Error


-- | Build a program starting from a Main.ds file
testDiff :: Test -> War TestWin
testDiff test@(TestDiff exp out)
 = do	debugLn $ "* TestDiff " ++ exp ++ " " ++ out

	-- the base name of the output file
	let outBase	= baseNameOfPath out

	-- file to write the diff output to
	let outDiff	= outBase ++ ".diff"

	-- if there is an existing diff file then remove it
	liftIOF $ removeIfExists outDiff

	-- do the diff
	let cmd	= "diff"
		++ " " ++ exp
		++ " " ++ out
		++ " > " ++ outDiff
				
	debugLn $ "  * cmd = " ++ cmd
	liftIOF $ system cmd
	
	-- read the output file back
	outFile	<- liftIO $ readFile outDiff

--	liftIO $ putStr $ "outFile = |" ++ outFile ++ "|\n"

	case outFile of
	 []	-> return TestWinDiff
	 _	-> throwError
			$ TestFailDiff
			{ testFailExpectedFile	= exp
			, testFailActualFile	= out
			, testFailDiffFile	= outDiff }

