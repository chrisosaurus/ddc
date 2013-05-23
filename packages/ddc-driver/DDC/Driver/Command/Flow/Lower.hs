
module DDC.Driver.Command.Flow.Lower
        (cmdFlowLower)
where
import DDC.Driver.Stage
import DDC.Driver.Source
import DDC.Build.Pipeline
import Control.Monad.Trans.Error
import Control.Monad.IO.Class
import qualified DDC.Base.Pretty                as P
import qualified DDC.Build.Language.Flow        as Flow


-- | Lower a flow program to loop code.
cmdFlowLower
        :: Config
        -> Source       -- ^ Source of the code.
        -> String       -- ^ Program module text.
        -> ErrorT String IO ()

cmdFlowLower config source sourceText
 = do   
        errs    <- liftIO
                $  pipeText (nameOfSource source)
                            (lineStartOfSource source)
                            sourceText
                $  stageFlowLoad  config source
                [  stageFlowPrep  config source
                [  PipeCoreCheck  Flow.fragment
                [  stageFlowLower config source
--                [  PipeCoreCheck  Flow.fragment
                [  PipeCoreOutput SinkStdout ]]]]

        case errs of
         []     -> return ()
         es     -> throwError $ P.renderIndent $ P.vcat $ map P.ppr es

